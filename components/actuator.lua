local Actuator = {}
Actuator.__index = Actuator

function Actuator.new(modulate, set)
    return setmetatable({
        modulate = modulate,
        set = set,
    }, Actuator)
end

function Actuator:update(input)
    if input ~= nil then
        if type(input) ~= "number"
            or input ~= input
            or input < -1
            or input > 1 then
            input = nil
        end
    end

    if input ~= nil and self.modulate then
        input = self.modulate(input)
    end

    self.set(input)
end

return Actuator
