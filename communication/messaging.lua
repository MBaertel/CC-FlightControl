local Messaging = {}

local DEFAULT_MODEM_CHANNEL = 4269
local PROTOCOL_VERSION = 1

function Messaging.open(config)
    config = config or {}

    assert(type(config) == "table", "config must be a table")

    local channel = config.channel or DEFAULT_MODEM_CHANNEL

    assert(
        type(channel) == "number"
        and channel % 1 == 0
        and channel >= 0
        and channel <= 65535,
        "invalid channel"
    )

    local modem
    if config.modem then
        modem = type(config.modem) == "string"
            and peripheral.wrap(config.modem)
            or config.modem
    else
        modem = peripheral.find("modem")
    end

    assert(modem, "No modem found")

    modem.open(channel)

    local client = {
        password = config.password,
        modem = modem,
        channel = channel,
        closed = false,
        running = false,
        subscriptions = {},

        -- Latest received message for each topic.
        latest = {},

        -- Topics with unread messages.
        pending = {},
        pendingHead = 1,
        pendingTail = 0,

        -- Current pending entry for each topic.
        pendingByTopic = {},
    }

    function client:publish(topic, content)
        if self.closed then
            error("client is closed")
        end

        assert(type(topic) == "string", "topic must be a string")

        self.modem.transmit(
            self.channel,
            self.channel,
            {
                _messaging = PROTOCOL_VERSION,
                topic = topic,
                password = self.password,
                content = content,
            }
        )
    end

    function client:subscribe(topic)
        if self.closed then
            error("client is closed")
        end

        assert(type(topic) == "string", "topic must be a string")

        self.subscriptions[topic] = true
    end

    function client:unsubscribe(topic)
        if self.closed then
            error("client is closed")
        end

        assert(type(topic) == "string", "topic must be a string")

        self.subscriptions[topic] = nil
        self.latest[topic] = nil
        self.pendingByTopic[topic] = nil
    end

    function client:isSubscribed(topic)
        return self.subscriptions[topic] == true
    end

    -- Continuously receive modem events and update the cache.
    -- Run this in its own parallel coroutine.
    function client:run()
        if self.closed then
            error("client is closed")
        end

        if self.running then
            error("client is already running")
        end

        self.running = true

        while not self.closed do
            local _, side, receivedChannel, replyChannel, message =
                os.pullEvent("modem_message")

            if receivedChannel == self.channel
                and type(message) == "table"
                and message._messaging == PROTOCOL_VERSION
                and type(message.topic) == "string"
                and self.subscriptions[message.topic]
                and (
                    self.password == nil
                    or message.password == self.password
                ) then
                local topic = message.topic
                self.latest[topic] = message

                if not self.pendingByTopic[topic] then
                    local entry = { topic = topic }

                    self.pendingTail = self.pendingTail + 1
                    self.pending[self.pendingTail] = entry
                    self.pendingByTopic[topic] = entry
                end
            end
        end

        self.running = false
    end

    function client:getMessages()
        if self.closed then
            error("client is closed")
        end

        local messages = {}

        while self.pendingHead <= self.pendingTail do
            local entry = self.pending[self.pendingHead]

            self.pending[self.pendingHead] = nil
            self.pendingHead = self.pendingHead + 1

            local topic = entry.topic

            if self.pendingByTopic[topic] == entry then
                self.pendingByTopic[topic] = nil

                local message = self.latest[topic]

                if message then
                    messages[#messages + 1] = {
                        content = message.content,
                        topic = topic,
                        message = message,
                    }
                end
            end
        end

        self.pending = {}
        self.pendingHead = 1
        self.pendingTail = 0

        return messages
    end

    function client:close()
        if self.closed then
            return
        end

        self.closed = true
        self.modem.close(self.channel)

        self.subscriptions = {}
        self.latest = {}
        self.pending = {}
        self.pendingByTopic = {}
        self.pendingHead = 1
        self.pendingTail = 0
    end

    return client
end

return Messaging
