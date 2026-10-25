local Input = {}
Input.__index = Input

function Input.new(read)
    return setmetatable({
        read = read,
    }, Input)
end

function Input:update()
    return self.read()
end

return Input
