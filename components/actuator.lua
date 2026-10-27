local Actuator = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Actuator.new(id, modulate, set)
    assertString(id, "Actuator requires an id")

    assert(
        modulate == nil or type(modulate) == "function",
        "Actuator modulate must be a function or nil"
    )

    assert(
        type(set) == "function",
        "Actuator requires a set function"
    )

    local actuator = {
        id = id,
        role = "sink",
        modulate = modulate,
        set = set,
    }

    function actuator:update(value)
        assert(
            type(value) == "number" and value >= -1 and value <= 1,
            "Actuator input must be a number between -1 and 1"
        )

        if self.modulate then
            value = self.modulate(value)
        end

        self.set(value)
    end

    return actuator
end

return Actuator
