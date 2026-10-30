return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/watermark"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Panel = require("hud/panel")

local Watermark = {}
Watermark.__index = Watermark

local lp = Players.LocalPlayer

function Watermark.new(props)
    local self = setmetatable({}, Watermark)

    local frame = Panel.glass({
        Name = "Watermark",
        Size = UDim2.fromOffset(0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        Radius = 9,
        Position = props.Position or UDim2.fromOffset(18, 18),
        Parent = props.Parent,
    })
    Util.pad(frame, 0, 13, 0, 6)
    Util.list(frame, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.Frame = frame

    local avatar = Util.new("ImageLabel", {
        Name = "Avatar",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(23, 23),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = frame,
    })
    Util.corner(avatar, 6)
    task.spawn(function()
        avatar.Image = Util.thumbnail(lp.UserId)
    end)

    local identity = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        ZIndex = 3,
        Parent = frame,
    })
    Util.list(identity, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local userCell = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(14, 14),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = identity,
    })
    Icons.draw({ Icon = "user", Size = 14, Token = "textDim", ZIndex = 5, Parent = userCell })

    Craft.text({
        Text = props.Name or lp.DisplayName,
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = identity,
    })

    if props.Tag then
        local badge = Craft.frame({
            Token = "accentSoft",
            Radius = 5,
            Size = UDim2.fromOffset(0, 17),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 3,
            ZIndex = 4,
            Parent = identity,
        })
        Util.pad(badge, 0, 5, 0, 5)
        Craft.text({
            Text = props.Tag,
            Token = "accentGlow",
            TextSize = 10.5,
            FontFace = Theme.font.bold,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
            Parent = badge,
        })
    end

    local function stat(icon, order)
        local group = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = frame,
        })
        Util.list(group, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        local cell = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(14, 14),
            LayoutOrder = 1,
            ZIndex = 4,
            Parent = group,
        })
        Icons.draw({ Icon = icon, Size = 14, Token = "accent", ZIndex = 5, Parent = cell })

        local value = Craft.text({
            Text = "0",
            Token = "text",
            TextSize = 13,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            ZIndex = 4,
            Parent = group,
        })

        local unit = Craft.text({
            Text = "",
            Token = "textFaint",
            TextSize = 11,
            FontFace = Theme.font.medium,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 3,
            ZIndex = 4,
            Parent = group,
        })

        return value, unit
    end

    local function split(order)
        Craft.frame({
            Token = "line",
            Size = UDim2.fromOffset(1, 16),
            BackgroundTransparency = 0.35,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = frame,
        })
    end

    split(3)
    local pingValue, pingUnit = stat("signal", 4)
    pingUnit.Text = "ms"
    split(5)
    local fpsValue, fpsUnit = stat("gauge", 6)
    fpsUnit.Text = "fps"
    split(7)
    local playerValue, playerUnit = stat("users", 8)
    playerUnit.Text = "players"

    -- the sampler is the library's only RenderStepped connection, so hold on to
    -- the stop function: without it a destroyed watermark kept sampling for the
    -- rest of the session, and every reload of the script added another one
    local readFps, stopFps = Util.fps()
    local readPing = Util.ping()
    self.stopFps = stopFps

    self.alive = true

    task.spawn(function()
        while self.alive do
            if not self.Hidden then
                fpsValue.Text = tostring(readFps())
            end
            task.wait(0.25)
        end
    end)

    task.spawn(function()
        while self.alive do
            if not self.Hidden then
                pingValue.Text = tostring(readPing())
                playerValue.Text = tostring(#Players:GetPlayers())
            end
            task.wait(1)
        end
    end)

    -- pinned by default so it keeps its clearance from the Roblox topbar;
    -- pass Draggable = true to let it be moved
    self.Fixed = not props.Draggable
    if props.Draggable then
        Util.drag(frame, frame, props.OnMove)
    end

    return self
end

function Watermark:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Watermark:Destroy()
    self.alive = false
    if self.stopFps then
        self.stopFps()
        self.stopFps = nil
    end
    self.Frame:Destroy()
end

return Watermark
end

__flowStartupCheckpoint()

end