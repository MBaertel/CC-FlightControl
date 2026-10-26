local Monitor = {}

function Monitor.new(id, write)
    assert(type(id) == "string", "Monitor requires an id")
    assert(type(write) == "function", "Monitor requires a write function")

    local self = {
        id = id,
        role = "sink",
        write = write,
    }

    function self:update(inputs)
        assert(type(inputs) == "table", "Monitor inputs must be a table")

        local value
        local count = 0

        for _, input in pairs(inputs) do
            count = count + 1
            value = input
        end

        assert(count == 1, "Monitor requires exactly one input")

        self:display(value)
    end

    function self:display(value)
        error(
            "Monitor '" .. self.id .. "' must implement display(value)",
            2
        )
    end

    return self
end

return Monitor
