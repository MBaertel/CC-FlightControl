local Sink = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Sink.new(id, apply)
    assertString(id, "Sink requires an id")
    assert(type(apply) == "function", "Sink requires an apply function")

    local sink = {
        id = id,
        role = "sink",
    }

    function sink:update(...)
        apply(...)
    end

    return sink
end

return Sink
