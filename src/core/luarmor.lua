return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/luarmor"] = function(require)
__flowStartupCheckpoint()
--[[
    Reads the runtime variables Luarmor injects into a protected script.

        LRM_SecondsLeft      seconds until the key expires, math.huge if auth_expire is unset
        LRM_IsUserPremium    whitelist flag
        LRM_UserNote         note attached to the key
        LRM_LinkedDiscordID  discord id the key is bound to
        LRM_TotalExecutions  executions made by this key
        LRM_ScriptName / LRM_ScriptVersion

    https://docs.luarmor.net/luarmor-user-manual-and-f.a.q

    Nothing here errors when the script is not Luarmor-protected — every reader
    returns nil and the UI falls back to showing no key.
]]

local Luarmor = {}

local HOUR = 3600
local DAY = 86400
local YEAR = 365 * DAY

-- anything longer than this counts as premium rather than a trial key
Luarmor.PremiumAfter = 60 * HOUR

-- set by hand to preview a state, e.g. Luarmor.override = { SecondsLeft = math.huge }
Luarmor.override = nil

local NAMES = {
    "LRM_SecondsLeft",
    "LRM_IsUserPremium",
    "LRM_UserNote",
    "LRM_LinkedDiscordID",
    "LRM_TotalExecutions",
    "LRM_ScriptName",
    "LRM_ScriptVersion",
    "LRM_ScriptKey",
}

-- Luarmor puts its variables in the protected script's own environment, which may
-- be the executor global table, _G, or a caller's env depending on how the script
-- was loaded, so check all of them.
local function readGlobal(name)
    local envs = {}

    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            table.insert(envs, env)
        end
    end

    table.insert(envs, _G)

    if getfenv then
        for level = 1, 6 do
            local ok, env = pcall(getfenv, level)
            if ok and type(env) == "table" then
                table.insert(envs, env)
            end
        end
    end

    for _, env in ipairs(envs) do
        local ok, value = pcall(function()
            return env[name]
        end)
        if ok and value ~= nil then
            return value
        end
    end

    return nil
end

function Luarmor.info()
    local out = {}
    for _, name in ipairs(NAMES) do
        out[name] = readGlobal(name)
    end
    return out
end

-- nil when there is no key data at all
function Luarmor.secondsLeft()
    if Luarmor.override and Luarmor.override.SecondsLeft ~= nil then
        return Luarmor.override.SecondsLeft
    end
    local value = readGlobal("LRM_SecondsLeft")
    if type(value) ~= "number" then
        return nil
    end
    return value
end

function Luarmor.isLifetime()
    local left = Luarmor.secondsLeft()
    if left == nil then
        return false
    end
    -- math.huge is the documented "no auth_expire" value; the year check catches
    -- keys given an absurd expiry instead of none at all
    return left == math.huge or left > 50 * YEAR
end

function Luarmor.isPremium()
    local left = Luarmor.secondsLeft()
    if left == nil then
        local flag = readGlobal("LRM_IsUserPremium")
        if type(flag) == "boolean" then
            return flag
        end
        return false
    end
    return Luarmor.isLifetime() or left >= Luarmor.PremiumAfter
end

function Luarmor.plan()
    return Luarmor.isPremium() and "Premium" or "Free"
end

-- "Lifetime", "12d 4h", "3h 20m", "45m", "Expired", or "No key"
function Luarmor.duration()
    local left = Luarmor.secondsLeft()
    if left == nil then
        return "No key"
    end
    if Luarmor.isLifetime() then
        return "Lifetime"
    end
    if left <= 0 then
        return "Expired"
    end

    local days = math.floor(left / DAY)
    local hours = math.floor((left % DAY) / HOUR)
    local minutes = math.floor((left % HOUR) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    end
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", math.max(minutes, 1))
end

-- nil for lifetime keys and when there is no key
function Luarmor.expiry()
    local left = Luarmor.secondsLeft()
    if left == nil or left <= 0 or Luarmor.isLifetime() then
        return nil
    end
    return os.date("%d.%m.%Y %H:%M", os.time() + math.floor(left))
end

function Luarmor.note()
    local value = readGlobal("LRM_UserNote")
    if type(value) == "string" and value ~= "" and value ~= "Not specified" then
        return value
    end
    return nil
end

return Luarmor
end

__flowStartupCheckpoint()

end