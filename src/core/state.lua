return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/state"] = function(require)
__flowStartupCheckpoint()
local HttpService = __service("HttpService")

local State = {}

State.flags = {}
State.controls = {}
State.folder = "flow"

local listeners = {}

function State.register(flag, control)
    if not flag then
        return
    end
    State.controls[flag] = control
end

--[[
    Hand a flag back when the control behind it dies. Guarded on identity: a
    reload builds the new card before the old tree is torn down, so an
    unconditional clear would wipe the live registration and leave
    Flow:Set("flag", v) pointing at nothing.
]]
function State.release(flag, control)
    if flag and State.controls[flag] == control then
        State.controls[flag] = nil
    end
end

function State.get(flag)
    return State.flags[flag]
end

function State.set(flag, value, silent)
    State.flags[flag] = value
    local control = State.controls[flag]
    if control and control.Set and not silent then
        control:Set(value)
    end
    local bucket = listeners[flag]
    if bucket then
        for _, fn in ipairs(bucket) do
            task.spawn(fn, value)
        end
    end
end

function State.watch(flag, fn)
    listeners[flag] = listeners[flag] or {}
    table.insert(listeners[flag], fn)
    return function()
        local bucket = listeners[flag]
        if not bucket then
            return
        end
        for i, v in ipairs(bucket) do
            if v == fn then
                table.remove(bucket, i)
                break
            end
        end
    end
end

local function pack(value)
    local kind = typeof(value)
    if kind == "Color3" then
        return {
            __k = "Color3",
            r = math.floor(value.R * 255 + 0.5),
            g = math.floor(value.G * 255 + 0.5),
            b = math.floor(value.B * 255 + 0.5),
        }
    elseif kind == "EnumItem" then
        return { __k = "Enum", group = tostring(value.EnumType), item = value.Name }
    elseif kind == "Vector2" then
        return { __k = "Vector2", x = value.X, y = value.Y }
    elseif kind == "UDim2" then
        return {
            __k = "UDim2",
            xs = value.X.Scale,
            xo = value.X.Offset,
            ys = value.Y.Scale,
            yo = value.Y.Offset,
        }
    elseif kind == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[k] = pack(v)
        end
        return out
    end
    return value
end

local function unpack(value)
    if typeof(value) ~= "table" then
        return value
    end
    local kind = value.__k
    if kind == "Color3" then
        return Color3.fromRGB(value.r, value.g, value.b)
    elseif kind == "Enum" then
        local ok, item = pcall(function()
            return Enum[value.group:gsub("^Enum%.", "")][value.item]
        end)
        return ok and item or nil
    elseif kind == "Vector2" then
        return Vector2.new(value.x, value.y)
    elseif kind == "UDim2" then
        return UDim2.new(value.xs, value.xo, value.ys, value.yo)
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = unpack(v)
    end
    return out
end

State.pack = pack
State.unpack = unpack

local function canWrite()
    return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

-- every one of these can throw rather than return false on a sandboxed or
-- permission-limited executor, and an unhandled throw here surfaces as a dead
-- Save button with no explanation
local function ensureFolder()
    if not isfolder or not makefolder then
        return false
    end
    return (pcall(function()
        if not isfolder(State.folder) then
            makefolder(State.folder)
        end
        if not isfolder(State.folder .. "/configs") then
            makefolder(State.folder .. "/configs")
        end
    end))
end

-- config names reach the filesystem, so anything that could climb out of the
-- folder or break a path is stripped rather than trusted
local function safeName(name)
    name = tostring(name or "default"):gsub("[^%w%-_ %.]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.+$", "")
    if name == "" then
        return "default"
    end
    return name:sub(1, 64)
end

State.safeName = safeName

function State.dump(extra)
    local out = { flags = {}, extra = extra and pack(extra) or nil }
    for flag, value in pairs(State.flags) do
        out.flags[flag] = pack(value)
    end
    return out
end

function State.apply(data)
    if typeof(data) ~= "table" or typeof(data.flags) ~= "table" then
        return false
    end
    for flag, value in pairs(data.flags) do
        State.set(flag, unpack(value))
    end
    return true
end

function State.save(name, extra)
    if not canWrite() then
        return false, "executor has no file access"
    end
    ensureFolder()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, State.dump(extra))
    if not ok then
        return false, "could not encode config"
    end
    local wrote = pcall(writefile, State.folder .. "/configs/" .. safeName(name) .. ".json", encoded)
    if not wrote then
        return false, "executor refused the write"
    end
    return true
end

function State.load(name)
    if not canWrite() then
        return false, "executor has no file access"
    end
    local path = State.folder .. "/configs/" .. safeName(name) .. ".json"
    local there, present = pcall(isfile, path)
    if not there or not present then
        return false, "config not found"
    end
    local read, body = pcall(readfile, path)
    if not read then
        return false, "config could not be read"
    end
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or type(decoded) ~= "table" then
        return false, "config is corrupt"
    end
    State.apply(decoded)
    return true, decoded.extra and unpack(decoded.extra) or nil
end

function State.remove(name)
    if not delfile then
        return false
    end
    local path = State.folder .. "/configs/" .. safeName(name) .. ".json"
    local there, present = pcall(isfile, path)
    if there and present then
        return (pcall(delfile, path))
    end
    return false
end

function State.configs()
    local out = {}
    if not listfiles or not isfolder then
        return out
    end
    local ok, entries = pcall(function()
        if not isfolder(State.folder .. "/configs") then
            return nil
        end
        return listfiles(State.folder .. "/configs")
    end)
    if not ok or type(entries) ~= "table" then
        return out
    end
    for _, path in ipairs(entries) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

return State
end

__flowStartupCheckpoint()

end