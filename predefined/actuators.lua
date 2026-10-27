local Actuators = {}

local modulateFunctions = require("predefined.modulateFunctions")
local Validation = require("utils.validation")

local assertString = Validation.assertString
local wrapPeripheral = Validation.wrapPeripheral

local function clamp(value, minimum, maximum)
    assert(type(value) == "number", "Actuator input must be a number")
    return math.max(minimum, math.min(value, maximum))
end

local function setAnalog(relay, side, value)
    if relay then
        relay.setAnalogOutput(side, value)
    else
        redstone.setAnalogOutput(side, value)
    end
end

local function setDigital(relay, side, value)
    if relay then
        relay.setOutput(side, value)
    else
        redstone.setOutput(side, value)
    end
end

function Actuators.redstoneUnipolar(id, relayName, outputSide)
    assertString(id, "Actuator requires an id")
    assert(
        relayName == nil or type(relayName) == "string",
        "Relay name must be a string or nil"
    )
    assertString(outputSide, "Output side must be a string")

    local relay = relayName and wrapPeripheral(relayName) or nil

    return {
        id = id,
        role = "sink",

        update = function(_, value)
            local normalizedValue = clamp(value, 0, 1)
            setAnalog(relay, outputSide, normalizedValue * 15)
        end,
    }
end

function Actuators.redstoneBipolar(id, relayName, outputSide)
    assertString(id, "Actuator requires an id")
    assert(
        relayName == nil or type(relayName) == "string",
        "Relay name must be a string or nil"
    )
    assertString(outputSide, "Output side must be a string")

    local relay = relayName and wrapPeripheral(relayName) or nil

    return {
        id = id,
        role = "sink",

        update = function(_, value)
            local normalizedValue = clamp(value, -1, 1)
            local outputValue =
                modulateFunctions.redstoneBipolar(normalizedValue)

            setAnalog(relay, outputSide, outputValue)
        end,
    }
end

function Actuators.redstoneReversible(
    id,
    mainRelayName,
    mainOutputSide,
    directionRelayName,
    directionOutputSide
)
    assertString(id, "Actuator requires an id")
    assertString(
        mainRelayName,
        "Actuator requires a main relay name"
    )
    assertString(mainOutputSide, "Main output side must be a string")
    assertString(
        directionRelayName,
        "Actuator requires a direction relay name"
    )
    assertString(
        directionOutputSide,
        "Direction output side must be a string"
    )

    local mainRelay = wrapPeripheral(mainRelayName)
    local directionRelay = wrapPeripheral(directionRelayName)

    return {
        id = id,
        role = "sink",

        update = function(_, value)
            local normalizedValue = clamp(value, -1, 1)
            local outputValue =
                modulateFunctions.redstoneUnipolar(math.abs(normalizedValue))

            setDigital(
                directionRelay,
                directionOutputSide,
                normalizedValue < 0
            )

            setAnalog(mainRelay, mainOutputSide, outputValue)
        end,
    }
end

function Actuators.balloonBurner(id, peripheralName)
    assertString(id, "Actuator requires an id")
    assertString(peripheralName, "Actuator requires a peripheral name")

    local burner = wrapPeripheral(peripheralName)

    assert(
        type(burner.getBalloonCapacity) == "function",
        "Balloon burner must implement getBalloonCapacity()"
    )
    assert(
        type(burner.setTargetAmount) == "function",
        "Balloon burner must implement setTargetAmount()"
    )

    return {
        id = id,
        role = "sink",

        update = function(_, value)
            local normalizedValue = clamp(value, 0, 1)

            local capacity = burner.getBalloonCapacity()
            local maxVolume = math.min(capacity, 500)

            burner.setTargetAmount(normalizedValue * maxVolume)
        end,
    }
end

return Actuators
