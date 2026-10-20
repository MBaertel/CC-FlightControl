local leftTiltAdapterName = "tilt_adapter_0"
local rightTiltAdaptrName = "tilt_adapter_1"

local pitchScale = 0.4
local yawScale = 0.2
local rollScale = 0.1

local leftTiltAdapter = peripheral.wrap(leftTiltAdapterName)
local rightTiltAdapter = peripheral.wrap(rightTiltAdaptrName)
local relay = peripheral.find("redstone_relay")
local controller = peripheral.find("tweaked_controller")

local stabilisation = true
local mainThrottle = 0

local mainThrottleTickCooldown = 3
local currentCooldown = 0

function modulateRotorAngle(value)
    return value * 45
end

function modulateThrottle(value)
    value = value * 15
    return math.max(15, math.min(0, value))
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

    if currentCooldown > 0 then
        currentCooldown = currentCooldown - 1
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
    if (throttleAxis > 0.1 and mainThrottle <= 1 and currentCooldown == 0) then
        mainThrottle = mainThrottle + 0.1
        currentCooldown = mainThrottleTickCooldown
    end
    if (throttleAxis < -0.1 and mainThrottle >= 0 and currentCooldown == 0) then
        mainThrottle = mainThrottle - 0.1
        currentCooldown = mainThrottleTickCooldown
    end

    --assemble final inputs
    local finalLeftRotorAngle = (pitchAxis * pitchScale) + (yawAxis * yawScale)
    local finalRightRotorAngle = (pitchAxis * pitchScale) + (yawAxis * yawScale * -1)

    local leftRotorThrottle = mainThrottle + (rollAxis * rollScale)
    local rightRotorThrottle = mainThrottle + (rollAxis * rollScale * -1)

    print(finalLeftRotorAngle)
    print(finalRightRotorAngle)
    print(leftRotorThrottle)
    print(rightRotorThrottle)

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
