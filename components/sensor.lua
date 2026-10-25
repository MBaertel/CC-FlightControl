local Sensor = {}
Sensor.__index = Sensor

function Sensor.new(name, read)
    return setmetatable({
        name = name,
        read = read,
    }, Sensor)
end

function Sensor:update()
    return self.read()
end

return Sensor
