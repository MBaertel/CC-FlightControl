local Processor = {}

function Processor.new(id, process)
    assert(type(process) == "function", "Processor requires process")

    return {
        name = id,
        update = function(self, inputs, signals, context)
            return process(inputs, signals, context)
        end,
    }
end

return Processor
