local Processors = {}

function Processors.PID(id, kp, ki, kd, minOutput, maxOutput)
    assert(type(id) == "string", "PID requires an id")

    minOutput = minOutput or -1
    maxOutput = maxOutput or 1

    local integral = 0
    local previousError = nil

    local processor = {
        id = id,
        role = "processor",
    }

    function processor:update(inputs)
        local target = inputs.target
        local measured = inputs.measured
        local dt = inputs.dt

        if target == nil or measured == nil
            or dt == nil or dt <= 0 then
            return nil
        end

        local error = target - measured
        integral = integral + error * dt

        local derivative = 0
        if previousError ~= nil then
            derivative = (error - previousError) / dt
        end

        previousError = error

        local output = kp * error
            + ki * integral
            + kd * derivative

        return math.max(
            minOutput,
            math.min(maxOutput, output)
        )
    end

    return processor
end

function Processors.Delay(id, delaySeconds)
    assert(type(id) == "string", "Delay requires an id")
    assert(
        type(delaySeconds) == "number" and delaySeconds >= 0,
        "Delay requires a non-negative delay in seconds"
    )

    local processor = {
        id = id,
        role = "processor",
        delaySeconds = delaySeconds,
        lastRun = nil,
    }

    function processor:update(inputs)
        assert(type(inputs) == "table", "Delay inputs must be a table")

        local value
        local count = 0

        for _, input in pairs(inputs) do
            count = count + 1
            value = input
        end

        assert(count == 1, "Delay requires exactly one input")

        local now = os.epoch("utc") / 1000

        if self.lastRun == nil then
            self.lastRun = now
            return nil
        end

        if now - self.lastRun < self.delaySeconds then
            return nil
        end

        -- The delay elapsed; allow this output and restart the timer.
        self.lastRun = now
        return value
    end

    return processor
end

function Processors.Selector(id, expectedValue)
    assert(type(id) == "string", "Selector requires an id")

    local processor = {
        id = id,
        role = "processor",
        expectedValue = expectedValue,
    }

    function processor:update(inputs)
        assert(type(inputs) == "table", "Selector inputs must be a table")

        if inputs.select ~= self.expectedValue then
            return nil
        end

        return inputs.value
    end

    return processor
end

function Processors.Latch(id, initialValue, alternateValue)
    assert(type(id) == "string", "Latch requires an id")
    assert(initialValue ~= nil, "Latch requires an initial value")
    assert(alternateValue ~= nil, "Latch requires an alternate value")
    assert(initialValue ~= alternateValue,
        "Latch states must be different")

    local processor = {
        id = id,
        role = "processor",
        state = initialValue,
        previousTrigger = false,
    }

    function processor:update(inputs)
        assert(type(inputs) == "table", "Latch inputs must be a table")

        local trigger = inputs.trigger == true
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

return Processors
