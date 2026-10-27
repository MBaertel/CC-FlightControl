local Builder = {}
Builder.__index = Builder

local EXECUTION_POLICIES = {
    on_change = true,
    always = true,
    on_start = true,
}

-- Component validation

local function isComponent(value)
    return type(value) == "table"
        and type(value.id) == "string"
        and type(value.update) == "function"
end

-- Normalize node configuration.

local function normalizeConfig(config, label)
    if config == nil then
        config = {}
    end

    assert(
        type(config) == "table",
        label .. ": config must be a table"
    )

    local execution = config.execution or "on_change"

    assert(
        EXECUTION_POLICIES[execution],
        label .. ": invalid execution policy: "
        .. tostring(execution)
    )

    return {
        execution = execution,
    }
end

-- Parse a signal binding.
-- "sensor/altitude.raw" -> signal "sensor/altitude", accessor "raw"
-- A binding table may also specify { signal = "...", optional = true }.

local function parseBinding(binding, label)
    local signal
    local optional = false

    if type(binding) == "string" then
        signal = binding
    elseif type(binding) == "table" then
        signal = binding.signal
        optional = binding.optional == true

        assert(
            binding.optional == nil
            or type(binding.optional) == "boolean",
            label .. ": optional must be a boolean"
        )
    else
        error(label .. ": expected a signal string or binding table")
    end

    assert(
        type(signal) == "string" and signal ~= "",
        label .. ": signal must be a non-empty string"
    )

    local base, accessor = signal:match("^([^%.]+)%.(.+)$")

    if base then
        signal = base

        assert(
            not accessor:match("^%.")
            and not accessor:match("%.$")
            and not accessor:find("%.%.", 1, true),
            label .. ": invalid accessor path"
        )
    else
        assert(
            not signal:find(".", 1, true),
            label .. ": invalid signal/accessor syntax"
        )
    end

    assert(
        not signal:match("^/")
        and not signal:match("/$")
        and not signal:find("//", 1, true),
        label .. ": invalid signal name"
    )

    return {
        signal = signal,
        accessor = accessor,
        optional = optional,
    }
end

-- Check whether a table is a dense positional array.

local function isArray(value)
    local count = 0
    local maxIndex = 0

    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0 then
            return false
        end

        count = count + 1

        if key > maxIndex then
            maxIndex = key
        end
    end

    return count == maxIndex
end

-- Normalize component inputs into an ordered array.

local function normalizeInputs(component, inputs, label)
    if type(inputs) == "string" then
        inputs = { inputs }
    end

    assert(
        type(inputs) == "table",
        label .. ": inputs must be a string or table"
    )

    if next(inputs) == nil then
        return {}
    end

    local result = {}

    if isArray(inputs) then
        for i = 1, #inputs do
            result[i] = parseBinding(
                inputs[i],
                label .. " input " .. i
            )
        end

        return result
    end

    assert(
        type(component) == "table"
        and type(component.args) == "table",
        label .. ": named bindings require component.args"
    )

    local seen = {}

    for i, name in ipairs(component.args) do
        assert(
            type(name) == "string" and name ~= "",
            label .. ": component.args must contain non-empty strings"
        )

        assert(
            not seen[name],
            label .. ": duplicate component argument " .. name
        )

        assert(
            inputs[name] ~= nil,
            label .. ": missing binding for argument " .. name
        )

        result[i] = parseBinding(
            inputs[name],
            label .. " input " .. name
        )

        seen[name] = true
    end

    for name in pairs(inputs) do
        assert(
            type(name) == "string" and seen[name],
            label .. ": unknown named input " .. tostring(name)
        )
    end

    return result
end

-- Normalize remote publication bindings.
-- Named keys are sorted to ensure deterministic order.

local function normalizeRemoteInputs(inputs)
    if type(inputs) == "string" then
        inputs = { inputs }
    end

    assert(
        type(inputs) == "table",
        "Remote sink requires a string or binding table"
    )

    local result = {}

    if isArray(inputs) then
        for i = 1, #inputs do
            result[i] = parseBinding(
                inputs[i],
                "Remote sink input " .. i
            )
        end

        return result
    end

    local names = {}

    for name in pairs(inputs) do
        assert(
            type(name) == "string",
            "Remote sink named binding keys must be strings"
        )

        table.insert(names, name)
    end

    table.sort(names)

    for i, name in ipairs(names) do
        result[i] = parseBinding(
            inputs[name],
            "Remote sink input " .. name
        )
        result[i].name = name
    end

    return result
end

-- Builder

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
    assert(
        type(name) == "string" and name ~= "",
        "Stage requires a non-empty name"
    )

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
    assert(
        isComponent(component),
        "Component must have a string id and an update function"
    )

    local id = component.id

    if self.componentIds[id] then
        assert(
            self.components[id] == component,
            "Duplicate component id: " .. id
        )

        return id
    end

    self.componentIds[id] = true
    self.components[id] = component

    return id
end

function Builder:_nextNodeId()
    local id = "node_" .. self.nextNodeId
    self.nextNodeId = self.nextNodeId + 1
    return id
end

function Builder:_addNode(component, role, inputs, output, config)
    self:_ensureStage()

    local componentId = self:_registerComponent(component)
    local normalizedConfig = normalizeConfig(config, role)

    local node = {
        id = self:_nextNodeId(),
        component = componentId,
        role = role,
        inputs = inputs,
        output = output,
        config = normalizedConfig,
    }

    table.insert(self.currentStage.components, node)

    return self
end

-- Sources
--
-- Local:
--   builder:source(sensor, nil, "sensor/altitude", config)
--   builder:source(sensor, "sensor/altitude", config)
--
-- Remote:
--   builder:source("sensor/altitude", config)

function Builder:_addRemoteSource(signal, config)
    local binding = parseBinding(signal, "Remote source")

    assert(
        not binding.accessor,
        "Remote source accessors are not supported; "
        .. "bind the accessor on a consuming node instead"
    )

    self:_ensureStage()

    local node = {
        id = self:_nextNodeId(),
        component = nil,
        role = "source",
        output = binding.signal,
        remote = true,
        config = normalizeConfig(config, "Remote source"),
    }

    table.insert(self.currentStage.components, node)

    return self
end

function Builder:source(componentOrSignal, inputs, output, config)
    -- Remote source: source(signal [, config])
    if type(componentOrSignal) == "string" then
        assert(
            output == nil,
            "Remote source accepts a signal and optional config"
        )

        if inputs ~= nil then
            assert(
                type(inputs) == "table",
                "Remote source config must be a table"
            )

            assert(
                config == nil,
                "Remote source config was provided twice"
            )

            config = inputs
        end

        return self:_addRemoteSource(componentOrSignal, config)
    end

    -- Validate local source component.
    assert(
        isComponent(componentOrSignal),
        "Local source requires a component instance"
    )

    -- Support:
    -- source(component, output)
    -- source(component, output, config)
    if type(inputs) == "string" then
        if output == nil then
            -- source(component, output)
            output = inputs
            inputs = nil
        elseif type(output) == "table" and config == nil then
            -- source(component, output, config)
            config = output
            output = inputs
            inputs = nil
        end
    end

    -- Sources cannot have input bindings.
    assert(
        inputs == nil,
        "Source cannot have inputs"
    )

    -- Validate output signal.
    assert(
        type(output) == "string" and output ~= "",
        "Local source requires an output signal"
    )

    local binding = parseBinding(output, "Local source output")

    assert(
        not binding.accessor,
        "Source output cannot contain an accessor"
    )

    return self:_addNode(
        componentOrSignal,
        "source",
        nil,
        binding.signal,
        config
    )
end

-- Processors
--
-- builder:processor(component, inputs, output [, config])

function Builder:processor(component, inputs, output, config)
    assert(
        isComponent(component),
        "Processor requires a component instance"
    )

    assert(
        type(output) == "string" and output ~= "",
        "Processor requires an output signal"
    )

    local outputBinding = parseBinding(output, "Processor output")

    assert(
        not outputBinding.accessor,
        "Processor output cannot contain an accessor"
    )

    local normalized = normalizeInputs(
        component,
        inputs,
        "Processor"
    )

    return self:_addNode(
        component,
        "processor",
        normalized,
        outputBinding.signal,
        config
    )
end

-- Sinks
--
-- Local:
--   builder:sink(component, inputs [, config])
--   builder:sink(component, input1, input2, ... [, config])
--
-- Remote:
--   builder:sink(signalOrBindings [, config])

function Builder:_addRemoteSink(inputs, config)
    local normalized = normalizeRemoteInputs(inputs)

    self:_ensureStage()

    local node = {
        id = self:_nextNodeId(),
        component = nil,
        role = "sink",
        inputs = normalized,
        remote = true,
        publish = true,
        config = normalizeConfig(config, "Remote sink"),
    }

    table.insert(self.currentStage.components, node)

    return self
end

function Builder:sink(componentOrInputs, ...)
    local count = select("#", ...)
    local args = { ... }

    if not isComponent(componentOrInputs) then
        assert(
            count <= 1,
            "Remote sink accepts bindings and optional config"
        )

        local config

        if count == 1 then
            config = args[1]
            assert(
                config == nil or type(config) == "table",
                "Remote sink config must be a table"
            )
        end

        return self:_addRemoteSink(componentOrInputs, config)
    end

    assert(count > 0, "Local sink requires at least one input")

    local config
    local inputs

    -- A trailing config table is recognized by its execution field.
    -- This preserves named input tables and positional input bindings.
    if count >= 2
        and type(args[count]) == "table"
        and args[count].execution ~= nil then
        config = args[count]
        args[count] = nil
        count = count - 1
    end

    if count == 1 then
        inputs = args[1]
    else
        inputs = {}

        for i = 1, count do
            inputs[i] = args[i]
        end
    end

    local normalized = normalizeInputs(
        componentOrInputs,
        inputs,
        "Sink"
    )

    return self:_addNode(
        componentOrInputs,
        "sink",
        normalized,
        nil,
        config
    )
end

-- Build the flow definition.

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
