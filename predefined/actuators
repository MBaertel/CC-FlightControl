local Actuators = {}

local modulateFunctions = require("predefined.modulateFunctions")

function Actuator.redstoneUnipolar(id, relayName, outputSide)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(relayName) == "string", "Actuator requires peripheralName")
    assert(type(outputSide) == "string", "Output side must be a string")

    local sink = {
        id = id,
        role = "sink"
    }

    local peripheral
    if (relayName ~= nil) then
        peripheral = peripheral.wrap(relayName)
    end

    function sink:update(value)
        local normalizedValue = math.max(0, math.min(value, 1))
        local outputValue = normalizedValue * 15

        if (peripheral == nil) then
            redstone.setAnalogOutput(outputSide)
        else
            peripheral.setAnalogOutput(outputSide)
        end
    end

    return sink
end

function Actuator.redstoneBipolar(id, relayName, outputSide)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(relayName) == "string", "Actuator requires peripheralName")
    assert(type(outputSide) == "string", "Output side must be a string")

    local sink = {
        id = id,
        role = "sink"
    }

    local peripheral
    if (relayName ~= nil) then
        peripheral = peripheral.wrap(relayName)
    end

    function sink:update(value)
        local normalizedValue = math.max(-1, math.min(value, 1))
        local outputValue = modulateFunctions.redstoneBipolar(normalizedValue)

        if (peripheral == nil) then
            redstone.setAnalogOutput(outputSide)
        else
            peripheral.setAnalogOutput(outputSide)
        end
    end

    return sink
end

function Actuator.redstoneReversible(id, mainRelayName, mainOutputSide, directionRelayName, directionOutputSide)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(mainRelayName) == "string", "Actuator requires peripheralName for the main relay")
    assert(type(mainOutputSide) == "string", "Output side must be a string")
    assert(type(directionRelayName) == "string", "Actuator requires peripheralName for the direction relay")
    assert(type(directionOutputSide) == "string", "Output side must be a string")

    local sink = {
        id = id,
        role = "sink"
    }

    local mainRelay
    if (mainRelayName ~= nil) then
        peripheral = peripheral.wrap(mainRelayName)
    end
    local directionRelay
    if (directionRelayName ~= nil) then
        peripheral = peripheral.wrap(directionRelayName)
    end

    function sink:update(value)
        function sink:update(value)
            local normalizedValue = math.max(-1, math.min(value, 1))
            local outputValue = modulateFunctions.redstoneUnipolar(math.abs(normalizedValue))

            if (directionRelay ~= nil) then
                directionRelay.setOutput(directionOutputSide, normalizedValue < 0)
            end

            if (peripheral == nil) then
                redstone.setAnalogOutput(outputSide)
            else
                peripheral.setAnalogOutput(outputSide)
            end
        end
    end

    return sink
end

function Actuators.balloonBurner(id, peripheralName)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(peripheralName) == "string", "Actuator requires peripheralName")

    local sink = {
        id = id,
        role = "sink"
    }

    local burner = peripheral.wrap(peripheralName)

    function sink:update(value)
        local normalizedValue = math.max(0, math.max(value, 1))

        local maxVolume = math.min(burner.getBalloonCapacity, burner.getTargetAmount())
        local outputVolume = normalizedValue * maxVolume

        burner.setTargetAmount(outputVolume)
    end

    return sink
end

return Actuators
