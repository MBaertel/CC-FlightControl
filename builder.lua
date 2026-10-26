-- flow/builder.lua

local Builder = {}
Builder.__index = Builder

local function isComponent(value)
    return type(value) == "table"
        and type(value.id) == "string"
        and type(value.update) == "function"
end

local function validateSignal(signal, label)
    assert(
        type(signal) == "string" and signal ~= "",
        label .. " requires a non-empty signal name"
    )
end

local function validateInputs(inputs, label)
    assert(type(inputs) == "table", label .. " requires inputs")

    for name, binding in pairs(inputs) do
        assert(type(name) == "string" and name ~= "",
            label .. " input names must be non-empty strings")

        if type(binding) == "string" then
            validateSignal(binding, label .. " input " .. name)
        else
            assert(
                type(binding) == "table"
                and type(binding.signal) == "string"
                and binding.signal ~= "",
                label .. " input " .. name
                .. " must be a signal name or binding table"
            )

            if binding.optional ~= nil then
                assert(type(binding.optional) == "boolean",
                    label .. " input " .. name
                    .. " optional must be a boolean")
            end
        end
    end
end

function Builder.new(config)
    config = config or {}

    assert(type(config) == "table", "Builder config must be a table")

    local self = setmetatable({}, Builder)

    self.id = config.id or "flight-runtime"
    self.stages = {}
    self.components = {}
    self.componentIds = {}
    self.nextNodeId = 1
    self.currentStage = nil

    return self
end

function Builder:stage(name)
    assert(type(name) == "string" and name ~= "",
        "Stage requires a non-empty name")

    local stage = {
        name = name,
        components = {},
    }

    table.insert(self.stages, stage)
    self.currentStage = stage

    return self
end

function Builder:_ensureStage()
    if not self.currentStage then
        self:stage("main")
    end
end

function Builder:_registerComponent(component)
    assert(isComponent(component),
        "Component must have a string id and an update function")

    local id = component.id

    if self.componentIds[id] then
        assert(self.components[id] == component,
            "Duplicate component id: " .. id)
        return id
    end

    self.componentIds[id] = true
    self.components[id] = component

    return id
end

function Builder:_addNode(component, role, inputs, output)
    self:_ensureStage()

    local componentId = self:_registerComponent(component)

    local node = {
        id = "node_" .. self.nextNodeId,
        component = componentId,
        role = role,
        inputs = inputs,
        output = output,
    }

    self.nextNodeId = self.nextNodeId + 1
    table.insert(self.currentStage.components, node)

    return self
end

function Builder:_addRemoteSource(signal)
    validateSignal(signal, "Remote source")
    self:_ensureStage()

    local node = {
        id = "node_" .. self.nextNodeId,
        component = nil,
        role = "source",
        output = signal,
        remote = true,
    }

    self.nextNodeId = self.nextNodeId + 1
    table.insert(self.currentStage.components, node)

    return self
end

function Builder:_addRemoteSink(inputs)
    validateInputs(inputs, "Remote sink")
    self:_ensureStage()

    local node = {
        id = "node_" .. self.nextNodeId,
        component = nil,
        role = "sink",
        inputs = inputs,
        remote = true,
        publish = true,
    }

    self.nextNodeId = self.nextNodeId + 1
    table.insert(self.currentStage.components, node)

    return self
end

-- Local source:
-- builder:source(component, "sensor.altitude")
--
-- Remote source:
-- builder:source("demand.throttle")
function Builder:source(componentOrSignal, output)
    if type(componentOrSignal) == "string" and output == nil then
        return self:_addRemoteSource(componentOrSignal)
    end

    assert(isComponent(componentOrSignal),
        "Local source requires a component instance")
    validateSignal(output, "Local source output")

    return self:_addNode(componentOrSignal, "source", nil, output)
end

-- Local processor:
-- builder:processor(component, inputs, "demand.throttle")
function Builder:processor(component, inputs, output)
    assert(isComponent(component),
        "Processor requires a component instance")
    validateInputs(inputs, "Processor")
    validateSignal(output, "Processor output")

    return self:_addNode(component, "processor", inputs, output)
end

-- Local sink:
-- builder:sink(component, inputs)
--
-- Remote publishing sink:
-- builder:sink(inputs)
function Builder:sink(componentOrInputs, inputs)
    if inputs == nil then
        assert(type(componentOrInputs) == "table",
            "Remote sink requires an inputs table")

        return self:_addRemoteSink(componentOrInputs)
    end

    assert(isComponent(componentOrInputs),
        "Local sink requires a component instance")
    validateInputs(inputs, "Sink")

    return self:_addNode(componentOrInputs, "sink", inputs, nil)
end

function Builder:build()
    assert(#self.stages > 0, "Cannot build an empty flow")

    return {
        id = self.id,
        flow = {
            stages = self.stages,
        },
        components = self.components,
    }
end

return Builder
