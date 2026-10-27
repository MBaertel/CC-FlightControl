local Monitor = require("components.monitor")

local Monitors = {}

function Monitors.screen(id, peripheralName, label, line)
    assert(type(peripheralName) == "string",
        "Screen monitor requires a peripheral name")

    label = label or id
    line = line or 1

    local display = peripheral.wrap(peripheralName)
    assert(display, "Unable to find monitor peripheral: " .. peripheralName)

    return Monitor.new(id, function(value)
        display.setCursorPos(1, line)
        display.clearLine()
        display.write(label .. ": " .. tostring(value))
    end)
end

function Monitors.logger(id)
    assert(type(id) == "string", "Monitor must have an id")

    local monitor = {
        id = id,
        role = "sink",

        update = function(value, label)
            if (label == nil) then
                print(value)
            else
                print("[", label, "]", value)
            end
        end
    }
end

return Monitors
