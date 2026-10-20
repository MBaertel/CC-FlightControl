local leftTiltAdapterName = "tilt_adapter_0"
local rightTiltAdaptrName = "tilt_adapter_1"

local leftTiltAdapter = peripheral.wrap(leftTiltAdapterName)
local rightTiltAdapter = peripheral.wrap(rightTiltAdaptrName)
local relay = peripheral.find("redstone_relay")
local controller = peripheral.find("tweaked_controller")

local stabilisation = true
local mainThrottle = 0

function modulateRotorAngle(value)
    return value * 45
end

function modulateThrottle(value)
    return value * 15
end

function setRotorAngle(side, angle)
    if (side == "left") then
        leftTiltAdapter.setTargetAngle(angle)
    else
        rightTiltAdapter.setTargetAngle(angle)
    end
end

function setRotorThrottle(side, throttle)
    relay.setAnalogOutput(side, throttle)
end

function reset()
    setRotorAngle("left", 0)
    setRotorAngle("right", 0)
    setRotorThrottle("left", 0)
    setRotorThrottle("right", 0)
end

function controlLoop()
    if not controller.hasUser() then
        reset()
        sleep(0.5)
        return
    end
    --Get Inputs
    local pitchAxis = controller.getAxis(2)
    local rollAxis = controller.getAxis(1)
    local yawAxis = controller.getAxis(3)
    local throttleUp = controller.getAxis(6)
    local throttleDown = controller.getAxis(5)

    --Assemble final axis
    local throttleAxis = throttleUp - throttleDown

    --assemble constant inputs
    if (throttleAxis > 0.1 and mainThrottle <= 1) then
        mainThrottle = mainThrottle + 0.1
    end
    if (throttleAxis < 0.1 and mainThrottle >= 0) then
        mainThrottle = mainThrottle - 0.1
    end

    --assemble final inputs
    local finalLeftRotorAngle = pitchAxis + yawAxis
    local finalRightRotorAngle = pitchAxis + (yawAxis * -1)

    local leftRotorThrottle = mainThrottle + rollAxis
    local rightRotorThrottle = mainThrottle + (rollAxis * -1)

    --apply Inputs to outputs
    setRotorAngle("left", modulateRotorAngle(finalLeftRotorAngle))
    setRotorAngle("right", modulateRotorAngle(finalRightRotorAngle))

    setRotorThrottle("left", modulateThrottle(leftRotorThrottle))
    setRotorThrottle("right", modulateThrottle(rightRotorThrottle))
end

reset()
while true do
    controlLoop()
end
