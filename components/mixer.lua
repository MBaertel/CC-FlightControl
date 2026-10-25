local Mixer = {}
Mixer.__index = Mixer

function Mixer.new(name, mix)
    return setmetatable({
        name = name,
        mix = mix,
    }, Mixer)
end

function Mixer:update(data)
    return self.mix(data)
end

return Mixer
