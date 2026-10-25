local Actuators = {}

local actuator = require("components.actuator")
local modulateFunctions = require("modulateFunctions")

function Actuators.analogTransmission(name, peripheralName, reverse)
    local function set(value)
        peripheral.call(peripheralName, "setSignal", value)
    end

    local modulate
    if (reverse) then
        modulate = modulateFunctions.compose(
            modulateFunctions.reverse,
            modulateFunctions.redstoneUnipolar
        )
    else
        modulate = modulateFunctions.redstoneUnipolar
    end

    return actuator.new(
        name,
        modulate,
        set
    )
end

function Actuators.wheelMount(name, peripheralName, autoBrake)
    local function set(value)
        if (autoBrake) then
            if (value <= 0.01 and value >= -0.01) then
                peripheral.call(peripheralName, "setBrake", 15)
            else
                peripheral.call(peripheralName, "setBrake", 0)
            end
        end
        peripheral.call(peripheralName, "setSteering", value)
    end

    return actuator.new(
        name,
        modulateFunctions.identity,
        set
    )
end

function Actuators.redstoneTransmission(name, peripheralName, redstoneSide)
    local function set(value)
        peripheral.call(peripheralName, "setAnalogOutput", redstoneSide, value)
    end
end

return Actuators
