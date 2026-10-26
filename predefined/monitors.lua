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

return Monitors
