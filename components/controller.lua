local Controller = {}
Controller.__index = Controller

function Controller.new(name, control)
    assert(type(name) == "string", "Controller requires a name")
    assert(type(control) == "function", "Controller requires a control function")

    return setmetatable({
        name = name,
        control = control,
    }, Controller)
end

function Controller:update(sensors, inputs, state, dt)
    return self.control(sensors, inputs, state, dt)
end

return Controller
