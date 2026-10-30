return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/icons"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Lucide = require("core/lucide")

local Icons = {}

--[[
    Real Lucide artwork, drawn from spritesheets, is the default. The vector set
    below stays as the fallback for anything Lucide has no glyph for, and as the
    escape hatch if you would rather not depend on image assets at all:

        Flow.Icons.sprites = false
]]
Icons.sprites = Lucide

--[[
    Icons are authored on a 100x100 grid in the style of Lucide: 2px strokes on a
    24px canvas, round caps, no fills. On this grid that is a stroke weight of 8.

    line() is the workhorse — give it two endpoints and it works out the centre,
    length and angle itself, so an icon reads as a list of pen strokes rather than
    a pile of hand-computed rotations.
]]

local WEIGHT = 9.5

local function line(x1, y1, x2, y2, t, a)
    t = t or WEIGHT
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    -- + t so the rounded caps sit past the endpoints, the way a round linecap does
    return { "bar", (x1 + x2) / 2, (y1 + y2) / 2, len + t, t, math.deg(math.atan2(dy, dx)), 999, a or 0 }
end

local function circle(x, y, d, t, a)
    return { "ring", x, y, d, d, 0, 999, a or 0, t or WEIGHT }
end

local function rect(x, y, w, h, r, t, a)
    return { "box", x, y, w, h, 0, r or 0, a or 0, t or WEIGHT }
end

local function disc(x, y, d, a)
    return { "dot", x, y, d, d, 0, 999, a or 0 }
end

-- solid shape rather than an outline, for glyphs that read better filled at 13px
local function slab(x, y, w, h, rot, r, a)
    return { "bar", x, y, w, h, rot or 0, r or 0, a or 0 }
end

local function hole(x, y, d)
    return { "hole", x, y, d, d, 0, 999, 0 }
end

-- Names that resolve to a real image instead of drawn primitives. Anything that
-- takes an Icon accepts these the same way it accepts a shape name.
Icons.images = {
    -- the Image asset, not the Decal that wraps it (78239445499664) — decal ids
    -- do not render in ImageLabel.Image
    brand = "rbxassetid://120877581663049",
}

local set = {
    -- kept as the fallback silhouette if the brand image ever fails to load
    ["brand-vector"] = { slab(44, 50, 12, 60, -12, 5), slab(59, 26, 34, 12, -12, 5), slab(55, 50, 26, 12, -12, 5) },

    ----------------------------------------------------------------------------
    -- glyphs
    ----------------------------------------------------------------------------

    plus = { line(50, 20, 50, 80), line(20, 50, 80, 50) },
    minus = { line(20, 50, 80, 50) },
    close = { line(24, 24, 76, 76), line(76, 24, 24, 76) },
    check = { line(16, 52, 40, 76), line(40, 76, 84, 26) },

    ["chevron-down"] = { line(24, 38, 50, 64), line(76, 38, 50, 64) },
    ["chevron-up"] = { line(24, 62, 50, 36), line(76, 62, 50, 36) },
    ["chevron-right"] = { line(38, 24, 64, 50), line(38, 76, 64, 50) },
    ["chevron-left"] = { line(62, 24, 36, 50), line(62, 76, 36, 50) },
    ["chevrons-right"] = {
        line(20, 26, 46, 50),
        line(20, 74, 46, 50),
        line(52, 26, 78, 50),
        line(52, 74, 78, 50),
    },
    ["arrow-right"] = { line(16, 50, 84, 50), line(58, 24, 84, 50), line(58, 76, 84, 50) },
    ["arrow-up"] = { line(50, 84, 50, 16), line(24, 42, 50, 16), line(76, 42, 50, 16) },
    dots = { disc(20, 50, 12), disc(50, 50, 12), disc(80, 50, 12) },

    ----------------------------------------------------------------------------
    -- interface
    ----------------------------------------------------------------------------

    search = { circle(44, 44, 48), line(68, 68, 86, 86) },
    -- rim + hub + stubby teeth that touch the rim: reads as a cog, not a sun
    gear = {
        circle(50, 50, 46, 9),
        disc(50, 50, 16),
        line(50, 14, 50, 27, 15),
        line(50, 86, 50, 73, 15),
        line(14, 50, 27, 50, 15),
        line(86, 50, 73, 50, 15),
        line(24, 24, 33, 33, 15),
        line(76, 76, 67, 67, 15),
        line(76, 24, 67, 33, 15),
        line(24, 76, 33, 67, 15),
    },
    bell = {
        line(28, 64, 28, 44),
        line(72, 64, 72, 44),
        line(28, 44, 50, 24),
        line(72, 44, 50, 24),
        line(18, 66, 82, 66),
        disc(50, 82, 13),
    },
    user = {
        circle(50, 30, 32),
        line(18, 86, 18, 74),
        line(82, 86, 82, 74),
        line(18, 74, 34, 60),
        line(82, 74, 66, 60),
        line(34, 60, 66, 60),
    },
    users = {
        circle(40, 30, 28),
        line(12, 86, 12, 74),
        line(68, 86, 68, 74),
        line(12, 74, 26, 62),
        line(68, 74, 54, 62),
        line(26, 62, 54, 62),
        circle(76, 32, 22, 7, 0.35),
        line(88, 84, 88, 72, 7, 0.35),
        line(88, 72, 78, 62, 7, 0.35),
    },
    keyboard = {
        rect(50, 50, 84, 54, 10),
        disc(30, 42, 8),
        disc(50, 42, 8),
        disc(70, 42, 8),
        line(34, 62, 66, 62),
    },
    logout = {
        line(24, 18, 24, 82),
        line(24, 18, 52, 18),
        line(24, 82, 52, 82),
        line(46, 50, 88, 50),
        line(72, 34, 88, 50),
        line(72, 66, 88, 50),
    },
    folder = {
        line(12, 28, 40, 28),
        line(40, 28, 50, 42),
        line(12, 28, 12, 80),
        line(12, 80, 88, 80),
        line(88, 80, 88, 42),
        line(50, 42, 88, 42),
    },
    sliders = { line(12, 32, 88, 32), disc(66, 32, 20), line(12, 68, 88, 68), disc(34, 68, 20) },
    filter = { line(16, 26, 84, 26), line(30, 50, 70, 50), line(42, 74, 58, 74) },
    palette = { circle(50, 50, 76), disc(36, 38, 13), disc(62, 34, 13), disc(66, 60, 13) },
    info = { circle(50, 50, 76), disc(50, 30, 10), line(50, 46, 50, 70) },
    alert = { circle(50, 50, 76), line(50, 28, 50, 54), disc(50, 70, 10) },
    code = { line(34, 30, 14, 50), line(14, 50, 34, 70), line(66, 30, 86, 50), line(86, 50, 66, 70) },
    link = { line(42, 58, 58, 42), line(36, 64, 22, 78), line(64, 36, 78, 22), circle(24, 76, 30, 8), circle(76, 24, 30, 8) },
    cloud = { disc(36, 58, 34), disc(64, 52, 42), slab(50, 66, 56, 24, 0, 12) },
    badge = {
        circle(50, 34, 44),
        line(34, 60, 26, 90),
        line(66, 60, 74, 90),
        line(26, 90, 50, 78),
        line(74, 90, 50, 78),
    },
    chart = { line(14, 84, 86, 84), line(30, 84, 30, 58), line(50, 84, 50, 36), line(70, 84, 70, 20) },
    signal = { line(18, 84, 18, 70), line(38, 84, 38, 54), line(60, 84, 60, 36), line(82, 84, 82, 18) },
    gauge = { circle(50, 52, 68), disc(50, 52, 12), line(50, 52, 70, 32) },
    clock = { circle(50, 50, 76), line(50, 28, 50, 52), line(50, 52, 68, 62) },
    hourglass = {
        line(22, 16, 78, 16),
        line(22, 84, 78, 84),
        line(30, 16, 30, 34),
        line(70, 16, 70, 34),
        line(30, 34, 50, 50),
        line(70, 34, 50, 50),
        line(30, 84, 30, 66),
        line(70, 84, 70, 66),
        line(30, 66, 50, 50),
        line(70, 66, 50, 50),
    },
    refresh = {
        circle(50, 50, 62),
        line(62, 12, 80, 20),
        line(80, 20, 74, 38),
        line(38, 88, 20, 80),
        line(20, 80, 26, 62),
    },
    power = { circle(50, 56, 58), line(50, 14, 50, 44) },
    pin = { circle(50, 40, 44), disc(50, 40, 14), line(50, 62, 50, 88) },
    grid = { rect(31, 31, 26, 26, 5, 7), rect(69, 31, 26, 26, 5, 7), rect(31, 69, 26, 26, 5, 7), rect(69, 69, 26, 26, 5, 7) },
    layers = { slab(50, 34, 46, 46, 45, 8), slab(50, 62, 46, 46, 45, 8, 0.55) },
    expand = {
        line(14, 32, 14, 14),
        line(14, 14, 32, 14),
        line(68, 14, 86, 14),
        line(86, 14, 86, 32),
        line(86, 68, 86, 86),
        line(86, 86, 68, 86),
        line(32, 86, 14, 86),
        line(14, 86, 14, 68),
    },
    cube = { rect(50, 50, 64, 64, 12), line(50, 18, 50, 50, 7), line(50, 50, 22, 66, 7), line(50, 50, 78, 66, 7) },
    wand = { line(20, 80, 74, 26), disc(80, 20, 15), disc(24, 24, 10), disc(84, 58, 10) },
    sparkle = { line(50, 16, 50, 84, 9), line(16, 50, 84, 50, 9), line(28, 28, 72, 72, 7), line(72, 28, 28, 72, 7) },

    ----------------------------------------------------------------------------
    -- combat
    ----------------------------------------------------------------------------

    target = {
        circle(50, 50, 66),
        disc(50, 50, 14),
        line(50, 8, 50, 20),
        line(50, 80, 50, 92),
        line(8, 50, 20, 50),
        line(80, 50, 92, 50),
    },
    swords = {
        line(22, 78, 80, 20, 9),
        line(78, 78, 20, 20, 9),
        line(12, 70, 30, 88),
        line(88, 70, 70, 88),
    },
    shield = {
        line(20, 26, 50, 14),
        line(80, 26, 50, 14),
        line(20, 26, 20, 52),
        line(80, 26, 80, 52),
        line(20, 52, 50, 88),
        line(80, 52, 50, 88),
    },
    heart = { disc(34, 40, 40), disc(66, 40, 40), slab(50, 58, 48, 48, 45, 9) },
    flame = { disc(50, 68, 42), slab(50, 36, 34, 34, 45, 9) },
    bolt = {
        line(58, 10, 24, 54),
        line(24, 54, 52, 54),
        line(52, 54, 42, 90),
        line(42, 90, 76, 46),
        line(76, 46, 48, 46),
        line(48, 46, 58, 10),
    },
    ban = { circle(50, 50, 74), line(26, 74, 74, 26) },
    lock = { rect(50, 68, 56, 40, 9), line(34, 48, 34, 34), line(66, 48, 66, 34), line(34, 34, 50, 24), line(66, 34, 50, 24) },
    hitbox = {
        rect(50, 50, 62, 62, 10),
        disc(50, 50, 14),
        line(50, 24, 50, 36, 6, 0.35),
        line(50, 64, 50, 76, 6, 0.35),
        line(24, 50, 36, 50, 6, 0.35),
        line(64, 50, 76, 50, 6, 0.35),
    },
    skull = { disc(50, 42, 56), slab(50, 76, 36, 22, 0, 7), hole(36, 42, 16), hole(64, 42, 16) },
    magnet = {
        line(26, 72, 26, 40, 9),
        line(74, 72, 74, 40, 9),
        line(26, 40, 50, 20, 9),
        line(74, 40, 50, 20, 9),
        line(18, 72, 34, 72),
        line(66, 72, 82, 72),
    },

    ----------------------------------------------------------------------------
    -- movement
    ----------------------------------------------------------------------------

    fly = { line(12, 50, 88, 20), line(88, 20, 56, 86), line(56, 86, 46, 56), line(46, 56, 12, 50) },
    jump = { line(50, 64, 50, 18), line(30, 38, 50, 18), line(70, 38, 50, 18), line(18, 86, 82, 86) },
    noclip = { rect(50, 50, 62, 62, 10), line(26, 74, 74, 26) },
    teleport = { circle(26, 74, 28), circle(74, 26, 28), line(42, 58, 58, 42) },
    orbit = { circle(50, 50, 60), disc(50, 50, 18), disc(86, 28, 14) },

    ----------------------------------------------------------------------------
    -- visuals
    ----------------------------------------------------------------------------

    eye = { circle(50, 50, 50), disc(50, 50, 18), line(8, 50, 20, 50), line(80, 50, 92, 50) },
    esp = {
        line(16, 34, 16, 16),
        line(16, 16, 34, 16),
        line(66, 16, 84, 16),
        line(84, 16, 84, 34),
        line(84, 66, 84, 84),
        line(84, 84, 66, 84),
        line(34, 84, 16, 84),
        line(16, 84, 16, 66),
        disc(50, 50, 16),
    },
    tracer = { disc(50, 18, 18), line(50, 34, 50, 76), line(50, 86, 30, 60), line(50, 86, 70, 60) },
    ghost = { disc(50, 44, 52), slab(50, 62, 52, 32, 0, 7), hole(38, 42, 12), hole(62, 42, 12) },
    radar = { circle(50, 50, 78), circle(50, 50, 42, 7, 0.4), disc(50, 50, 11), line(50, 50, 76, 30) },
    wall = { rect(50, 50, 76, 60, 6), line(12, 50, 88, 50), line(50, 20, 50, 50), line(32, 50, 32, 80), line(68, 50, 68, 80) },

    ----------------------------------------------------------------------------
    -- utility
    ----------------------------------------------------------------------------

    backpack = { rect(50, 62, 58, 48, 10), line(36, 38, 36, 26), line(64, 38, 64, 26), line(36, 26, 64, 26), line(38, 62, 62, 62) },
    coin = { circle(50, 50, 70), line(50, 32, 50, 68), line(38, 40, 62, 40), line(38, 60, 62, 60) },
    flask = { line(40, 14, 40, 44), line(60, 14, 60, 44), line(32, 14, 68, 14), line(40, 44, 20, 82), line(60, 44, 80, 82), line(20, 82, 80, 82) },
    crown = {
        line(14, 30, 24, 76),
        line(24, 76, 76, 76),
        line(76, 76, 86, 30),
        line(14, 30, 32, 46),
        line(32, 46, 50, 20),
        line(50, 20, 68, 46),
        line(68, 46, 86, 30),
    },
    star = { line(50, 14, 50, 86, 9), line(14, 50, 86, 50, 9), line(26, 26, 74, 74, 8), line(74, 26, 26, 74, 8) },
    branch = { circle(28, 22, 24), circle(28, 78, 24), line(28, 34, 28, 66), line(40, 78, 68, 78), circle(80, 78, 24) },
}

-- Second names for the same glyph, so modules can be named after what they do.
-- Resolved before both the sprite and the vector lookup.
local alias = {
    crosshair = "target",
    aim = "target",
    combat = "swords",
    movement = "chevrons-right",
    visuals = "eye",
    render = "expand",
    speed = "chevrons-right",
    settings = "gear",
    fps = "gauge",
    ping = "signal",
    box = "cube",
    scan = "esp",
    cog = "gear",

    silentaim = "target",
    aimbot = "target",
    killaura = "swords",
    reach = "expand",
    nametags = "badge",
    chams = "layers",
    fullbright = "sparkle",
    xray = "eye",
    antiafk = "clock",
    autofarm = "refresh",
    serverhop = "link",
    rejoin = "refresh",
    bhop = "jump",
    walkspeed = "chevrons-right",
    jumppower = "jump",
    infjump = "jump",
    godmode = "shield",
    player = "user",
    utility = "sliders",
    exploit = "code",
    world = "orbit",
    item = "cube",
    tool = "swords",
}

for from, to in pairs(alias) do
    set[from] = set[to]
end

Icons.alias = alias

Icons.set = set

function Icons.list()
    local names = {}
    for k in pairs(set) do
        table.insert(names, k)
    end
    for k in pairs(Icons.images) do
        if not set[k] then
            table.insert(names, k)
        end
    end
    for k in pairs(Icons.sprites or {}) do
        if not set[k] and not Icons.images[k] then
            table.insert(names, k)
        end
    end
    table.sort(names)
    return names
end

function Icons.define(name, parts)
    set[name] = parts
end

-- register an image under a shape name, e.g. Icons.image("brand", "rbxassetid://123")
function Icons.image(name, asset)
    Icons.images[name] = asset
end

-- authoring helpers, exposed so custom icons can be written the same way
Icons.line = line
Icons.circle = circle
Icons.rect = rect
Icons.disc = disc
Icons.slab = slab
Icons.hole = hole

local function assetOf(name)
    if typeof(name) ~= "string" then
        return nil
    end
    local mapped = Icons.images[name]
    if mapped then
        return mapped
    end
    if name:match("^rbxasset") or name:match("^rbxthumb") or name:match("^http") then
        return name
    end
    return nil
end

function Icons.draw(props)
    local size = props.Size or 16
    local name = props.Icon
    if typeof(name) == "string" and Icons.alias[name] and not Icons.images[name] then
        name = Icons.alias[name]
    end
    local holder = Util.new("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Position = props.Position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })

    -- a Lucide sprite wins over the vector drawing when one exists
    local sprite = Icons.sprites and typeof(name) == "string" and Icons.sprites[name]
    if sprite and not Icons.images[name] then
        local img = Util.new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://" .. tostring(sprite[1]),
            ImageRectSize = Vector2.new(sprite[2], sprite[3]),
            ImageRectOffset = Vector2.new(sprite[4], sprite[5]),
            ImageTransparency = props.Transparency or 0,
            ZIndex = holder.ZIndex,
            Parent = holder,
        })
        if props.Token then
            Theme.bind(img, "ImageColor3", props.Token)
        else
            img.ImageColor3 = props.Color or Theme.get("text")
        end
        holder:SetAttribute("Image", true)
        return holder
    end

    local asset = assetOf(name)
    if asset then
        local img = Util.new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = asset,
            ImageTransparency = props.Transparency or 0,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = holder.ZIndex,
            Parent = holder,
        })
        -- brand marks keep their own colours unless a tint is explicitly requested
        if props.Token then
            Theme.bind(img, "ImageColor3", props.Token)
        elseif props.Color then
            img.ImageColor3 = props.Color
        end
        holder:SetAttribute("Image", true)
        Icons.rescue(holder, img, props, size)
        return holder
    end

    local parts = set[name]
    if not parts then
        return holder
    end

    local unit = size / 100
    local fill = props.Color or Theme.get("text")
    local void = props.Hole or Theme.get("surface")
    local alpha = props.Transparency or 0

    for _, p in ipairs(parts) do
        local kind, x, y, w, h, rot, r, a, t = p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9]
        local piece = Util.new("Frame", {
            Name = kind,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x / 100, y / 100),
            Size = UDim2.fromOffset(math.max(w * unit, 1), math.max(h * unit, 1)),
            Rotation = rot,
            BorderSizePixel = 0,
            BackgroundTransparency = alpha + (a or 0) * (1 - alpha),
            ZIndex = holder.ZIndex,
            Parent = holder,
        })

        if r and r > 0 then
            Util.corner(piece, r >= 999 and UDim.new(1, 0) or UDim.new(0, math.max(r * unit, 1)))
        end

        if kind == "ring" or kind == "box" then
            piece.BackgroundTransparency = 1
            local edge = Util.stroke(piece, fill, math.max((t or WEIGHT) * unit, 1), alpha + (a or 0) * (1 - alpha))
            if props.Token then
                Theme.bind(edge, "Color", props.Token)
            end
        elseif kind == "hole" then
            piece.BackgroundColor3 = void
            piece.ZIndex = holder.ZIndex + 1
            if props.HoleToken then
                Theme.bind(piece, "BackgroundColor3", props.HoleToken)
            end
        else
            piece.BackgroundColor3 = fill
            if props.Token then
                Theme.bind(piece, "BackgroundColor3", props.Token)
            end
        end
    end

    return holder
end

--[[
    A dead asset id renders as nothing at all, which reads as a missing icon
    rather than a broken one. Scripts carry plenty of them — ids get moderated or
    deleted long after the script was written — so when the fetch actually fails,
    swap in a drawn glyph.

    The replacement pieces are moved into the original holder rather than nested
    inside a second one, because Icons.tint colours the holder's direct children.
]]
function Icons.rescue(holder, img, props, size)
    task.spawn(function()
        if img.IsLoaded then
            return
        end

        local failed = false
        local provider = __service("ContentProvider")
        if provider then
            -- PreloadAsync yields until the fetch settles, but with a card full
            -- of icons the status callback does not reliably fire for every
            -- one, so its verdict is only ever used to fail fast
            pcall(function()
                provider:PreloadAsync({ img }, function(_, status)
                    failed = status ~= Enum.AssetFetchStatus.Success
                end)
            end)
        end

        -- the authority is IsLoaded: once the fetch has settled, an image that
        -- still has not loaded is one that never will
        if not failed then
            local deadline = os.clock() + 5
            while not img.IsLoaded and os.clock() < deadline do
                task.wait(0.25)
            end
            failed = not img.IsLoaded
        end

        if not failed or img.IsLoaded or not holder.Parent then
            return
        end

        local spare = Icons.draw({
            Icon = props.Fallback or "cube",
            Size = size,
            Token = props.Token,
            Color = props.Color,
            Hole = props.Hole,
            HoleToken = props.HoleToken,
            Transparency = props.Transparency,
            ZIndex = props.ZIndex,
        })
        img:Destroy()
        -- the fallback may itself be a sprite rather than a drawn glyph, and
        -- Icons.tint reads this attribute to decide how to colour the holder
        holder:SetAttribute("Image", spare:GetAttribute("Image"))
        for _, piece in ipairs(spare:GetChildren()) do
            piece.Parent = holder
        end
        spare:Destroy()
    end)
end

function Icons.tint(holder, color, void)
    if holder:GetAttribute("Image") then
        local img = holder:FindFirstChildWhichIsA("ImageLabel")
        if img then
            img.ImageColor3 = color
        end
        return
    end
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local edge = piece:FindFirstChildWhichIsA("UIStroke")
            if edge then
                edge.Color = color
            elseif piece.Name == "hole" then
                if void then
                    piece.BackgroundColor3 = void
                end
            else
                piece.BackgroundColor3 = color
            end
        end
    end
end

function Icons.fade(holder, transparency)
    for _, piece in ipairs(holder:GetChildren()) do
        if piece:IsA("Frame") then
            local edge = piece:FindFirstChildWhichIsA("UIStroke")
            if edge then
                Util.tween(edge, { Transparency = transparency }, Util.ease.snap)
            else
                Util.tween(piece, { BackgroundTransparency = transparency }, Util.ease.snap)
            end
        end
    end
end

return Icons
end

__flowStartupCheckpoint()

end