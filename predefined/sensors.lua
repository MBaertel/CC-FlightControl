local Sensors = {}

function Sensors.altitudeSensor(id, peripheralName)
    assert(type(id) == "string", "Sensor requires an id")
    assert(type(peripheralName) == "string", "Sensor requires peripheralName")

    local source = {
        id = id,
        role = "source"
    }

    local sensorBlock = peripheral.wrap(peripheralName)

    function source:update()
        return {
            altitude = sensorBlock.getHeight(),
            verticalSpeed = sensorBlock.getVerticalSpeed(),
            pressure = sensorBlock.getAirPressure()
        }
    end

    return source
end

function Sensors.gimbal(id, peripheralName)
    assert(type(id) == "string", "Sensor requires an id")
    assert(type(peripheralName) == "string", "Sensor requires peripheralName")

    local source = {
        id = id,
        role = "source"
    }

    local sensorBlock = peripheral.wrap(peripheralName)

    function source:update()
        local angles = sensorBlock.getAngles()
        local angularRates = sensorBlock.getAngularRates()
        return {
            x = angles[1],
            z = angles[2],
            xVelocity = angularRates[1],
            yVelocity = angularRates[2],
            zVelocity = angularRates[3]
        }
    end

    return source
end

function Sensors.navigationTable(id, peripheralName)
    assert(type(id) == "string", "Sensor requires an id")
    assert(type(peripheralName) == "string", "Sensor requires peripheralName")

    local source = {
        id = id,
        role = "source"
    }

    local sensorBlock = peripheral.wrap(peripheralName)

    function source:update()
        return {
            heading = sensorBlock.getHeading(),
            hasTarget = sensorBlock.hasTarget(),
            targetOffset = sensorBlock.getRelativeAngle()
        }
    end

    return source
end

function Sensors.laser(id, peripheralName)
    assert(type(id) == "string", "Sensor requires an id")
    assert(type(peripheralName) == "string", "Sensor requires peripheralName")

    local source = {
        id = id,
        role = "source"
    }

    local sensorBlock = peripheral.wrap(peripheralName)

    function source:update()
        return sensorBlock.getClosestHitDistance()
    end

    return source
end

return Sensors
