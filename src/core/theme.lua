return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/theme"] = function(require)
__flowStartupCheckpoint()
local Theme = {}

local rgb = Color3.fromRGB

local base = {
    backdrop = rgb(16, 15, 21),
    surface = rgb(23, 22, 30),
    surfaceAlt = rgb(29, 28, 37),
    raised = rgb(37, 35, 47),
    raisedHi = rgb(46, 44, 58),

    line = rgb(43, 41, 55),
    lineSoft = rgb(32, 31, 41),

    text = rgb(234, 233, 241),
    textDim = rgb(150, 147, 166),
    textFaint = rgb(104, 101, 121),

    danger = rgb(238, 92, 100),
    success = rgb(72, 205, 141),
    warning = rgb(240, 178, 78),

    white = rgb(255, 255, 255),
    black = rgb(0, 0, 0),
}

Theme.tokens = {}
Theme.accent = rgb(124, 92, 255)
Theme.radius = { window = 12, card = 10, control = 8, chip = 6, tile = 7 }
-- one left/right inset for every band inside a window: header, tab strip, card
-- lanes and footer. They drifted to 16, 18 and 18 and the 2px told.
Theme.gutter = 14

--[[
    The fixed bands a window is built from. These used to be literals scattered
    across window.lua — a 72 here, a 121 and a 122 there, each one silently
    derived from the two above it — so tightening the chrome meant finding all of
    them and getting the arithmetic right by hand. One table, and `top` is the
    y where the page starts.
]]
Theme.chrome = {}

--[[
    Two densities.

    `compact` is the desktop build: a mouse pointer is one pixel, so the only
    limit on how tight the chrome gets is legibility.

    `touch` exists because none of that holds on a phone. A fingertip covers
    around 9mm, the interface is additionally scaled down to fit a small screen,
    and 28px of tab strip at 0.8 scale is a 22px target — under half of what
    every mobile guideline asks for. Touch mode buys the difference back on the
    things that are actually pressed and leaves the rest alone.

    Set before anything is built, so this is a table swap rather than a relayout.
]]
local densities = {
    compact = {
        header = 58,
        strip = 40,
        footer = 36,
        -- the collapsed height of a module card, and the gap between cards and lanes
        card = 44,
        gap = 10,
        -- press targets: tab button, header icon button, search field
        tab = 28,
        icon = 30,
        field = 30,
        switch = Vector2.new(38, 21),
    },
    touch = {
        header = 62,
        strip = 48,
        footer = 38,
        card = 48,
        gap = 10,
        tab = 38,
        icon = 38,
        field = 36,
        switch = Vector2.new(46, 26),
    },
}

function Theme.density(mode)
    local picked = densities[mode] or densities.compact
    for k, v in pairs(picked) do
        Theme.chrome[k] = v
    end
    Theme.chrome.mode = densities[mode] and mode or "compact"
    Theme.chrome.top = Theme.chrome.header + Theme.chrome.strip
    return Theme.chrome
end

Theme.density("compact")

local family = "rbxasset://fonts/families/BuilderSans.json"

Theme.font = {
    regular = Font.new(family, Enum.FontWeight.Regular),
    medium = Font.new(family, Enum.FontWeight.Medium),
    semi = Font.new(family, Enum.FontWeight.SemiBold),
    bold = Font.new(family, Enum.FontWeight.Bold),
}

-- instance -> { [property] = token }. Keyed by instance rather than kept as a
-- flat list so re-binding a property replaces the token instead of appending a
-- second entry that races the first.
local bindings = {}
local watchers = {}

local function derive()
    for k, v in pairs(base) do
        Theme.tokens[k] = v
    end
    local a = Theme.accent
    Theme.tokens.accent = a
    Theme.tokens.accentDeep = a:Lerp(base.black, 0.34)
    Theme.tokens.accentGlow = a:Lerp(base.white, 0.28)
    Theme.tokens.accentSoft = a:Lerp(base.surface, 0.74)
    Theme.tokens.accentEdge = a:Lerp(base.line, 0.45)
end

derive()

function Theme.get(token)
    return Theme.tokens[token] or base.text
end

function Theme.bind(inst, prop, token)
    inst[prop] = Theme.get(token)

    local props = bindings[inst]
    if not props then
        props = {}
        bindings[inst] = props
        --[[
            Dropping the entry here is what keeps this table bounded. The sweep
            in setAccent cannot do it: Roblox happily accepts a property write on
            a destroyed instance, so the pcall around it never fails and nothing
            was ever pruned. Every notification toast, overlay panel and tooltip
            left its labels behind for the rest of the session, and each accent
            change then had to walk all of them.

            A weak-keyed table looks like the tidier fix but is wrong here: the
            Lua handle for an instance is collectable while the instance is still
            in the tree, so elements nothing else holds a reference to would
            silently stop following the theme.
        ]]
        inst.Destroying:Connect(function()
            bindings[inst] = nil
        end)
    end
    props[prop] = token

    return inst
end

-- point an existing binding at a different token. Writing the property directly
-- would hold only until the next accent change re-ran the binding list.
function Theme.rebind(inst, prop, token)
    return Theme.bind(inst, prop, token)
end

function Theme.watch(fn)
    table.insert(watchers, fn)
    return function()
        for i, v in ipairs(watchers) do
            if v == fn then
                table.remove(watchers, i)
                break
            end
        end
    end
end

function Theme.setAccent(color)
    Theme.accent = color
    derive()

    for inst, props in pairs(bindings) do
        local ok = pcall(function()
            for prop, token in pairs(props) do
                inst[prop] = Theme.get(token)
            end
        end)
        if not ok then
            bindings[inst] = nil
        end
    end

    for i = #watchers, 1, -1 do
        local fn = watchers[i]
        local ok, keep = pcall(fn)
        if not ok or keep == false then
            table.remove(watchers, i)
        end
    end
end

--[[
    Watchers only pruned themselves on the next accent change, because that is
    the only thing that ever ran them. A session that never touches the accent —
    most of them — kept every watcher from every reload. This runs the same prune
    pass on demand and repaints nothing that is still alive.
]]
function Theme.sweep()
    local dropped = 0
    for inst in pairs(bindings) do
        if not inst.Parent then
            bindings[inst] = nil
            dropped = dropped + 1
        end
    end
    for i = #watchers, 1, -1 do
        local ok, keep = pcall(watchers[i])
        if not ok or keep == false then
            table.remove(watchers, i)
            dropped = dropped + 1
        end
    end
    return dropped
end

function Theme.setFont(assetPath)
    Theme.font.regular = Font.new(assetPath, Enum.FontWeight.Regular)
    Theme.font.medium = Font.new(assetPath, Enum.FontWeight.Medium)
    Theme.font.semi = Font.new(assetPath, Enum.FontWeight.SemiBold)
    Theme.font.bold = Font.new(assetPath, Enum.FontWeight.Bold)
end

return Theme
end

__flowStartupCheckpoint()

end