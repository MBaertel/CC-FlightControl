local Source = {}

function Source.new(id, read)
    assert(type(read) == "function", "Source requires read")

    return {
        id = id,

        update = function()
            return read()
        end,
    }
end

return Source
