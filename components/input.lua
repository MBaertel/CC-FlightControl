local Input = {}
Input.__index = Input

function Input.new(name, read)
    return setmetatable({
        name = name,
        read = read,
    }, Input)
end

function Input:update()
    return self.read()
end

return Input
