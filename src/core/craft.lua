return function(__modules, __service, __flowStartupCheckpoint)
__modules["core/craft"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Icons = require("core/icons")

local Craft = {}

local function fill(props, defaults)
    for k, v in pairs(defaults) do
        if props[k] == nil then
            props[k] = v
        end
    end
    return props
end

function Craft.frame(props)
    local token = props.Token
    local radius = props.Radius
    local edge = props.Edge
    local edgeAlpha = props.EdgeTransparency
    props.Token, props.Radius, props.Edge, props.EdgeTransparency = nil, nil, nil, nil

    fill(props, { BorderSizePixel = 0, BackgroundColor3 = Theme.get(token or "surface") })
    local f = Util.new("Frame", props)

    if token then
        Theme.bind(f, "BackgroundColor3", token)
    end
    if radius then
        Util.corner(f, radius)
    end
    if edge then
        local s = Util.stroke(f, Theme.get(edge), 1, edgeAlpha or 0)
        Theme.bind(s, "Color", edge)
    end
    return f
end

function Craft.text(props)
    local token = props.Token
    props.Token = nil

    fill(props, {
        BackgroundTransparency = 1,
        FontFace = Theme.font.medium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        Text = "",
    })

    local l = Util.new("TextLabel", props)
    if props.TextColor3 == nil then
        Theme.bind(l, "TextColor3", token or "text")
    end
    return l
end

function Craft.button(props)
    local token = props.Token
    local radius = props.Radius
    local edge = props.Edge
    props.Token, props.Radius, props.Edge = nil, nil, nil

    fill(props, {
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        BackgroundTransparency = token and 0 or 1,
        BackgroundColor3 = Theme.get(token or "surfaceAlt"),
    })

    local b = Util.new("TextButton", props)
    if token then
        Theme.bind(b, "BackgroundColor3", token)
    end
    if radius then
        Util.corner(b, radius)
    end
    if edge then
        local s = Util.stroke(b, Theme.get(edge), 1, 0)
        Theme.bind(s, "Color", edge)
    end
    return b
end

function Craft.scroll(props)
    fill(props, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.25,
        ScrollBarImageColor3 = Theme.get("raisedHi"),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    })
    local s = Util.new("ScrollingFrame", props)
    Theme.bind(s, "ScrollBarImageColor3", "raisedHi")
    return s
end

function Craft.divider(parent, order, inset)
    local d = Craft.frame({
        Name = "Divider",
        Token = "lineSoft",
        Size = UDim2.new(1, -(inset or 0) * 2, 0, 1),
        Position = UDim2.fromOffset(inset or 0, 0),
        LayoutOrder = order or 0,
        Parent = parent,
    })
    return d
end

function Craft.tile(props)
    local holder = Craft.frame({
        Name = "Tile",
        Token = props.Token or "surfaceAlt",
        Radius = props.Radius or Theme.radius.tile,
        Size = UDim2.fromOffset(props.Size or 26, props.Size or 26),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    local glyph = Icons.draw({
        Icon = props.Icon or "cube",
        Size = props.IconSize or math.floor((props.Size or 26) * 0.55),
        Token = props.IconToken,
        Color = props.IconColor or Theme.get("textDim"),
        Hole = Theme.get(props.Token or "surfaceAlt"),
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = holder,
    })
    return holder, glyph
end

function Craft.chip(props)
    local holder = Craft.frame({
        Name = "Chip",
        Token = props.Token or "raised",
        Radius = props.Radius or Theme.radius.chip,
        Size = UDim2.fromOffset(0, props.Height or 22),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = props.LayoutOrder,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    Util.pad(holder, 0, props.PadX or 7, 0, props.PadX or 7)
    local label = Craft.text({
        Name = "Value",
        Text = props.Text or "",
        Token = props.TextToken or "textDim",
        TextSize = props.TextSize or 12,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = holder,
    })
    return holder, label
end

function Craft.head(props)
    local row = Craft.frame({
        Name = "Head",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = props.LayoutOrder or 0,
        ZIndex = props.ZIndex or 2,
        Parent = props.Parent,
    })
    Util.list(row, 3)

    Craft.text({
        Name = "Title",
        Text = props.Name or "",
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        Size = UDim2.new(1, props.Trim or 0, 0, 17),
        ZIndex = (props.ZIndex or 2) + 1,
        Parent = row,
    })

    if props.Desc and props.Desc ~= "" then
        Craft.text({
            Name = "Desc",
            Text = props.Desc,
            Token = "textFaint",
            TextSize = 12,
            FontFace = Theme.font.regular,
            TextWrapped = true,
            LineHeight = 1.15,
            Size = UDim2.new(1, props.Trim or 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = (props.ZIndex or 2) + 1,
            Parent = row,
        })
    end

    return row
end

function Craft.gradient(parent, from, to, rotation, transparency)
    return Util.new("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 0,
        Transparency = transparency or NumberSequence.new(0),
        Parent = parent,
    })
end

return Craft
end

__flowStartupCheckpoint()

end