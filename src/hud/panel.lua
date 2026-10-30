return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/panel"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")

local Panel = {}
Panel.__index = Panel

function Panel.glass(props)
    local frame = Craft.frame({
        Name = props.Name or "Panel",
        Token = "backdrop",
        Radius = props.Radius or 10,
        BackgroundTransparency = props.Transparency or 0.12,
        Size = props.Size or UDim2.fromOffset(200, 0),
        Position = props.Position or UDim2.fromOffset(20, 20),
        AnchorPoint = props.AnchorPoint,
        AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.Y,
        Parent = props.Parent,
    })
    local edge = Util.stroke(frame, Theme.get("line"), 1, 0.4)
    Theme.bind(edge, "Color", "line")
    return frame
end

function Panel.new(props)
    local self = setmetatable({}, Panel)
    self.rows = {}

    local frame = Panel.glass({
        Name = props.Title or "Panel",
        Size = UDim2.fromOffset(props.Width or 196, 0),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        Parent = props.Parent,
    })
    Util.list(frame, 0)
    self.Frame = frame

    if props.Title then
        local head = Craft.frame({
            Name = "Head",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36),
            LayoutOrder = 1,
            Parent = frame,
        })

        local cell = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(36, 36),
            Parent = head,
        })
        Icons.draw({ Icon = props.Icon or "grid", Size = 15, Token = "textDim", ZIndex = 3, Parent = cell })

        Craft.frame({
            Token = "line",
            Size = UDim2.fromOffset(1, 15),
            Position = UDim2.new(0, 36, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 0.35,
            ZIndex = 3,
            Parent = head,
        })

        Craft.text({
            Text = props.Title,
            Token = "text",
            TextSize = 13,
            FontFace = Theme.font.semi,
            Position = UDim2.fromOffset(48, 0),
            Size = UDim2.new(1, -58, 1, 0),
            ZIndex = 3,
            Parent = head,
        })

        Craft.frame({
            Token = "line",
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.fromOffset(0, 35),
            BackgroundTransparency = 0.45,
            ZIndex = 3,
            Parent = head,
        })
    end

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Parent = frame,
    })
    -- callers tune spacing through props; a second UIPadding or UIListLayout on the
    -- same frame fights the first one, so the body only ever gets these
    Util.list(body, props.Gap or 0)
    Util.pad(body, props.PadTop or 5, props.PadX or 0, props.PadBottom or 6, props.PadX or 0)
    self.Body = body

    if props.Draggable ~= false then
        Util.drag(frame, frame, props.OnMove)
    end

    return self
end

function Panel:Row(props)
    local row = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, props.Height or 30),
        LayoutOrder = props.LayoutOrder or (#self.rows + 1),
        Parent = self.Body,
    })

    local cell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(36, props.Height or 30),
        Parent = row,
    })
    local glyph = Icons.draw({
        Icon = props.Icon or "cube",
        Size = 15,
        Color = props.Color or Theme.get("accent"),
        ZIndex = 3,
        Parent = cell,
    })

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 13),
        Position = UDim2.new(0, 36, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.5,
        ZIndex = 3,
        Parent = row,
    })

    local label = Craft.text({
        Text = props.Name or "",
        Token = "textDim",
        TextSize = 12.5,
        FontFace = Theme.font.medium,
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -92, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = row,
    })

    local value = Craft.text({
        Text = props.Value or "",
        Token = "textFaint",
        TextSize = 12,
        FontFace = Theme.font.semi,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -13, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 64, 1, 0),
        ZIndex = 3,
        Parent = row,
    })

    local entry = { Frame = row, Label = label, Value = value, Glyph = glyph }
    table.insert(self.rows, entry)
    return entry
end

function Panel:Clear()
    for _, entry in ipairs(self.rows) do
        entry.Frame:Destroy()
    end
    table.clear(self.rows)
end

function Panel:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

return Panel
end

__flowStartupCheckpoint()

end