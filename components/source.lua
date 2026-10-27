local Source = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Source.new(id, read)
    assertString(id, "Source requires an id")
    assert(type(read) == "function", "Source requires a read function")

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        return read()
    end

    return source
end

return Source
