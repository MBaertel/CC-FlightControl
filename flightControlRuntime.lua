local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(config)
    assert(type(config) == "table", "Runtime requires a config")
    assert(type(config.createClient) == "function",
        "Runtime requires createClient")
    assert(type(config.createControlSystem) == "function",
        "Runtime requires createControlSystem")

    local self = setmetatable({
        config = config,
        client = nil,
        controlSystem = nil,
    }, Runtime)

    return self
end

function Runtime:_runClient()
    self.client:run()
end

function Runtime:_runControlSystem()
    while true do
        self.controlSystem:update()
        sleep(self.config.interval or 0.05)
    end
end

function Runtime:run()
    self.client = self.config.createClient()
    self.controlSystem = self.config.createControlSystem(self.client)

    parallel.waitForAll(
        function()
            self:_runClient()
        end,
        function()
            self:_runControlSystem()
        end
    )
end

return Runtime
