return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/util"] = function(require)
__flowStartupCheckpoint()
local TweenService = __service("TweenService")
local UserInputService = __service("UserInputService")
local RunService = __service("RunService")

local Util = {}

local ease = {
    out = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    snap = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    glide = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

Util.ease = ease

function Util.new(class, props, kids)
    local inst = Instance.new(class)
    local parent
    if props then
        parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if kids then
        for _, v in ipairs(kids) do
            v.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

function Util.corner(parent, radius)
    return Util.new("UICorner", {
        CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8),
        Parent = parent,
    })
end

function Util.stroke(parent, color, thickness, transparency)
    return Util.new("UIStroke", {
        Color = color or Color3.fromRGB(255, 255, 255),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Util.pad(parent, top, right, bottom, left)
    return Util.new("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = parent,
    })
end

function Util.list(parent, gap, dir, align, valign)
    return Util.new("UIListLayout", {
        Padding = UDim.new(0, gap or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        Parent = parent,
    })
end

function Util.tween(inst, props, info)
    local t = TweenService:Create(inst, info or ease.out, props)
    t:Play()
    return t
end

function Util.clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

function Util.round(v, step)
    if not step or step <= 0 then
        return v
    end
    return math.floor(v / step + 0.5) * step
end

function Util.decimals(step)
    if not step or step >= 1 then
        return 0
    end
    local s = string.format("%.6f", step):gsub("0+$", "")
    return #(s:match("%.(%d*)") or "")
end

function Util.format(v, step)
    local d = Util.decimals(step)
    if d == 0 then
        return tostring(math.floor(v + 0.5))
    end
    return string.format("%." .. d .. "f", v)
end

function Util.hover(button, target, idle, over, dur)
    target = target or button
    local info = TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    button.MouseEnter:Connect(function()
        Util.tween(target, over, info)
    end)
    button.MouseLeave:Connect(function()
        Util.tween(target, idle, info)
    end)
end

--[[
    Every draggable, slider and keybind used to open its own UserInputService
    connection. A window with 20 modules meant ~100 global handlers firing on
    every mouse move.

    Now there is one engine connection per phase and components register into it.
    Dragging and sliding go further: only one can be active at a time, so they
    share a single handler and a single piece of state rather than one each.
]]

local hub = { began = {}, changed = {}, ended = {} }
local wired = false

local function wire()
    if wired then
        return
    end
    wired = true

    UserInputService.InputBegan:Connect(function(input, typing)
        for i = #hub.began, 1, -1 do
            hub.began[i](input, typing)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        for i = #hub.changed, 1, -1 do
            hub.changed[i](input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        for i = #hub.ended, 1, -1 do
            hub.ended[i](input)
        end
    end)
end

-- Util.onInput("began" | "changed" | "ended", fn) -> disconnect
function Util.onInput(phase, fn)
    wire()
    local list = hub[phase]
    if not list then
        return function() end
    end
    table.insert(list, fn)
    return function()
        for i, entry in ipairs(list) do
            if entry == fn then
                table.remove(list, i)
                break
            end
        end
    end
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local gesture

Util.onInput("changed", function(input)
    if not gesture or not isMove(input) then
        return
    end
    gesture.move(input)
end)

Util.onInput("ended", function(input)
    if not gesture or not isPress(input) then
        return
    end
    local done = gesture
    gesture = nil
    if done.finish then
        done.finish()
    end
end)

function Util.drag(handle, target, onFinish)
    handle.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local origin, start = input.Position, target.Position
        gesture = {
            move = function(moved)
                local delta = moved.Position - origin
                target.Position =
                    UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
            end,
            finish = onFinish and function()
                onFinish(target.Position)
            end or nil,
        }
    end)
end

function Util.slide(track, onChange, onRelease)
    local function push(x)
        local alpha = Util.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        onChange(alpha)
        return alpha
    end

    track.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local alpha = push(input.Position.X)
        gesture = {
            move = function(moved)
                alpha = push(moved.Position.X)
            end,
            finish = onRelease and function()
                onRelease(alpha)
            end or nil,
        }
    end)
end

function Util.keyName(key)
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.UserInputType then
            local n = key.Name:gsub("MouseButton", "MB")
            return n
        end
        local n = key.Name
        n = n:gsub("^Left", "L"):gsub("^Right", "R")
        n = n:gsub("^KeyPad", "Num")
        if n:match("^Zero$") then n = "0" end
        return n
    end
    return "None"
end

--[[
    Where the interface lives decides whether a game can see it at all.

    gethui() is the good case: a container game scripts cannot reach, since
    CoreGui returns nil at LocalScript identity. protectgui + CoreGui is the
    fallback. PlayerGui is the last resort and is fully visible to the game —
    Util.protected is left false so callers can warn about it.
]]
Util.protected = false
Util.host = "unknown"

function Util.root()
    local gui = Util.new("ScreenGui", {
        Name = "\0" .. tostring(math.random(1e8, 1e9)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })

    if RunService:IsStudio() then
        gui.Parent = __service("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        return gui
    end

    -- executors name the hidden container differently; any of them is the good
    -- case, and only checking gethui threw away a working one
    for _, resolver in ipairs({
        gethui,
        get_hidden_gui,
        gethiddengui,
        get_hidden_ui,
        gethiddenui,
    }) do
        if type(resolver) == "function" then
            local ok, holder = pcall(resolver)
            if ok and typeof(holder) == "Instance" then
                local placed = pcall(function()
                    gui.Parent = holder
                end)
                if placed then
                    Util.protected = true
                    Util.host = "hidden"
                    return gui
                end
            end
        end
    end

    local protect = protectgui or (syn and syn.protect_gui)
    if protect then
        pcall(protect, gui)
    end

    local ok = pcall(function()
        gui.Parent = __service("CoreGui")
    end)
    if ok then
        -- CoreGui is already out of a game script's reach: GetService("CoreGui")
        -- returns nil at identity 2. protectgui hardens it further against other
        -- elevated code, but its absence does not make this PlayerGui.
        Util.protected = true
        Util.host = protect and "coregui+protect" or "coregui"
        return gui
    end

    gui.Parent = __service("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
    Util.host = "playergui"
    -- last resort: the tree is readable here, so hide the root from the calls a
    -- game script would use to find it
    Util.protected = Util.conceal(gui)
    if Util.protected then
        Util.host = "playergui+hooked"
    end
    return gui
end

--[[
    Concealment for executors that offer no hidden container.

    In PlayerGui the interface is an ordinary ScreenGui the game can enumerate.
    The root already carries a NUL-prefixed random name so it cannot be indexed,
    but GetChildren and GetDescendants still hand it over. This filters it out of
    the handful of calls a detection script actually uses.

    Honest limits, because this is the weakest tier by definition:
      - the hook itself is detectable by code that checksums __namecall
      - it hides the instance, never the behaviour
      - it only engages when the good paths are unavailable, so the common case
        pays nothing for it
]]
local hidden = setmetatable({}, { __mode = "k" })

local ENUMERATE = { GetChildren = true, GetDescendants = true }
local LOOKUP = {
    FindFirstChild = true,
    FindFirstChildOfClass = true,
    FindFirstChildWhichIsA = true,
    WaitForChild = true,
}

local function isHidden(value)
    if typeof(value) ~= "Instance" then
        return false
    end
    if hidden[value] then
        return true
    end
    -- a descendant of the root gives it away just as well; the walk is bounded
    -- by how shallow a ScreenGui tree is
    local node = value.Parent
    for _ = 1, 12 do
        if not node then
            return false
        end
        if hidden[node] then
            return true
        end
        node = node.Parent
    end
    return false
end

function Util.conceal(gui)
    if type(hookmetamethod) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(newcclosure) ~= "function"
    then
        return false
    end

    hidden[gui] = true
    if Util.concealing then
        return true
    end

    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()

            -- the library walks its own tree constantly (tinting an icon, finding
            -- a card's header). Filtering those calls would hide the interface
            -- from itself, so only calls made from outside the root are censored.
            if (ENUMERATE[method] or LOOKUP[method]) and isHidden(self) then
                return old(self, ...)
            end

            if ENUMERATE[method] then
                local list = old(self, ...)
                if type(list) == "table" then
                    for i = #list, 1, -1 do
                        if isHidden(list[i]) then
                            table.remove(list, i)
                        end
                    end
                end
                return list
            end

            if LOOKUP[method] then
                local found = old(self, ...)
                if isHidden(found) then
                    return nil
                end
                return found
            end

            return old(self, ...)
        end))
    end)

    Util.concealing = ok
    return ok
end

-- touch with no keyboard is the reliable mobile signal; viewport width alone
-- misreads a small windowed desktop client
function Util.isMobile()
    local touch = UserInputService.TouchEnabled
    local keyboard = UserInputService.KeyboardEnabled
    if touch and not keyboard then
        return true
    end
    local camera = __service("Workspace").CurrentCamera
    return camera ~= nil and camera.ViewportSize.X < 820
end

function Util.viewport()
    local camera = __service("Workspace").CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

--[[
    Binding to CurrentCamera once was not enough. The engine replaces the camera
    on respawn and on anything that scripts a cutscene, and the old connection
    goes with it — so a phone that rotated after dying never re-fitted and the
    window stayed clipped off the edge of the screen. Follow the swap instead.
]]
function Util.onViewport(fn)
    local workspace = __service("Workspace")
    local bound

    local function attach()
        if bound then
            bound:Disconnect()
            bound = nil
        end
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        bound = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            fn(camera.ViewportSize)
        end)
    end

    attach()

    local swap = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        attach()
        local camera = workspace.CurrentCamera
        if camera then
            fn(camera.ViewportSize)
        end
    end)

    return function()
        swap:Disconnect()
        if bound then
            bound:Disconnect()
            bound = nil
        end
    end
end

function Util.inset()
    local ok, gap = pcall(function()
        return __service("GuiService"):GetGuiInset().Y
    end)
    return ok and gap or 36
end

--[[
    The only per-frame connection in the library, so it is worth it being cheap
    and worth it stopping.

    It used to keep a growing list of frame times and `table.remove(samples, 1)`
    the front off it every frame — an O(n) shift, sixty times a second, forever,
    because the connection was never handed back and never disconnected. A
    watermark that had been destroyed an hour ago was still sampling.

    Now it is a counter and a window: two adds and a compare per frame, and the
    caller gets a stop function.
]]
function Util.fps()
    local frames, elapsed = 0, 0
    local value = 60

    local connection = RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        elapsed = elapsed + dt
        if elapsed >= 0.5 then
            value = frames / elapsed
            frames, elapsed = 0, 0
        end
    end)

    return function()
        return math.floor(value + 0.5)
    end, function()
        connection:Disconnect()
    end
end

function Util.ping()
    local Stats = __service("Stats")
    return function()
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and v then
            return math.floor(v + 0.5)
        end
        return 0
    end
end

--[[
    GetUserThumbnailAsync is a yielding web request. The player list called it for
    every row on every refresh — eight round trips a second, forever — which is
    the single most expensive thing the library used to do.

    rbxthumb:// is the content-url form of the same image: the engine resolves and
    caches it itself, no API call and no yield. The result is memoised anyway so a
    row that redraws does not even rebuild the string.
]]
local thumbs = {}

function Util.thumbnail(userId, size)
    local px = 150
    if typeof(size) == "EnumItem" then
        px = tonumber(size.Name:match("^Size(%d+)")) or 150
    elseif type(size) == "number" then
        px = size
    end
    local key = tostring(userId) .. "@" .. px
    local hit = thumbs[key]
    if hit then
        return hit
    end
    local url = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=" .. px .. "&h=" .. px
    thumbs[key] = url
    return url
end

return Util
end

__flowStartupCheckpoint()

end