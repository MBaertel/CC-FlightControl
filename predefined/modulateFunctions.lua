local ModulateFunctions = {}

function ModulateFunctions.compose(...)
    local functions = { ... }

    return function(value)
        for _, fn in ipairs(functions) do
            value = fn(value)
        end

        return value
    end
end

function ModulateFunctions.identity(value)
    return value
end

function ModulateFunctions.reverse(value)
    return -value
end

function ModulateFunctions.unipolar(value)
    return (value + 1) / 2
end

function ModulateFunctions.bipolar(value)
    return (2 * value) - 1
end

function ModulateFunctions.redstoneUnipolar(value)
    return math.floor((value + 1) * 7.5 + 0.5)
end

function ModulateFunctions.redstoneBipolar(value)
    if value == 0 then
        return 7
    elseif value <= 0 then
        return math.floor((value + 1) * 7)
    else
        return math.floor(7 + value * 8)
    end
end

return ModulateFunctions
