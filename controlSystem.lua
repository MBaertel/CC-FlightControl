local FlightControl = {}
FlightControl.__index = FlightControl

local CATEGORY = {
    input = "inputs",
    sensor = "sensors",
    controller = "demands",
    mixer = "outputs",
    actuator = "actuators",
}

local function signalName(category, name)
    local prefix = category .. "."

    if name:sub(1, #prefix) == prefix then
        return name
    end

    return prefix .. name
end

local function shortName(category, name)
    local prefix = category .. "."

    if name:sub(1, #prefix) == prefix then
        return name:sub(#prefix + 1)
    end

    return name
end

local function makeSet(values, category)
    local result = {}

    for key, value in pairs(values or {}) do
        local name

        if type(key) == "number" then
            name = value
        elseif value then
            name = key
        end

        if type(name) == "string" then
            result[signalName(category, name)] = true
        end
    end

    return result
end

local function subscribeExternal(bus, external)
    for _, signals in pairs(external) do
        for topic in pairs(signals) do
            bus:subscribe(topic)
        end
    end
end

function FlightControl.new(config)
    config = config or {}

    assert(type(config.id) == "string",
        "FlightControl requires an id")
    assert(config.bus,
        "FlightControl requires a bus")

    local external = {
        inputs = makeSet(
            config.external and config.external.inputs,
            "inputs"
        ),
        sensors = makeSet(
            config.external and config.external.sensors,
            "sensors"
        ),
        demands = makeSet(
            config.external and config.external.demands,
            "demands"
        ),
        outputs = makeSet(
            config.external and config.external.outputs,
            "outputs"
        ),
    }

    local self = setmetatable({
        id = config.id,
        bus = config.bus,

        components = {
            input = {},
            sensor = {},
            controller = {},
            mixer = {},
            actuator = {},
        },

        inputs = {},
        sensors = {},
        state = {},
        demands = {},
        outputs = {},

        external = external,
    }, FlightControl)

    subscribeExternal(self.bus, self.external)

    return self
end

function FlightControl:register(component, kind, spec)
    spec = spec or {}

    assert(CATEGORY[kind],
        "Unknown component type: " .. tostring(kind))
    assert(type(component) == "table",
        "Component must be a table")
    assert(type(component.name) == "string",
        "Component requires a name")
    assert(type(component.update) == "function",
        "Component requires an update method")

    local registry = self.components[kind]
    local name = component.name

    assert(not registry[name],
        "Duplicate " .. kind .. ": " .. name)

    registry[name] = {
        object = component,
        public = spec.public == true,
    }

    return component
end

function FlightControl:registerInput(component, spec)
    return self:register(component, "input", spec)
end

function FlightControl:registerSensor(component, spec)
    return self:register(component, "sensor", spec)
end

function FlightControl:registerController(component, spec)
    return self:register(component, "controller", spec)
end

function FlightControl:registerMixer(component, spec)
    return self:register(component, "mixer", spec)
end

function FlightControl:registerActuator(component, spec)
    return self:register(component, "actuator", spec)
end

-- Publish to the fully qualified topic.
-- hasValue=false communicates that the signal should be cleared.
function FlightControl:_publish(category, name, value)
    local content = {
        hasValue = value ~= nil,
    }

    if value ~= nil then
        content.value = value
    end

    self.bus:publish(signalName(category, name), content)
end

function FlightControl:_publishIfPublic(entry, category, name, value)
    if entry.public then
        self:_publish(category, name, value)
    end
end

-- Receive configured external signals.
-- Store them under short names and never republish them.
function FlightControl:_receive()
    for _, message in ipairs(self.bus:getMessages() or {}) do
        local topic = message.topic

        if type(topic) == "string" then
            for category, allowed in pairs(self.external) do
                local prefix = category .. "."

                if topic:sub(1, #prefix) == prefix
                    and allowed[topic] then
                    local name = shortName(category, topic)
                    local content = message.content
                    local value

                    if type(content) == "table"
                        and type(content.hasValue) == "boolean" then
                        if content.hasValue then
                            value = content.value
                        end
                    else
                        -- Accept plain-value messages as well.
                        value = content
                    end

                    local target

                    if category == "inputs" then
                        target = self.inputs
                    elseif category == "sensors" then
                        target = self.sensors
                    elseif category == "demands" then
                        target = self.demands
                    elseif category == "outputs" then
                        target = self.outputs
                    end

                    if target then
                        target[name] = value
                    end
                end
            end
        end
    end
end

function FlightControl:_collectInputs()
    for name, entry in pairs(self.components.input) do
        local value = entry.object:update()

        self.inputs[name] = value
        self:_publishIfPublic(entry, "inputs", name, value)
    end
end

function FlightControl:_collectSensors()
    for name, entry in pairs(self.components.sensor) do
        local value = entry.object:update()

        self.sensors[name] = value
        self:_publishIfPublic(entry, "sensors", name, value)
    end
end

function FlightControl:_runControllers()
    for _, entry in pairs(self.components.controller) do
        local result = entry.object:update(
            self.sensors,
            self.inputs,
            self.state
        )

        if type(result) == "table" then
            for signal, value in pairs(result) do
                local name = shortName("demands", signal)

                self.demands[name] = value
                self:_publishIfPublic(
                    entry,
                    "demands",
                    name,
                    value
                )
            end
        end
    end
end

function FlightControl:_runMixers()
    for name, entry in pairs(self.components.mixer) do
        local value = entry.object:update(self.demands)

        self.outputs[name] = value
        self:_publishIfPublic(
            entry,
            "outputs",
            name,
            value
        )
    end
end

function FlightControl:_updateActuators()
    for name, entry in pairs(self.components.actuator) do
        -- Plant/actuator names correspond to output names.
        entry.object:update(self.outputs[name])
    end
end

function FlightControl:update()
    -- 1. Receive external signals and collect local inputs.
    self:_receive()
    self:_collectInputs()

    -- 2. Collect local sensors.
    self:_collectSensors()

    -- 3. Run controllers.
    self:_runControllers()

    -- 4. Run mixers.
    self:_runMixers()

    -- 5. Apply actuator outputs.
    self:_updateActuators()
end

return FlightControl
