local Sources = {}

function Sources.timer(id)
    assert(type(id) == "string", "Timer requires an id")

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

function Sources.tweakedControllerAxis(id, peripheralName, axisId)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(peripheralName) == "string", "Controller requires a peripheralName")
    assert(type(axisId) == "number", "Axis Id must be a number")

    local source = {
        id = id,
        role = "source"
    }

    local controller = peripheral.wrap(peripheralName)

    function source:update()
        if (not controller.hasUser()) then
            return nil
        end

        return controller.getAxis(axisId)
    end
end

function Sources.tweakedControllerButton(id, peripheralName, buttonId, asNumber)
    assert(type(id) == "string", "Controller requires an id")
    assert(type(peripheralName) == "string", "Controller requires a peripheralName")
    assert(type(buttonId) == "number", "Button Id must be a number")

    local source = {
        id = id,
        role = "source"
    }

    local controller = peripheral.wrap(peripheralName)

    function source:update()
        if (not controller.hasUser()) then
            return nil
        end

        local buttonValue = controller.getButton(buttonId)
        if (asNumber) then
            if (buttonValue) then
                return 1
            else
                return 0
            end
        else
            return buttonValue
        end
    end
end

return Sources
