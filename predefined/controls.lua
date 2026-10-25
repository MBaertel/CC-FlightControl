local controls = {}

function controls.PID(kp, ki, kd, minOutput, maxOutput)
    minOutput = minOutput or -1
    maxOutput = maxOutput or 1

    local integral = 0
    local previousError = nil

    return function(target, measured, dt)
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

        return math.max(minOutput, math.min(maxOutput, output))
    end
end

return controls
