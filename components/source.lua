local Source = {}

function Source.new(name, read)
    assert(type(read) == "function", "Source requires read")

    return {
        name = name,

        update = function(self)
            return read()
        end,
    }
end

return Source
