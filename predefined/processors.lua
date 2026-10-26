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

return Processors
