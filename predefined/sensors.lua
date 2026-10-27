local Sensors = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString
local wrapPeripheral = Validation.wrapPeripheral

function Sensors.altitudeSensor(id, peripheralName)
    assertString(id, "Altitude sensor requires an id")
    assertString(peripheralName, "Altitude sensor requires peripheralName")

    local sensorBlock = wrapPeripheral(peripheralName)

    assert(
        type(sensorBlock.getHeight) == "function",
        "Altitude sensor requires getHeight()"
    )
    assert(
        type(sensorBlock.getVerticalSpeed) == "function",
        "Altitude sensor requires getVerticalSpeed()"
    )
    assert(
        type(sensorBlock.getAirPressure) == "function",
        "Altitude sensor requires getAirPressure()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        return {
            altitude = sensorBlock.getHeight(),
            verticalSpeed = sensorBlock.getVerticalSpeed(),
            pressure = sensorBlock.getAirPressure(),
        }
    end

    return source
end

function Sensors.gimbal(id, peripheralName)
    assertString(id, "Gimbal sensor requires an id")
    assertString(peripheralName, "Gimbal sensor requires peripheralName")

    local sensorBlock = wrapPeripheral(peripheralName)

    assert(
        type(sensorBlock.getAngles) == "function",
        "Gimbal sensor requires getAngles()"
    )
    assert(
        type(sensorBlock.getAngularRates) == "function",
        "Gimbal sensor requires getAngularRates()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        local angles = sensorBlock.getAngles()
        local angularRates = sensorBlock.getAngularRates()

        return {
            x = angles[1],
            z = angles[2],
            xVelocity = angularRates[1],
            yVelocity = angularRates[2],
            zVelocity = angularRates[3],
        }
    end

    return source
end

function Sensors.navigationTable(id, peripheralName)
    assertString(id, "Navigation table requires an id")
    assertString(peripheralName, "Navigation table requires peripheralName")

    local sensorBlock = wrapPeripheral(peripheralName)

    assert(
        type(sensorBlock.getHeading) == "function",
        "Navigation table requires getHeading()"
    )
    assert(
        type(sensorBlock.hasTarget) == "function",
        "Navigation table requires hasTarget()"
    )
    assert(
        type(sensorBlock.getRelativeAngle) == "function",
        "Navigation table requires getRelativeAngle()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        return {
            heading = sensorBlock.getHeading(),
            hasTarget = sensorBlock.hasTarget(),
            targetOffset = sensorBlock.getRelativeAngle(),
        }
    end

    return source
end

function Sensors.laser(id, peripheralName)
    assertString(id, "Laser sensor requires an id")
    assertString(peripheralName, "Laser sensor requires peripheralName")

    local sensorBlock = wrapPeripheral(peripheralName)

    assert(
        type(sensorBlock.getClosestHitDistance) == "function",
        "Laser sensor requires getClosestHitDistance()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        return sensorBlock.getClosestHitDistance()
    end

    return source
end

return Sensors
