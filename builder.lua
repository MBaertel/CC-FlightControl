local Builder = {}
Builder.__index = Builder

function Builder.new(id)
    assert(type(id) == "string", "Flow requires an id")

    return setmetatable({
        id = id,
        stages = {},
        currentStage = nil,
    }, Builder)
end

function Builder:stage(id)
    assert(type(id) == "string", "Stage requires an id")

    local stage = {
        id = id,
        components = {},
    }

    table.insert(self.stages, stage)
    self.currentStage = stage

    return self
end

function Builder:_ensureStage()
    if not self.currentStage then
        self:stage("main")
    end
end

function Builder:_addNode(node)
    self:_ensureStage()
    table.insert(self.currentStage.components, node)
    return self
end

function Builder:source(id, component, output)
    assert(type(output) == "string", "Source requires an output signal")

    return self:_addNode({
        id = id,
        component = component,
        role = "source",
        output = output,
    })
end

function Builder:processor(id, component, inputs, output)
    assert(type(inputs) == "table", "Processor requires input bindings")
    assert(type(output) == "string", "Processor requires an output signal")

    return self:_addNode({
        id = id,
        component = component,
        role = "processor",
        inputs = inputs,
        output = output,
    })
end

function Builder:sink(id, component, inputs)
    assert(type(inputs) == "table", "Sink requires input bindings")

    return self:_addNode({
        id = id,
        component = component,
        role = "sink",
        inputs = inputs,
    })
end

function Builder:build()
    local stages = {}

    for i, stage in ipairs(self.stages) do
        local nodes = {}

        for j, node in ipairs(stage.components) do
            local copy = {}

            for key, value in pairs(node) do
                copy[key] = value
            end

            nodes[j] = copy
        end

        stages[i] = {
            id = stage.id,
            components = nodes,
        }
    end

    return {
        id = self.id,
        stages = stages,
    }
end

return Builder
