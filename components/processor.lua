local Processor = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Processor.new(id, process, args)
    assertString(id, "Processor requires an id")
    assert(type(process) == "function", "Processor requires a process function")

    if args ~= nil then
        assert(type(args) == "table", "Processor args must be a table")

        for i, name in ipairs(args) do
            assertString(name, "Processor argument names must be non-empty strings")
        end
    end

    local processor = {
        id = id,
        role = "processor",
        args = args,
    }

    function processor:update(...)
        return process(...)
    end

    return processor
end

return Processor
