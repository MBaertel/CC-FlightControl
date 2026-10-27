local Runtime = {}
Runtime.__index = Runtime

local Messaging = require("communication.messaging")

local ROLES = {
    source = true,
    processor = true,
    sink = true,
}

local EXECUTION_POLICIES = {
    on_change = true,
    always = true,
    on_start = true,
}

local unpackValues = table.unpack or unpack

local function valuesEqual(a, b)
    return a == b
end

local function resolveBinding(binding)
    if type(binding) == "string" then
        return {
            signal = binding,
            accessor = nil,
            optional = false,
        }
    end

    assert(
        type(binding) == "table"
        and type(binding.signal) == "string"
        and binding.signal ~= "",
        "Input binding requires a signal name"
    )

    assert(
        binding.accessor == nil
        or (
            type(binding.accessor) == "string"
            and binding.accessor ~= ""
        ),
        "Input binding accessor must be a non-empty string"
    )

    return {
        signal = binding.signal,
        accessor = binding.accessor,
        optional = binding.optional == true,
    }
end

-- Read a dotted field path from a signal value.
-- Example: accessor "raw.value" reads value.raw.value.
local function resolveAccessor(value, accessor)
    if accessor == nil then
        return value
    end

    for key in accessor:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end

        value = value[key]
    end

    return value
end

local function bindingList(bindings)
    local result = {}

    for _, binding in ipairs(bindings or {}) do
        result[#result + 1] = resolveBinding(binding)
    end

    return result
end

local function getExecutionPolicy(node)
    local config = node.config or {}
    local execution =
        config.execution or node.execution or "on_change"

    assert(
        EXECUTION_POLICIES[execution],
        "Invalid execution policy: " .. tostring(execution)
    )

    return execution
end

function Runtime.new(config)
    assert(type(config) == "table", "Runtime requires config")

    local definition = config.definition or config

    assert(type(definition) == "table", "Runtime requires a definition")
    assert(type(definition.flow) == "table", "Definition requires a flow")
    assert(
        type(definition.flow.stages) == "table",
        "Flow requires stages"
    )
    assert(
        type(definition.components) == "table",
        "Definition requires components"
    )

    local self = setmetatable({}, Runtime)

    self.id = config.id or definition.id or "flight-runtime"
    self.interval = config.interval or 0.05

    assert(
        type(self.interval) == "number" and self.interval > 0,
        "Runtime interval must be a positive number"
    )

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

    -- Register local component instances by ID.
    for id, component in pairs(definition.components) do
        assert(
            type(id) == "string",
            "Component registry keys must be strings"
        )
        assert(
            type(component) == "table",
            "Invalid component: " .. id
        )
        assert(
            component.id == id,
            "Component registry key does not match component id: " .. id
        )
        assert(
            type(component.update) == "function",
            "Component " .. id .. " requires update()"
        )

        self.components[id] = component
    end

    -- Validate nodes and discover local producers and dependencies.
    for stageIndex, stage in ipairs(self.flow.stages) do
        assert(
            type(stage) == "table",
            "Stage " .. stageIndex .. " must be a table"
        )
        assert(
            type(stage.components) == "table",
            "Stage " .. stageIndex .. " requires components"
        )

        for nodeIndex, node in ipairs(stage.components) do
            local label = "Stage " .. stageIndex
                .. ", node " .. nodeIndex

            assert(type(node) == "table", label .. " must be a table")
            assert(ROLES[node.role], label .. " has an invalid role")

            assert(
                node.config == nil or type(node.config) == "table",
                label .. " config must be a table"
            )

            node.execution = getExecutionPolicy(node)
            node.started = false

            if node.remote then
                assert(
                    node.component == nil,
                    label .. " remote nodes cannot have components"
                )

                if node.role == "source" then
                    assert(
                        type(node.output) == "string",
                        label .. " remote source requires an output signal"
                    )

                    self.explicitRemoteSignals[node.output] = true
                elseif node.role == "sink" then
                    assert(
                        node.publish == true,
                        label .. " remote sink must publish"
                    )
                    assert(
                        type(node.inputs) == "table",
                        label .. " remote sink requires inputs"
                    )

                    node.inputs = bindingList(node.inputs)

                    for _, binding in ipairs(node.inputs) do
                        assert(
                            binding.accessor == nil,
                            label .. " remote sink cannot publish an "
                            .. "accessor binding; publish the derived "
                            .. "value on its own signal instead"
                        )

                        self.publishSignals[binding.signal] = true
                    end
                else
                    error(label .. " cannot be a remote processor")
                end
            else
                assert(
                    type(node.component) == "string",
                    label .. " requires a component ID"
                )
                assert(
                    self.components[node.component],
                    label .. " references an unregistered component: "
                    .. node.component
                )

                if node.role == "source" then
                    assert(
                        type(node.output) == "string",
                        label .. " source requires an output"
                    )
                    assert(
                        node.inputs == nil,
                        label .. " source cannot have inputs"
                    )
                elseif node.role == "processor" then
                    assert(
                        type(node.output) == "string",
                        label .. " processor requires an output"
                    )
                    assert(
                        type(node.inputs) == "table",
                        label .. " processor requires inputs"
                    )

                    node.inputs = bindingList(node.inputs)
                else
                    assert(
                        node.output == nil,
                        label .. " sink cannot have an output"
                    )
                    assert(
                        type(node.inputs) == "table",
                        label .. " sink requires inputs"
                    )

                    node.inputs = bindingList(node.inputs)
                end

                -- Each output signal has at most one local producer.
                if node.output then
                    assert(
                        not self.localOutputs[node.output],
                        "Multiple local producers for signal: "
                        .. node.output
                    )

                    self.localOutputs[node.output] = true
                end

                -- Collect underlying signal names, not accessors.
                if node.role ~= "source" then
                    for _, binding in ipairs(node.inputs) do
                        self.neededSignals[binding.signal] = true
                    end
                end
            end
        end
    end

    -- Determine which dependencies must be received remotely.
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

    -- Only locally produced signals may be published.
    for signal in pairs(self.publishSignals) do
        assert(
            self.localOutputs[signal],
            "Remote sink can only publish a locally produced signal: "
            .. signal
        )
    end

    -- Open messaging only when remote I/O is required.
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

    -- Keep only the latest received value for each relevant topic.
    local received = {}

    for _, message in ipairs(self.bus:getMessages() or {}) do
        local topic = message.topic

        if type(topic) == "string" and (
                self.neededSignals[topic]
                or self.explicitRemoteSignals[topic]
            ) then
            received[topic] = message.content
        end
    end

    return received
end

function Runtime:_publishBatch(batch)
    if not self.bus or #batch == 0 then
        return
    end

    assert(
        type(self.bus.publishBatch) == "function",
        "Messaging bus must implement publishBatch(batch)"
    )

    self.bus:publishBatch(batch)
end

-- Resolve bindings into positional arguments.
-- Explicit count preserves optional nil arguments.
function Runtime:_resolveInputs(bindings)
    local args = {}
    local count = 0

    for index, rawBinding in ipairs(bindings or {}) do
        local binding = resolveBinding(rawBinding)
        local value = self.signals[binding.signal]

        if value ~= nil then
            value = resolveAccessor(value, binding.accessor)
        end

        if value == nil and not binding.optional then
            return nil, count, false
        end

        count = index
        args[index] = value
    end

    return args, count, true
end

function Runtime:_inputsChanged(bindings, changed)
    for _, rawBinding in ipairs(bindings or {}) do
        local binding = resolveBinding(rawBinding)

        if changed[binding.signal] then
            return true
        end
    end

    return false
end

function Runtime:_setSignal(signal, value, changed, outgoing)
    if value == nil then
        -- Nil means no update; retain the cached value.
        return
    end

    local previous = self.signals[signal]

    if valuesEqual(previous, value) then
        return
    end

    self.signals[signal] = value
    changed[signal] = true

    -- Publish only explicitly configured remote sink signals.
    if self.publishSignals[signal] then
        outgoing[signal] = {
            topic = signal,
            content = value,
        }
    end
end

function Runtime:_executeNode(node, changed)
    if node.remote then
        return nil
    end

    local component = self.components[node.component]

    assert(
        component and type(component.update) == "function",
        "Component " .. tostring(node.component) .. " requires update()"
    )

    local policy = node.execution

    -- Sources have no inputs to trigger execution.
    -- on_change and always poll every tick.
    -- on_start polls only once.
    if node.role == "source" then
        if policy == "on_start" and node.started then
            return nil
        end

        return {
            node = node,
            signal = node.output,
            value = component:update(),
        }
    end

    local inputsChanged = self:_inputsChanged(node.inputs, changed)

    -- on_start means initial execution followed by on_change behavior.
    local shouldRun =
        policy == "always"
        or inputsChanged
        or (policy == "on_start" and not node.started)

    if not shouldRun then
        return nil
    end

    local args, count, ready = self:_resolveInputs(node.inputs)

    if not ready then
        return nil
    end

    if node.role == "processor" then
        return {
            node = node,
            signal = node.output,
            value = component:update(unpackValues(args, 1, count)),
        }
    end

    component:update(unpackValues(args, 1, count))

    return {
        node = node,
        executed = true,
    }
end

function Runtime:update()
    -- Apply the complete incoming network batch before evaluating stages.
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

    -- Each stage is a parallel execution barrier.
    for _, stage in ipairs(self.flow.stages) do
        local nodes = stage.components
        local results = {}

        if #nodes > 0 then
            local tasks = {}

            for index, node in ipairs(nodes) do
                local nodeIndex = index
                local currentNode = node

                tasks[#tasks + 1] = function()
                    results[nodeIndex] =
                        self:_executeNode(currentNode, changed)
                end
            end

            -- All nodes finish before outputs are committed.
            parallel.waitForAll(unpackValues(tasks))
        end

        -- Commit outputs only after every node in the stage has completed.
        for index = 1, #nodes do
            local result = results[index]

            if result then
                -- Mark started only after actual execution.
                if result.node then
                    result.node.started = true
                end

                if result.signal then
                    self:_setSignal(
                        result.signal,
                        result.value,
                        changed,
                        outgoing
                    )
                end
            end
        end
    end

    -- Publish accumulated changes as a single batch.
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
    if self.running then
        return
    end

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
