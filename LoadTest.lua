--[[
    Loader for the Flow UI test suite.

    In an executor:

        loadstring(readfile("flow-ui/Flow.lua"))()
        loadstring(readfile("flow-ui/TestSuite.lua"))()

    Or, if both files are on a web host:

        local Flow = loadstring(game:HttpGet("…/Flow.lua"))()
        -- then either set _G.Flow = Flow or edit TestSuite to use the local
]]

-- Prefer an already-loaded Flow, otherwise try common paths
local Flow = rawget(_G, "Flow")

if not Flow then
    local candidates = {
        "flow-ui/Flow.lua",
        "Flow.lua",
        "flow/Flow.lua",
    }
    for _, path in ipairs(candidates) do
        if isfile and isfile(path) then
            local ok, result = pcall(function()
                return loadstring(readfile(path))()
            end)
            if ok and type(result) == "table" then
                Flow = result
                break
            end
        end
    end
end

if not Flow then
    error("[Flow Test] Could not locate Flow.lua — load it first or place it next to this file")
end

_G.Flow = Flow

-- Run the suite (same folder)
local suiteSrc
if isfile and isfile("flow-ui/TestSuite.lua") then
    suiteSrc = readfile("flow-ui/TestSuite.lua")
elseif isfile and isfile("TestSuite.lua") then
    suiteSrc = readfile("TestSuite.lua")
end

if suiteSrc then
    local fn, err = loadstring(suiteSrc)
    if not fn then
        error("[Flow Test] TestSuite compile error: " .. tostring(err))
    end
    return fn()
else
    warn("[Flow Test] TestSuite.lua not found on disk — paste/run it manually after loading Flow")
    return Flow
end
