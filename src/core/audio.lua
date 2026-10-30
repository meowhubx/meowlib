return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/audio"] = function(require)
__flowStartupCheckpoint()
local SoundService = __service("SoundService")

--[[
    Short UI sounds. Every clip ships with the Roblox client under rbxasset://,
    so nothing here can be moderated, rate-limited or fail to fetch.

    One Sound instance per name is reused rather than cloned — replaying cuts the
    previous tail, which is what you want when a toggle is spammed.
]]

local Audio = {}

Audio.enabled = true
-- 0.4 was inaudible over game audio — the clips are short, soft system sounds
-- and the quietest of them landed near 0.09. The per-clip ratios below are
-- unchanged, so the balance between them is the same, just louder overall.
Audio.volume = 0.7

Audio.set = {
    -- pitch is what separates on from off; same clip, brighter or duller
    on = { Id = "rbxasset://sounds/switch.wav", Speed = 1.2, Volume = 1 },
    off = { Id = "rbxasset://sounds/switch.wav", Speed = 0.9, Volume = 0.85 },
    click = { Id = "rbxasset://sounds/clickfast.wav", Speed = 1.5, Volume = 0.7 },
    select = { Id = "rbxasset://sounds/clickfast.wav", Speed = 1.9, Volume = 0.5 },
    open = { Id = "rbxasset://sounds/switch3.wav", Speed = 1.1, Volume = 0.75 },
    close = { Id = "rbxasset://sounds/switch3.wav", Speed = 0.85, Volume = 0.65 },
    -- switch.wav at 2.4x is ~0.1s, short enough to read as a detent rather than a click
    tick = { Id = "rbxasset://sounds/switch.wav", Speed = 2.4, Volume = 0.32 },
}

local pool = {}
local holder

-- The sound pool used to live in SoundService, where any game script could
-- enumerate a folder called "FlowAudio". It now sits inside the protected GUI
-- container alongside everything else; a Sound parented to a GUI still plays 2D.
function Audio.attach(host)
    Audio.host = host
    if holder then
        pcall(function()
            holder:Destroy()
        end)
        holder = nil
        table.clear(pool)
    end
end

local function container()
    if holder and holder.Parent then
        return holder
    end
    holder = Instance.new("Folder")
    holder.Name = ""

    local target = Audio.host
    local ok = target ~= nil
        and pcall(function()
            holder.Parent = target
        end)
    if not ok then
        pcall(function()
            holder.Parent = __service("SoundService")
        end)
    end
    return holder
end

local function instance(name)
    local hit = pool[name]
    if hit and hit.Parent then
        return hit
    end

    local spec = Audio.set[name]
    if not spec then
        return nil
    end

    local sound = Instance.new("Sound")
    sound.Name = "flow_" .. name
    sound.SoundId = spec.Id
    sound.PlaybackSpeed = spec.Speed or 1
    sound.Parent = container()

    pool[name] = sound
    return sound
end

function Audio.play(name, speed)
    if not Audio.enabled then
        return
    end
    local spec = Audio.set[name]
    if not spec then
        return
    end
    pcall(function()
        local sound = instance(name)
        if not sound then
            return
        end
        sound.Volume = Audio.volume * (spec.Volume or 1)
        sound.PlaybackSpeed = speed or spec.Speed or 1
        sound.TimePosition = 0
        sound:Play()
    end)
end

-- replace a clip, e.g. Flow.Audio.define("on", { Id = "rbxassetid://123", Speed = 1 })
function Audio.define(name, spec)
    Audio.set[name] = spec
    local hit = pool[name]
    if hit then
        hit:Destroy()
        pool[name] = nil
    end
end

function Audio.destroy()
    for _, sound in pairs(pool) do
        pcall(function()
            sound:Destroy()
        end)
    end
    table.clear(pool)
    if holder then
        pcall(function()
            holder:Destroy()
        end)
        holder = nil
    end
end

return Audio
end

__flowStartupCheckpoint()

end