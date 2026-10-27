local Processors = {}

local Validation = require("utils.validation")
local assertString = Validation.assertString

function Processors.PID(id, kp, ki, kd, minOutput, maxOutput)
    assertString(id, "PID requires an id")
    assert(type(kp) == "number", "PID kp must be a number")
    assert(type(ki) == "number", "PID ki must be a number")
    assert(type(kd) == "number", "PID kd must be a number")

    minOutput = minOutput or -1
    maxOutput = maxOutput or 1

    assert(
        type(minOutput) == "number" and type(maxOutput) == "number",
        "PID output limits must be numbers"
    )
    assert(minOutput <= maxOutput, "PID minimum output exceeds maximum")

    local integral = 0
    local previousError = nil

    local processor = {
        id = id,
        role = "processor",
        args = { "target", "measured", "dt" },
    }

    function processor:update(target, measured, dt)
        if target == nil or measured == nil
            or dt == nil or dt <= 0 then
            return nil
        end

        local errorValue = target - measured
        integral = integral + errorValue * dt

        local derivative = 0
        if previousError ~= nil then
            derivative = (errorValue - previousError) / dt
        end

        previousError = errorValue

        local output = kp * errorValue
            + ki * integral
            + kd * derivative

        return math.max(
            minOutput,
            math.min(maxOutput, output)
        )
    end

    return processor
end

function Processors.add(id)
    assertString(id, "Add requires an id")

    local processor = {
        id = id,
        role = "processor",
        args = { "a", "b" },
        lastRun = nil,
    }

    function processor:update(a, b)
        return a + b
    end
end

function Processors.subtract(id)
    assertString(id, "Subtract requires an id")

    local processor = {
        id = id,
        role = "processor",
        args = { "a", "b" },
        lastRun = nil,
    }

    function processor:update(a, b)
        return a - b
    end
end

function Processors.multiply(id)
    assertString(id, "Multiply requires an id")

    local processor = {
        id = id,
        role = "processor",
        args = { "a", "b" },
        lastRun = nil,
    }

    function processor:update(a, b)
        return a * b
    end
end

function Processors.divide(id)
    assertString(id, "Divide requires an id")

    local processor = {
        id = id,
        role = "processor",
        args = { "a", "b" },
        lastRun = nil,
    }

    function processor:update(a, b)
        return a / b
    end
end

function Processors.Delay(id, delaySeconds)
    assertString(id, "Delay requires an id")
    assert(
        type(delaySeconds) == "number" and delaySeconds >= 0,
        "Delay requires a non-negative delay in seconds"
    )

    local processor = {
        id = id,
        role = "processor",
        args = { "value" },
        delaySeconds = delaySeconds,
        lastRun = nil,
    }

    function processor:update(value)
        if value == nil then
            return nil
        end

        local now = os.epoch("utc") / 1000

        if self.lastRun == nil then
            self.lastRun = now
            return nil
        end

        if now - self.lastRun < self.delaySeconds then
            return nil
        end

        self.lastRun = now
        return value
    end

    return processor
end

function Processors.Selector(id, expectedValue)
    assertString(id, "Selector requires an id")

    local processor = {
        id = id,
        role = "processor",
        args = { "select", "value" },
        expectedValue = expectedValue,
    }

    function processor:update(selectValue, value)
        if selectValue ~= self.expectedValue then
            return nil
        end

        return value
    end

    return processor
end

function Processors.Latch(id, initialValue, alternateValue)
    assertString(id, "Latch requires an id")
    assert(initialValue ~= nil, "Latch requires an initial value")
    assert(alternateValue ~= nil, "Latch requires an alternate value")
    assert(
        initialValue ~= alternateValue,
        "Latch states must be different"
    )

    local processor = {
        id = id,
        role = "processor",
        args = { "trigger" },
        state = initialValue,
        previousTrigger = false,
    }

    function processor:update(trigger)
        trigger = trigger == true

        local risingEdge = trigger and not self.previousTrigger
        self.previousTrigger = trigger

        if not risingEdge then
            return nil
        end

        if self.state == initialValue then
            self.state = alternateValue
        else
            self.state = initialValue
        end

        return self.state
    end

    return processor
end

function Processors.hold(id, initialValue)
    assertString(id, "Hold requires an id")

    if initialValue == nil then
        initialValue = 0
    end

    assert(type(initialValue) == "number", "Hold initial value must be a number")

    local processor = {
        id = id,
        role = "processor",
        args = { "value" },
        current = initialValue,
    }

    function processor:update(value)
        if type(value) ~= "number" then
            return nil
        end

        self.current = self.current + value
        return self.current
    end

    return processor
end

return Processors
