local Actuator = {}

function Actuator.new(id, modulate, set)
    assert(type(id) == "string", "Actuator requires an id")

    assert(
        modulate == nil or type(modulate) == "function",
        "Actuator modulate must be a function or nil"
    )

    assert(type(set) == "function",
        "Actuator requires a set function")

    local self = {
        id = id,
        role = "sink",
        modulate = modulate,
        set = set,
    }

    function self:update(inputs)
        assert(type(inputs) == "table",
            "Actuator inputs must be a table")

        local value = next(inputs) and select(2, next(inputs))

        assert(
            type(value) == "number" and value >= -1 and value <= 1,
            "Actuator input must be a number between -1 and 1"
        )

        if self.modulate then
            value = self.modulate(value)
        end

        self.set(value)
    end

    return self
end

return Actuator
