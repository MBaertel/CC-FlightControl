local Inputs = {}

local Validation = require("utils.validation")

local assertString = Validation.assertString
local wrapPeripheral = Validation.wrapPeripheral

function Inputs.timer(id)
    assertString(id, "Timer requires an id")

    local source = {
        id = id,
        role = "source",
        lastTime = nil,
    }

    function source:update()
        local now = os.epoch("utc") / 1000
        local delta = 0

        if self.lastTime ~= nil then
            delta = now - self.lastTime
        end

        self.lastTime = now
        return delta
    end

    return source
end

function Inputs.tweakedControllerAxis(id, peripheralName, axisId)
    assertString(id, "Controller requires an id")
    assertString(peripheralName, "Controller requires a peripheral name")
    assert(type(axisId) == "number", "Axis ID must be a number")

    local controller = wrapPeripheral(peripheralName)

    assert(
        type(controller.hasUser) == "function",
        "Controller must implement hasUser()"
    )
    assert(
        type(controller.getAxis) == "function",
        "Controller must implement getAxis()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        if not controller.hasUser() then
            return 0
        end

        return controller.getAxis(axisId)
    end

    return source
end

function Inputs.tweakedControllerButton(
    id,
    peripheralName,
    buttonId,
    asNumber
)
    assertString(id, "Controller requires an id")
    assertString(peripheralName, "Controller requires a peripheral name")
    assert(type(buttonId) == "number", "Button ID must be a number")
    assert(
        asNumber == nil or type(asNumber) == "boolean",
        "asNumber must be a boolean or nil"
    )

    local controller = wrapPeripheral(peripheralName)

    assert(
        type(controller.hasUser) == "function",
        "Controller must implement hasUser()"
    )
    assert(
        type(controller.getButton) == "function",
        "Controller must implement getButton()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        if not controller.hasUser() then
            return false
        end

        local buttonValue = controller.getButton(buttonId)

        if asNumber then
            return buttonValue and 1 or 0
        end

        return buttonValue
    end

    return source
end

function Inputs.steeringWheel(id, peripheralName, normalized)
    assertString(id, "Source requires an id")
    assertString(peripheralName, "Source requires a peripheral name")
    assert(
        normalized == nil or type(normalized) == "boolean",
        "normalized must be a boolean or nil"
    )

    local steeringWheel = wrapPeripheral(peripheralName)

    assert(
        type(steeringWheel.getAngle) == "function",
        "Steering wheel must implement getAngle()"
    )
    assert(
        type(steeringWheel.getNormalizedAngle) == "function",
        "Steering wheel must implement getNormalizedAngle()"
    )

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        if normalized == nil then
            return {
                raw = steeringWheel.getAngle(),
                normalized = steeringWheel.getNormalizedAngle(),
            }
        end

        if normalized then
            return steeringWheel.getNormalizedAngle()
        end

        return steeringWheel.getAngle()
    end

    return source
end

function Inputs.redstone(id, peripheralName, peripheralSide)
    assertString(id, "Lever requires an id")
    assertString(peripheralSide, "Lever requires a peripheral side to read")

    local relay = nil
    if (peripheralName ~= nil) then
        relay = wrapPeripheral(peripheralName)
    end

    local source = {
        id = id,
        role = "source",
    }

    function source:update()
        local input = nil
        if relay == nil then
            input = redstone.getAnalogInput(peripheralSide)
        else
            input = relay.getAnalogInput(peripheralSide)
        end

        return {
            raw = input,
            normalized = input / 15
        }
    end

    return source
end

return Inputs
