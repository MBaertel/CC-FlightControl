local Monitor = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Monitor.new(id, write)
    assertString(id, "Monitor requires an id")
    assert(
        type(write) == "function",
        "Monitor requires a write function"
    )

    local monitor = {
        id = id,
        role = "sink",
    }

    function monitor:update(value)
        assert(value ~= nil, "Monitor requires a non-nil input value")
        write(value)
    end

    function monitor:display(value)
        write(value)
    end

    return monitor
end

return Monitor
