local Sink = {}

function Sink.new(id, apply)
    assert(type(apply) == "function", "Actuator requires apply")

    return {
        id = id,
        update = function(self, inputs, signals, context)
            apply(inputs, signals, context)
        end,
    }
end

return Sink
