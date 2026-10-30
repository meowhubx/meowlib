return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/notify"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Overlay = require("ui/overlay")

local Notify = {}

Notify.history = {}

local stack

local tone = {
    info = "accent",
    success = "success",
    danger = "danger",
    warning = "warning",
}

function Notify.attach(layer)
    stack = Craft.frame({
        Name = "Toasts",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(276, 400),
        Position = UDim2.new(1, -18, 1, -18),
        AnchorPoint = Vector2.new(1, 1),
        Parent = layer,
    })
    Util.list(stack, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
end

function Notify.push(opts)
    opts = opts or {}
    local kind = tone[opts.Kind or "info"] or "accent"
    table.insert(Notify.history, 1, {
        Title = opts.Title or "Notice",
        Text = opts.Text or "",
        Icon = opts.Icon or "info",
        Kind = kind,
        Stamp = os.date("%H:%M"),
    })
    while #Notify.history > 24 do
        table.remove(Notify.history)
    end

    if not stack then
        return
    end

    local card = Util.new("CanvasGroup", {
        Name = "Toast",
        BackgroundColor3 = Theme.get("surface"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1,
        Position = UDim2.fromOffset(44, 0),
        Parent = stack,
    })
    Theme.bind(card, "BackgroundColor3", "surface")
    Util.corner(card, 12)
    local edge = Util.stroke(card, Theme.get("line"), 1, 0.2)
    Theme.bind(edge, "Color", "line")

    -- scale is what makes the entrance feel like it arrives rather than slides;
    -- it animates alongside position and fade
    local scale = Util.new("UIScale", { Scale = 0.92, Parent = card })

    local inner = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = card,
    })
    Util.pad(inner, 12, 12, 13, 13)

    Craft.tile({
        Icon = opts.Icon or "info",
        Size = 28,
        Token = "surfaceAlt",
        IconToken = kind,
        Position = UDim2.fromOffset(0, 1),
        AnchorPoint = Vector2.new(0, 0),
        ZIndex = 4,
        Parent = inner,
    })

    local words = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -39, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(39, 0),
        ZIndex = 4,
        Parent = inner,
    })
    Util.list(words, 2)

    Craft.text({
        Text = opts.Title or "Notice",
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        Size = UDim2.new(1, 0, 0, 17),
        ZIndex = 5,
        Parent = words,
    })

    if opts.Text and opts.Text ~= "" then
        Craft.text({
            Text = opts.Text,
            Token = "textFaint",
            TextSize = 12,
            FontFace = Theme.font.regular,
            TextWrapped = true,
            LineHeight = 1.15,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 5,
            Parent = words,
        })
    end

    local rail = Craft.frame({
        Token = "raised",
        Size = UDim2.new(1, -24, 0, 2),
        Position = UDim2.new(0, 12, 1, -7),
        Radius = UDim.new(1, 0),
        ZIndex = 4,
        Parent = card,
    })
    local burn = Craft.frame({
        Token = kind,
        Size = UDim2.fromScale(1, 1),
        Radius = UDim.new(1, 0),
        ZIndex = 5,
        Parent = rail,
    })

    local life = opts.Duration or 4
    local dying = false

    -- entrance: fade, glide and settle at once
    Util.tween(card, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Util.ease.glide)
    Util.tween(scale, { Scale = 1 }, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out))

    local countdown = Util.tween(burn, { Size = UDim2.fromScale(0, 1) }, TweenInfo.new(life, Enum.EasingStyle.Linear))

    local function dismiss()
        if dying then
            return
        end
        dying = true
        countdown:Cancel()

        local exit = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Util.tween(card, { GroupTransparency = 1, Position = UDim2.fromOffset(44, 0) }, exit)
        Util.tween(scale, { Scale = 0.94 }, exit)

        -- collapse the footprint so toasts below glide up instead of snapping
        task.delay(0.16, function()
            if card.Parent then
                card.AutomaticSize = Enum.AutomaticSize.None
                Util.tween(
                    card,
                    { Size = UDim2.new(1, 0, 0, 0) },
                    TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                )
            end
        end)
        task.delay(0.42, function()
            card:Destroy()
        end)
    end

    -- hovering holds the toast open, so a long message can actually be read
    local hover = Craft.button({
        Name = "Hit",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
        Parent = card,
    })

    local held = false
    hover.MouseEnter:Connect(function()
        held = true
        countdown:Pause()
        Util.tween(scale, { Scale = 1.02 }, Util.ease.out)
    end)
    hover.MouseLeave:Connect(function()
        held = false
        if not dying then
            countdown:Play()
            Util.tween(scale, { Scale = 1 }, Util.ease.out)
        end
    end)
    hover.MouseButton1Click:Connect(dismiss)

    task.delay(life, function()
        while held and not dying do
            task.wait(0.1)
        end
        dismiss()
    end)

    return card
end

function Notify.panel(anchor)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 246,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 10)
            Util.list(panel, 6)

            Craft.text({
                Text = "Notifications",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })

            if #Notify.history == 0 then
                Craft.text({
                    Text = "Nothing here yet.",
                    Token = "textFaint",
                    TextSize = 11.5,
                    Size = UDim2.new(1, 0, 0, 34),
                    LayoutOrder = 2,
                    ZIndex = 3,
                    Parent = panel,
                })
                return
            end

            local feed = Craft.scroll({
                Size = UDim2.new(1, 0, 0, math.min(#Notify.history * 44, 240)),
                LayoutOrder = 2,
                Parent = panel,
            })
            Util.list(feed, 2)

            for i, entry in ipairs(Notify.history) do
                local row = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 42),
                    LayoutOrder = i,
                    ZIndex = 3,
                    Parent = feed,
                })
                Craft.tile({
                    Icon = entry.Icon,
                    Size = 22,
                    Token = "surfaceAlt",
                    IconToken = entry.Kind,
                    Position = UDim2.new(0, 2, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Title,
                    Token = "text",
                    TextSize = 12,
                    FontFace = Theme.font.semi,
                    Position = UDim2.fromOffset(32, 6),
                    Size = UDim2.new(1, -70, 0, 14),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Text,
                    Token = "textFaint",
                    TextSize = 10.5,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(32, 21),
                    Size = UDim2.new(1, -40, 0, 13),
                    ZIndex = 4,
                    Parent = row,
                })
                Craft.text({
                    Text = entry.Stamp,
                    Token = "textFaint",
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Position = UDim2.fromOffset(0, 6),
                    Size = UDim2.new(1, -2, 0, 14),
                    ZIndex = 4,
                    Parent = row,
                })
            end
        end,
    })
end

return Notify
end

__flowStartupCheckpoint()

end