local Runtime = {}
Runtime.__index = Runtime

local Messaging = require("communication.messaging")

local ROLES = {
    source = true,
    processor = true,
    sink = true,
}

local function resolveBinding(binding)
    if type(binding) == "string" then
        return binding, false
    end

    assert(
        type(binding) == "table"
        and type(binding.signal) == "string",
        "Input binding must be a signal name or binding table"
    )

    return binding.signal, binding.optional == true
end

local function valuesEqual(a, b)
    return a == b
end

function Runtime.new(config)
    assert(type(config) == "table", "Runtime requires config")

    local definition = config.definition or config

    assert(type(definition) == "table", "Runtime requires a definition")
    assert(type(definition.flow) == "table", "Definition requires a flow")
    assert(type(definition.flow.stages) == "table",
        "Flow requires stages")
    assert(type(definition.components) == "table",
        "Definition requires components")

    local self = setmetatable({}, Runtime)

    self.id = config.id or definition.id or "flight-runtime"
    self.interval = config.interval or 0.05
    self.flow = definition.flow

    self.components = {}
    self.signals = {}
    self.neededSignals = {}
    self.localOutputs = {}
    self.remoteSignals = {}
    self.explicitRemoteSignals = {}
    self.publishSignals = {}

    self.bus = nil
    self.running = false

    -- Register local component instances by their own IDs.
    for id, component in pairs(definition.components) do
        assert(type(id) == "string", "Component registry keys must be strings")
        assert(type(component) == "table", "Invalid component: " .. id)
        assert(component.id == id,
            "Component registry key does not match component id: " .. id)
        assert(type(component.update) == "function",
            "Component " .. id .. " requires update()")

        self.components[id] = component
    end

    -- Pass 1: validate nodes, find local outputs, and collect dependencies.
    for stageIndex, stage in ipairs(self.flow.stages) do
        assert(type(stage) == "table",
            "Stage " .. stageIndex .. " must be a table")
        assert(type(stage.components) == "table",
            "Stage " .. stageIndex .. " requires components")

        for nodeIndex, node in ipairs(stage.components) do
            local label = "Stage " .. stageIndex
                .. ", node " .. nodeIndex

            assert(type(node) == "table", label .. " must be a table")
            assert(
                node.role == "source"
                or node.role == "processor"
                or node.role == "sink",
                label .. " has an invalid role"
            )

            if node.remote then
                assert(node.component == nil,
                    label .. " remote nodes cannot have components")

                if node.role == "source" then
                    assert(type(node.output) == "string",
                        label .. " remote source requires an output signal")

                    self.explicitRemoteSignals[node.output] = true
                elseif node.role == "sink" then
                    assert(node.publish == true,
                        label .. " remote sink must publish")
                    assert(type(node.inputs) == "table",
                        label .. " remote sink requires inputs")
                else
                    error(label .. " cannot be a remote processor")
                end
            else
                assert(type(node.component) == "string",
                    label .. " requires a component ID")
                assert(self.components[node.component],
                    label .. " references an unregistered component: "
                    .. node.component)

                if node.role == "source" then
                    assert(type(node.output) == "string",
                        label .. " source requires an output")
                    assert(node.inputs == nil,
                        label .. " source cannot have inputs")
                elseif node.role == "processor" then
                    assert(type(node.output) == "string",
                        label .. " processor requires an output")
                    assert(type(node.inputs) == "table",
                        label .. " processor requires inputs")
                else
                    assert(node.output == nil,
                        label .. " sink cannot have an output")
                    assert(type(node.inputs) == "table",
                        label .. " sink requires inputs")
                end

                -- Only local source/processor nodes are local producers.
                if node.output then
                    assert(not self.localOutputs[node.output],
                        "Multiple local producers for signal: " .. node.output)

                    self.localOutputs[node.output] = true
                end
            end

            -- Only executable local processors/sinks need input subscriptions.
            if not node.remote and node.role ~= "source" then
                for _, binding in pairs(node.inputs or {}) do
                    local signal = resolveBinding(binding)
                    self.neededSignals[signal] = true
                end
            end

            -- Remote sinks declare which locally produced signals to publish.
            if node.remote and node.role == "sink" then
                for _, binding in pairs(node.inputs) do
                    local signal = resolveBinding(binding)
                    self.publishSignals[signal] = true
                end
            end
        end
    end

    -- Pass 2: determine which signals must arrive over the bus.
    for signal in pairs(self.neededSignals) do
        if not self.localOutputs[signal] then
            self.remoteSignals[signal] = true
        end
    end

    for signal in pairs(self.explicitRemoteSignals) do
        if not self.localOutputs[signal] then
            self.remoteSignals[signal] = true
        end
    end

    -- A remote sink may only publish a signal produced locally.
    for signal in pairs(self.publishSignals) do
        assert(self.localOutputs[signal],
            "Remote sink can only publish a locally produced signal: "
            .. signal)
    end

    -- Do not create a bus if this flow has no external communication.
    local needsBus = next(self.remoteSignals) ~= nil
        or next(self.publishSignals) ~= nil

    if needsBus then
        self.bus = Messaging.open(config.messaging or {})

        for signal in pairs(self.remoteSignals) do
            self.bus:subscribe(signal)
        end
    end

    return self
end

function Runtime:_receiveBatch()
    if not self.bus then
        return {}
    end

    -- Collapse each incoming batch to its latest value per topic.
    local received = {}

    for _, message in ipairs(self.bus:getMessages() or {}) do
        if message.topic and (
                self.neededSignals[message.topic]
                or self.explicitRemoteSignals[message.topic]
            ) then
            received[message.topic] = message.content
        end
    end

    return received
end

function Runtime:_publishBatch(batch)
    if not self.bus or #batch == 0 then
        return
    end

    assert(type(self.bus.publishBatch) == "function",
        "Messaging bus must implement publishBatch(batch)")

    self.bus:publishBatch(batch)
end

function Runtime:_resolveInputs(bindings)
    local inputs = {}

    for name, binding in pairs(bindings or {}) do
        local signal, optional = resolveBinding(binding)
        local value = self.signals[signal]

        if value == nil and not optional then
            return nil, false
        end

        inputs[name] = value
    end

    return inputs, true
end

function Runtime:_inputsChanged(bindings, changed)
    for _, binding in pairs(bindings or {}) do
        local signal = resolveBinding(binding)

        if changed[signal] then
            return true
        end
    end

    return false
end

function Runtime:_setSignal(signal, value, changed, outgoing)
    if value == nil then
        -- nil means no new output; retain the previous value.
        return
    end

    local previous = self.signals[signal]

    if valuesEqual(previous, value) then
        return
    end

    self.signals[signal] = value
    changed[signal] = true

    if self.publishSignals[signal] then
        outgoing[signal] = {
            topic = signal,
            content = value,
        }
    end
end

function Runtime:_executeNode(node, changed, outgoing)
    if node.remote then
        return
    end

    local component = self.components[node.component]

    -- This node belongs to another computer.
    if not component then
        return
    end

    assert(type(component.update) == "function",
        "Component " .. node.component .. " requires update()")

    if node.role == "source" then
        -- Sources are sampled once per runtime cycle.
        local value = component:update()
        self:_setSignal(node.output, value, changed, outgoing)
        return
    end

    -- Processors and sinks are event-driven.
    if not self:_inputsChanged(node.inputs, changed) then
        return
    end

    local inputs, ready = self:_resolveInputs(node.inputs)

    -- Wait until every required input has a value.
    if not ready then
        return
    end

    if node.role == "processor" then
        local value = component:update(inputs)
        self:_setSignal(node.output, value, changed, outgoing)
    else
        component:update(inputs)
    end
end

function Runtime:update()
    -- Apply all received values before evaluating any nodes.
    local received = self:_receiveBatch()
    local changed = {}
    local outgoing = {}

    for signal, value in pairs(received) do
        local previous = self.signals[signal]

        if not valuesEqual(previous, value) then
            self.signals[signal] = value
            changed[signal] = true
        end
    end

    -- Local source changes and downstream processing propagate
    -- in declared stage/node order within this cycle.
    for _, stage in ipairs(self.flow.stages) do
        for _, node in ipairs(stage.components) do
            self:_executeNode(node, changed, outgoing)
        end
    end

    -- Send all changed local outputs as one network batch.
    local batch = {}

    for _, message in pairs(outgoing) do
        batch[#batch + 1] = message
    end

    self:_publishBatch(batch)
end

function Runtime:_runLoop()
    self.running = true

    while self.running do
        self:update()
        sleep(self.interval)
    end
end

function Runtime:run()
    if self.bus then
        parallel.waitForAll(
            function()
                self.bus:run()
            end,
            function()
                self:_runLoop()
            end
        )
    else
        self:_runLoop()
    end
end

function Runtime:stop()
    self.running = false
end

function Runtime:getSignal(name)
    return self.signals[name]
end

return Runtime
