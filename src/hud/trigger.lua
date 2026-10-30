return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/trigger"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Panel = require("hud/panel")

-- A pill that opens and closes the menu, so the interface is reachable without
-- knowing the keybind. Sits top centre by default and is draggable.
local Trigger = {}
Trigger.__index = Trigger

function Trigger.new(props)
    local self = setmetatable({}, Trigger)
    self.onToggle = props.OnToggle
    self.open = props.Default ~= false

    local frame = Panel.glass({
        Name = "Trigger",
        Size = UDim2.fromOffset(0, 36),
        AutomaticSize = Enum.AutomaticSize.X,
        Radius = 10,
        Position = props.Position or UDim2.new(0.5, -70, 0, props.Top or 18),
        Parent = props.Parent,
    })
    self.Frame = frame

    -- the pill auto-sizes, so centre it once its real width is known
    if not props.Position then
        task.defer(function()
            if frame.Parent then
                frame.Position = UDim2.new(0.5, -math.floor(frame.AbsoluteSize.X / 2), 0, props.Top or 18)
            end
        end)
    end

    local button = Craft.button({
        Name = "Hit",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 5,
        Parent = frame,
    })

    local row = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 3,
        Parent = frame,
    })
    Util.pad(row, 0, 12, 0, 9)
    Util.list(row, 9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    -- bare logo, matching the window header rather than sitting in a tile
    local markName = props.Mark or "brand"
    local mark = Craft.frame({
        Name = "Mark",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(24, 24),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = row,
    })
    Icons.draw({ Icon = markName, Size = 24, ZIndex = 5, Parent = mark })

    Craft.text({
        Name = "Label",
        Text = props.Text or "FLOW",
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.bold,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = row,
    })

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 16),
        BackgroundTransparency = 0.35,
        LayoutOrder = 3,
        ZIndex = 4,
        Parent = row,
    })

    local caretCell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        LayoutOrder = 4,
        ZIndex = 4,
        Parent = row,
    })
    self.Caret = Icons.draw({ Icon = "chevron-down", Size = 15, Token = "textDim", ZIndex = 5, Parent = caretCell })

    -- count of enabled modules: on mobile this pill is the only always-visible
    -- surface, so it carries the one number worth glancing at
    self.Badge = Craft.frame({
        Name = "Badge",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(1, -4, 0, -4),
        AnchorPoint = Vector2.new(1, 0),
        Visible = false,
        ZIndex = 7,
        Parent = frame,
    })
    self.BadgeText = Craft.text({
        Name = "Count",
        Text = "0",
        Token = "white",
        TextSize = 11,
        FontFace = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 8,
        Parent = self.Badge,
    })

    Util.hover(button, frame, { BackgroundTransparency = 0.12 }, { BackgroundTransparency = 0 })

    -- a drag should move the pill, not fire the toggle
    local moved, downAt = false, nil
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            moved, downAt = false, input.Position
        end
    end)
    button.InputChanged:Connect(function(input)
        if downAt and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if (input.Position - downAt).Magnitude > 6 then
                moved = true
            end
        end
    end)
    button.MouseButton1Click:Connect(function()
        if not moved then
            self:Toggle()
        end
    end)

    Util.drag(frame, frame, props.OnMove)

    self:Paint()
    return self
end

function Trigger:Toggle(state)
    if state == nil then
        state = not self.open
    end
    self.open = state and true or false
    self:Paint()
    if self.onToggle then
        task.spawn(self.onToggle, self.open)
    end
end

function Trigger:Paint()
    Util.tween(self.Caret, { Rotation = self.open and 180 or 0 }, Util.ease.out)
    Icons.tint(self.Caret, self.open and Theme.get("accent") or Theme.get("textDim"))
end

-- n enabled modules; hides itself at zero so an idle menu stays clean
function Trigger:SetCount(n)
    n = tonumber(n) or 0
    local show = n > 0
    self.BadgeText.Text = n > 99 and "99+" or tostring(n)
    self.Badge.Size = UDim2.fromOffset(n > 9 and 22 or 18, 18)

    if show ~= self.Badge.Visible then
        self.Badge.Visible = show
        if show then
            local pop = Util.new("UIScale", { Scale = 0.6, Parent = self.Badge })
            Util.tween(pop, { Scale = 1 }, Util.ease.spring)
            task.delay(0.5, function()
                if pop.Parent then
                    pop:Destroy()
                end
            end)
        end
    end
end

function Trigger:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Trigger:Destroy()
    self.Frame:Destroy()
end

return Trigger
end

__flowStartupCheckpoint()

end