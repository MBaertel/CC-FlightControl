local Processor = {}

function Processor.new(name, process)
    assert(type(process) == "function", "Processor requires process")

    return {
        name = name,

        update = function(self, inputs, signals, context)
            return process(inputs, signals, context)
        end,
    }
end

return Processor
