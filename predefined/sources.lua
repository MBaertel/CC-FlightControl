local Sources = {}

function Sources.timer(id)
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

return Sources
