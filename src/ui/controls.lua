return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/controls"] = function(require)
__flowStartupCheckpoint()
local UserInputService = __service("UserInputService")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Audio = require("core/audio")

local Controls = {}

local function shell(parent, opts, free)
    local root = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder or 0,
        ZIndex = 2,
        Parent = parent,
    })
    if not free then
        Util.list(root, opts.Gap or 8)
    end
    return root
end

local function bindFlag(control, opts)
    if opts.Flag then
        State.register(opts.Flag, control)
        State.flags[opts.Flag] = control.Value
    end
end

local function repaint(control, frame)
    Theme.watch(function()
        if not frame.Parent then
            return false
        end
        control:Set(control.Value, true)
    end)
end

local function emit(control, opts, value)
    control.Value = value
    if opts.Flag then
        State.set(opts.Flag, value, true)
    end
    if opts.Callback then
        task.spawn(opts.Callback, value)
    end
end

function Controls.switch(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default and true or false }
    -- the most-pressed control in the library, so it follows the touch density
    local metric = Theme.chrome.switch
    local width = opts.Width or metric.X
    local height = opts.Height or metric.Y

    local track = Craft.button({
        Name = "Switch",
        Token = "raised",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(width, height),
        Position = opts.Position,
        AnchorPoint = opts.AnchorPoint,
        LayoutOrder = opts.LayoutOrder,
        ZIndex = opts.ZIndex or 3,
        Parent = parent,
    })

    local glow = Util.stroke(track, Theme.get("accent"), 1, 1)
    Theme.bind(glow, "Color", "accentGlow")

    local knob = Craft.frame({
        Name = "Knob",
        Token = "textFaint",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(height - 5, height - 5),
        Position = UDim2.new(0, 2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = (opts.ZIndex or 3) + 1,
        Parent = track,
    })

    local span = width - height + 3

    function control:Set(value, silent)
        control.Value = value and true or false
        Util.tween(track, { BackgroundColor3 = control.Value and Theme.get("accent") or Theme.get("raised") })
        Util.tween(knob, {
            Position = UDim2.new(0, control.Value and span or 2, 0.5, 0),
            BackgroundColor3 = control.Value and Theme.get("white") or Theme.get("textFaint"),
        })
        Util.tween(glow, { Transparency = control.Value and 0.55 or 1 })
        if not silent then
            Audio.play(control.Value and "on" or "off")
            emit(control, opts, control.Value)
        end
    end

    track.MouseButton1Click:Connect(function()
        control:Set(not control.Value)
    end)

    control.Frame = track
    control:Set(control.Value, true)
    repaint(control, track)
    bindFlag(control, opts)
    return control
end

function Controls.toggle(parent, opts)
    local control = {}
    local root = shell(parent, opts, true)
    local head = Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    -- clear the switch plus a thumb's worth of gap, whatever density is running
    head.Size = UDim2.new(1, -(Theme.chrome.switch.X + 16), 0, 0)

    local switch = Controls.switch(root, {
        Default = opts.Default,
        Position = UDim2.new(1, 0, 0, 10),
        AnchorPoint = Vector2.new(1, 0.5),
        Callback = function(v)
            emit(control, opts, v)
        end,
    })

    control.Value = switch.Value
    control.Frame = root
    control.Head = head

    function control:Set(value, silent)
        switch:Set(value, true)
        control.Value = switch.Value
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    bindFlag(control, opts)
    return control
end

function Controls.slider(parent, opts)
    opts = opts or {}
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or ((max - min) <= 3 and 0.05 or 1)
    local control = { Value = Util.clamp(opts.Default or min, min, max) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local lane = Craft.frame({
        Name = "Lane",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        LayoutOrder = 2,
        Parent = root,
    })

    local track = Craft.frame({
        Name = "Track",
        Token = "raised",
        Radius = UDim.new(1, 0),
        Size = UDim2.new(1, 0, 0, 7),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 2,
        Parent = lane,
    })

    local ticks = Craft.frame({
        Name = "Ticks",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.fromOffset(7, 0),
        ZIndex = 3,
        Parent = track,
    })
    Util.list(ticks, 0, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
    for i = 1, opts.Ticks or 11 do
        local cell = Craft.frame({
            Name = "Cell",
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / (opts.Ticks or 11), 0, 1, 0),
            LayoutOrder = i,
            ZIndex = 3,
            Parent = ticks,
        })
        Craft.frame({
            Name = "Tick",
            Token = "textFaint",
            Radius = UDim.new(1, 0),
            BackgroundTransparency = 0.35,
            Size = UDim2.fromOffset(3, 3),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 3,
            Parent = cell,
        })
    end

    local fill = Craft.frame({
        Name = "Fill",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromScale(0, 1),
        ZIndex = 4,
        Parent = track,
    })

    local knob = Craft.frame({
        Name = "Knob",
        Token = "white",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 6,
        Parent = lane,
    })
    local knobEdge = Util.stroke(knob, Theme.get("accent"), 2, 0)
    Theme.bind(knobEdge, "Color", "accent")

    local readout = Craft.chip({
        Text = "0",
        Token = "raised",
        TextToken = "text",
        Height = 20,
        ZIndex = 7,
        Parent = lane,
    })
    readout.AnchorPoint = Vector2.new(0.5, 0.5)
    readout.Position = UDim2.new(0, 0, 0.5, -23)
    readout.BackgroundTransparency = 1
    local readoutText = readout:FindFirstChild("Value")
    readoutText.TextTransparency = 1

    local function paint(alpha)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        readout.Position = UDim2.new(alpha, 0, 0.5, -23)
        readoutText.Text = Util.format(control.Value, step) .. (opts.Suffix or "")
    end

    -- one detent per step, pitched up as the value rises, throttled so a long
    -- drag across a 2000-wide range does not machine-gun
    local lastTick = 0
    local function detent()
        local now = os.clock()
        if now - lastTick < 0.035 then
            return
        end
        lastTick = now
        local alpha = (control.Value - min) / math.max(max - min, 1e-6)
        Audio.play("tick", 2.05 + alpha * 0.85)
    end

    local function apply(alpha, silent)
        local raw = min + (max - min) * alpha
        local previous = control.Value
        control.Value = Util.clamp(Util.round(raw, step), min, max)
        paint((control.Value - min) / math.max(max - min, 1e-6))
        if not silent then
            if control.Value ~= previous then
                detent()
            end
            emit(control, opts, control.Value)
        end
    end

    local function reveal(on)
        Util.tween(readout, { BackgroundTransparency = on and 0 or 1 }, Util.ease.snap)
        Util.tween(readoutText, { TextTransparency = on and 0 or 1 }, Util.ease.snap)
        Util.tween(knob, { Size = UDim2.fromOffset(on and 18 or 16, on and 18 or 16) }, Util.ease.snap)
    end

    local hot = false
    lane.MouseEnter:Connect(function()
        hot = true
        reveal(true)
    end)
    lane.MouseLeave:Connect(function()
        hot = false
        task.delay(0.05, function()
            if not hot then
                reveal(false)
            end
        end)
    end)

    Util.slide(lane, function(a)
        apply(a)
        reveal(true)
    end, function()
        if not hot then
            reveal(false)
        end
    end)

    function control:Set(value, silent)
        control.Value = Util.clamp(Util.round(value, step), min, max)
        paint((control.Value - min) / math.max(max - min, 1e-6))
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    control.Frame = root
    apply((control.Value - min) / math.max(max - min, 1e-6), true)
    bindFlag(control, opts)
    return control
end

function Controls.segmented(parent, opts)
    opts = opts or {}
    local list = opts.Options or {}
    local control = { Value = opts.Default or list[1] }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local strip = Craft.frame({
        Name = "Strip",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Size = UDim2.new(1, 0, 0, opts.Height or 38),
        LayoutOrder = 2,
        ClipsDescendants = true,
        Parent = root,
    })
    Util.pad(strip, 3)

    local highlight = Craft.frame({
        Name = "Highlight",
        Token = "accent",
        Radius = 6,
        Size = UDim2.new(1 / math.max(#list, 1), -2, 1, 0),
        ZIndex = 2,
        Parent = strip,
    })

    local cells = {}
    for i, name in ipairs(list) do
        local cell = Craft.button({
            Name = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / #list, 0, 1, 0),
            Position = UDim2.fromScale((i - 1) / #list, 0),
            ZIndex = 3,
            Parent = strip,
        })
        local label = Craft.text({
            Text = name,
            Token = "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.semi,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
            Parent = cell,
        })
        cells[name] = { cell = cell, label = label, index = i }
        cell.MouseButton1Click:Connect(function()
            control:Set(name)
        end)
    end

    function control:Set(value, silent)
        local hit = cells[value]
        if not hit then
            return
        end
        control.Value = value
        Util.tween(highlight, {
            Position = UDim2.new((hit.index - 1) / #list, 1, 0, 0),
        }, Util.ease.out)
        for _, entry in pairs(cells) do
            Util.tween(entry.label, {
                TextColor3 = entry.index == hit.index and Theme.get("white") or Theme.get("textDim"),
            }, Util.ease.snap)
        end
        if not silent then
            Audio.play("select")
            emit(control, opts, value)
        end
    end

    control.Frame = root
    control:Set(control.Value, true)
    repaint(control, root)
    bindFlag(control, opts)
    return control
end

-- a row of round icon buttons; the live one carries an accent ring
function Controls.iconpicker(parent, opts)
    opts = opts or {}

    local list = {}
    for i, entry in ipairs(opts.Options or {}) do
        if typeof(entry) == "string" then
            list[i] = { Icon = entry, Value = entry }
        else
            list[i] = { Icon = entry.Icon, Value = entry.Value or entry.Icon, Name = entry.Name }
        end
    end

    local control = { Value = opts.Default or (list[1] and list[1].Value) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local size = opts.Size or 38
    local row = Craft.frame({
        Name = "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, size),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.list(row, opts.Gap or 8, Enum.FillDirection.Horizontal)

    local cells = {}
    for i, entry in ipairs(list) do
        local button = Craft.button({
            Name = "",
            Token = "surfaceAlt",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(size, size),
            LayoutOrder = i,
            ZIndex = 3,
            Parent = row,
        })
        local ring = Util.stroke(button, Theme.get("accent"), 1.5, 1)
        Theme.bind(ring, "Color", "accent")
        local glyph = Icons.draw({
            Icon = entry.Icon,
            Size = math.floor(size * 0.48),
            Color = Theme.get("textFaint"),
            ZIndex = 4,
            Parent = button,
        })

        cells[i] = { button = button, ring = ring, glyph = glyph, value = entry.Value }
        button.MouseButton1Click:Connect(function()
            control:Set(entry.Value)
        end)
    end

    function control:Set(value, silent)
        control.Value = value
        for _, cell in ipairs(cells) do
            local live = cell.value == value
            Util.tween(cell.ring, { Transparency = live and 0.1 or 1 }, Util.ease.snap)
            Util.tween(cell.button, {
                BackgroundColor3 = live and Theme.get("accentSoft") or Theme.get("surfaceAlt"),
            }, Util.ease.snap)
            Icons.tint(cell.glyph, live and Theme.get("accent") or Theme.get("textFaint"))
        end
        if not silent then
            Audio.play("select")
            emit(control, opts, value)
        end
    end

    control.Frame = root
    control:Set(control.Value, true)
    repaint(control, root)
    bindFlag(control, opts)
    return control
end

-- `options` is the list the caller declared. Reading the selection back in that
-- order keeps the caption agreeing with the rows in the open panel; sorting it
-- alphabetically instead turned { Players, NPCs } into "NPCs, Players" and threw
-- away the priority the caller chose.
local function joinValues(value, empty, options, limit)
    if typeof(value) == "table" then
        local picked = {}
        if type(options) == "table" and #options > 0 then
            for _, option in ipairs(options) do
                if value[option] == true then
                    table.insert(picked, option)
                end
            end
            -- a flag can carry a value that is no longer in Options; still show it
            for k, v in pairs(value) do
                if v == true and not table.find(picked, k) then
                    table.insert(picked, k)
                end
            end
        else
            for k, v in pairs(value) do
                if v == true then
                    table.insert(picked, k)
                end
            end
            table.sort(picked)
        end

        if #picked == 0 then
            return empty or "None"
        end

        -- past a few names the row truncates mid-word, which reads as a glitch;
        -- a count is shorter and says how much is hidden
        limit = limit or 3
        if #picked > limit then
            local head = table.move(picked, 1, limit, 1, {})
            return table.concat(head, ", ") .. " +" .. (#picked - limit)
        end
        return table.concat(picked, ", ")
    end
    return value ~= nil and tostring(value) or (empty or "None")
end

function Controls.dropdown(parent, opts)
    opts = opts or {}
    local list = opts.Options or {}
    local multi = opts.Multi and true or false
    local control = { Value = opts.Default or (multi and {} or list[1]) }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local field = Craft.button({
        Name = "Field",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, opts.Height or 38),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.pad(field, 0, 12, 0, 13)

    local caption = Craft.text({
        Name = "Caption",
        Text = joinValues(control.Value, opts.Empty, list, opts.MaxTags),
        Token = "text",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, -20, 1, 0),
        Parent = field,
    })

    local arrow = Icons.draw({
        Icon = "chevron-down",
        Size = 14,
        Token = "textFaint",
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Parent = field,
    })

    Util.hover(field, field, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })

    local function refresh()
        caption.Text = joinValues(control.Value, opts.Empty, list, opts.MaxTags)
    end

    local function build(panel)
        Util.pad(panel, 6)
        local scroller = Craft.scroll({
            Size = UDim2.new(1, 0, 0, math.min(#list * 36, opts.MaxHeight or 252)),
            Parent = panel,
        })
        Util.list(scroller, 2)

        for i, name in ipairs(list) do
            local row = Overlay.row({ Parent = scroller, LayoutOrder = i, Height = 34 })
            Util.pad(row, 0, 9, 0, 11)

            local label = Craft.text({
                Text = name,
                Token = "textDim",
                TextSize = 13,
                Size = UDim2.new(1, -24, 1, 0),
                ZIndex = 4,
                Parent = row,
            })

            local mark = Icons.draw({
                Icon = multi and "check" or "check",
                Size = 12,
                Token = "accent",
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                ZIndex = 4,
                Parent = row,
            })

            local function sync()
                local on
                if multi then
                    on = control.Value[name] == true
                else
                    on = control.Value == name
                end
                mark.Visible = on
                label.TextColor3 = on and Theme.get("text") or Theme.get("textDim")
                label.FontFace = on and Theme.font.semi or Theme.font.medium
            end

            sync()
            row.MouseButton1Click:Connect(function()
                if multi then
                    local copy = {}
                    for k, v in pairs(control.Value) do
                        copy[k] = v
                    end
                    copy[name] = not copy[name] or nil
                    control:Set(copy)
                    for _, sibling in ipairs(scroller:GetChildren()) do
                        if sibling:IsA("TextButton") then
                            local other = sibling:FindFirstChildWhichIsA("TextLabel")
                            local tick = sibling:FindFirstChild("Icon")
                            if other and tick then
                                local on = control.Value[other.Text] == true
                                tick.Visible = on
                                other.TextColor3 = on and Theme.get("text") or Theme.get("textDim")
                            end
                        end
                    end
                else
                    control:Set(name)
                    Overlay.close()
                end
            end)
        end
    end

    field.MouseButton1Click:Connect(function()
        Overlay.toggle({
            Key = field,
            Anchor = field,
            Width = field.AbsoluteSize.X,
            Build = build,
            OnClose = function()
                Util.tween(arrow, { Rotation = 0 }, Util.ease.snap)
            end,
        })
        Audio.play(Overlay.isOpen(field) and "open" or "close")
        Util.tween(arrow, { Rotation = Overlay.isOpen(field) and 180 or 0 }, Util.ease.snap)
    end)

    function control:Set(value, silent)
        control.Value = value
        refresh()
        if not silent then
            emit(control, opts, value)
        end
    end

    function control:Options(newList)
        list = newList
        if not multi and not table.find(list, control.Value) then
            control:Set(list[1])
        else
            refresh()
        end
    end

    control.Frame = root
    bindFlag(control, opts)
    return control
end

function Controls.buttons(parent, opts)
    opts = opts or {}
    local defs = opts.Buttons or {}
    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local row = Craft.frame({
        Name = "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, opts.Height or 36),
        LayoutOrder = 2,
        Parent = root,
    })
    local gap = 6
    Util.list(row, gap, Enum.FillDirection.Horizontal)

    -- an optional round accent button pinned to the end of the row
    local trail = opts.Trailing
    local trailSize = trail and (opts.Height or 32) or 0
    local reserve = trail and (trailSize + gap) or 0

    local made = {}
    for i, def in ipairs(defs) do
        local n = #defs
        local button = Craft.button({
            Name = def.Name or "Button",
            Token = def.Accent and "accent" or "surfaceAlt",
            Radius = Theme.radius.control,
            Size = UDim2.new(1 / n, -(gap * (n - 1) + reserve) / n, 1, 0),
            LayoutOrder = i,
            Parent = row,
        })

        local inner = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = button,
        })
        Util.list(
            inner,
            6,
            Enum.FillDirection.Horizontal,
            Enum.HorizontalAlignment.Center,
            Enum.VerticalAlignment.Center
        )

        if def.Icon then
            local holder = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                LayoutOrder = 1,
                Parent = inner,
            })
            Icons.draw({
                Icon = def.Icon,
                Size = 15,
                Token = def.Accent and "white" or "textFaint",
                Parent = holder,
            })
        end

        Craft.text({
            Text = def.Name or "",
            Token = def.Accent and "white" or "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 2,
            Parent = inner,
        })

        if not def.Accent then
            Util.hover(button, button, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })
        end

        button.MouseButton1Click:Connect(function()
            Util.tween(button, { BackgroundColor3 = Theme.get("raisedHi") }, Util.ease.snap)
            task.delay(0.1, function()
                Util.tween(button, {
                    BackgroundColor3 = def.Accent and Theme.get("accent") or Theme.get("surfaceAlt"),
                }, Util.ease.snap)
            end)
            Audio.play("click")
            if def.Callback then
                task.spawn(def.Callback)
            end
        end)

        table.insert(made, button)
    end

    if trail then
        local knob = Craft.button({
            Name = "Trailing",
            Token = trail.Accent == false and "surfaceAlt" or "accent",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(trailSize, trailSize),
            LayoutOrder = #defs + 1,
            Parent = row,
        })
        Icons.draw({
            Icon = trail.Icon or "plus",
            Size = math.floor(trailSize * 0.42),
            Color = trail.Accent == false and Theme.get("textFaint") or Theme.get("white"),
            Parent = knob,
        })
        knob.MouseButton1Click:Connect(function()
            if trail.Callback then
                task.spawn(trail.Callback)
            end
        end)
        made.Trailing = knob
    end

    return { Frame = root, Buttons = made }
end

function Controls.input(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default or "" }
    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local field = Craft.frame({
        Name = "Field",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, opts.Height or 34),
        LayoutOrder = 2,
        ClipsDescendants = true,
        Parent = root,
    })
    Util.pad(field, 0, 11, 0, 11)

    local box = Util.new("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = control.Value,
        PlaceholderText = opts.Placeholder or "",
        FontFace = Theme.font.medium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 3,
        Parent = field,
    })
    Theme.bind(box, "TextColor3", "text")
    Theme.bind(box, "PlaceholderColor3", "textFaint")

    local edge = field:FindFirstChildWhichIsA("UIStroke")
    box.Focused:Connect(function()
        Util.tween(edge, { Color = Theme.get("accent"), Transparency = 0.2 }, Util.ease.snap)
    end)
    box.FocusLost:Connect(function(enter)
        Util.tween(edge, { Color = Theme.get("lineSoft"), Transparency = 0 }, Util.ease.snap)
        control.Value = box.Text
        if opts.Flag then
            State.flags[opts.Flag] = box.Text
        end
        if opts.Callback and (enter or not opts.OnEnter) then
            task.spawn(opts.Callback, box.Text, enter)
        end
    end)

    function control:Set(value, silent)
        control.Value = tostring(value or "")
        box.Text = control.Value
        if not silent then
            emit(control, opts, control.Value)
        end
    end

    control.Frame = root
    control.Box = box
    bindFlag(control, opts)
    return control
end

function Controls.keybind(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default }
    local capturing = false

    --[[
        Drawn as a key cap rather than a text pill: a hairline edge so it reads
        as a physical key against the card, and padding that widens for a single
        character so "B" is a square cap instead of a sliver next to "MB3".

        The padding is what sets the width, not a UISizeConstraint. A minimum
        width leaves the label parked against the left inset with the whole
        remainder banked up on the right, which is exactly the lopsided cap this
        replaces.
    ]]
    local holder = Craft.button({
        Name = "Keybind",
        Token = "raised",
        Radius = Theme.radius.tile,
        Edge = "line",
        Size = UDim2.fromOffset(0, opts.Height or 22),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = opts.Position,
        AnchorPoint = opts.AnchorPoint,
        LayoutOrder = opts.LayoutOrder,
        ZIndex = opts.ZIndex or 3,
        Parent = parent,
    })
    local inset = Util.pad(holder, 0, 8, 0, 8)

    local label = Craft.text({
        Name = "Value",
        Text = Util.keyName(control.Value),
        Token = "textDim",
        TextSize = 11.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = (opts.ZIndex or 3) + 2,
        Parent = holder,
    })

    Util.hover(holder, holder, { BackgroundColor3 = Theme.get("raised") }, { BackgroundColor3 = Theme.get("raisedHi") })

    function control:Set(key, silent)
        control.Value = key
        label.Text = Util.keyName(key)
        label.TextColor3 = key and Theme.get("text") or Theme.get("textFaint")

        -- a lone letter gets a wider inset on both sides, so the cap is square
        -- rather than a sliver, and the glyph stays centred either way
        local wide = utf8.len(label.Text) == 1 and 11 or 8
        inset.PaddingLeft = UDim.new(0, wide)
        inset.PaddingRight = UDim.new(0, wide)

        -- an unbound chip carried the same fill as a bound one, so a row of them
        -- read as "MB3, V, None, B" all at equal weight; empty ones now recede
        holder.BackgroundTransparency = key and 0 or 0.6
        local edge = holder:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Transparency = key and 0 or 0.65
        end
        if not silent then
            emit(control, opts, key)
        end
    end

    function control:Capture()
        if capturing then
            return
        end
        capturing = true
        label.Text = "..."
        label.TextColor3 = Theme.get("accent")
        -- waiting for a key is an active state even from an empty chip
        holder.BackgroundTransparency = 0
        local edge = holder:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Transparency = 0
        end
    end

    holder.MouseButton1Click:Connect(function()
        control:Capture()
    end)

    -- right click clears the bind unless the caller wants its own menu there
    holder.MouseButton2Click:Connect(function()
        local wasCapturing = capturing
        capturing = false
        if opts.OnRightClick then
            -- the chip is left mid-capture otherwise: still reading "..." with no
            -- listener behind it, since the menu takes over from here
            if wasCapturing then
                control:Set(control.Value, true)
            end
            opts.OnRightClick(holder, control)
        else
            control:Set(nil)
        end
    end)

    control.Listener = Util.onInput("began", function(input, typing)
        if typing then
            return
        end
        if capturing then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                capturing = false
                control:Set(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                capturing = false
                control:Set(Enum.UserInputType.MouseButton3)
            end
            return
        end
        if not control.Value or not opts.OnPress then
            return
        end
        if input.KeyCode == control.Value or input.UserInputType == control.Value then
            opts.OnPress()
        end
    end)

    holder.Destroying:Connect(function()
        control.Listener()
    end)

    control.Frame = holder
    control:Set(control.Value, true)
    repaint(control, holder)
    bindFlag(control, opts)
    return control
end

local function hsvFrom(color)
    local h, s, v = Color3.toHSV(color)
    return h, s, v
end

function Controls.color(parent, opts)
    opts = opts or {}
    local control = { Value = opts.Default or Theme.get("accent") }
    local presets = opts.Presets
        or {
            Color3.fromRGB(124, 92, 255),
            Color3.fromRGB(92, 150, 255),
            Color3.fromRGB(70, 205, 190),
            Color3.fromRGB(80, 205, 137),
            Color3.fromRGB(240, 178, 78),
            Color3.fromRGB(238, 92, 100),
        }

    local root = shell(parent, opts)
    if opts.Name then
        Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    end

    local row = Craft.frame({
        Name = "Swatches",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 21),
        LayoutOrder = 2,
        Parent = root,
    })
    Util.list(row, 9, Enum.FillDirection.Horizontal)

    local custom = Craft.button({
        Name = "Custom",
        Token = "white",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(21, 21),
        LayoutOrder = 0,
        Parent = row,
    })
    Craft.gradient(
        custom,
        Color3.fromRGB(255, 90, 90),
        Color3.fromRGB(120, 90, 255),
        0
    ).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 84, 84)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 205, 76)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(88, 226, 124)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(76, 214, 226)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(124, 92, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 92, 214)),
    })

    local dots = {}
    for i, preset in ipairs(presets) do
        local dot = Craft.button({
            Name = "Swatch",
            Radius = UDim.new(1, 0),
            BackgroundColor3 = preset,
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(17, 17),
            LayoutOrder = i,
            Parent = row,
        })
        local ring = Util.stroke(dot, Theme.get("white"), 2, 1)
        dots[i] = { dot = dot, ring = ring, color = preset }
        dot.MouseButton1Click:Connect(function()
            control:Set(preset)
        end)
    end

    local function markSelection()
        for _, entry in ipairs(dots) do
            local same = math.abs(entry.color.R - control.Value.R) < 0.01
                and math.abs(entry.color.G - control.Value.G) < 0.01
                and math.abs(entry.color.B - control.Value.B) < 0.01
            Util.tween(entry.ring, { Transparency = same and 0.15 or 1 }, Util.ease.snap)
            Util.tween(entry.dot, { Size = UDim2.fromOffset(same and 19 or 17, same and 19 or 17) }, Util.ease.snap)
        end
        Util.tween(custom, { Size = UDim2.fromOffset(21, 21) }, Util.ease.snap)
    end

    local function picker(panel)
        Util.pad(panel, 10)
        Util.list(panel, 9)

        local h, s, v = hsvFrom(control.Value)

        local field = Craft.frame({
            Name = "Field",
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            Radius = 8,
            Size = UDim2.new(1, 0, 0, 132),
            LayoutOrder = 1,
            ZIndex = 3,
            Parent = panel,
        })

        local sat = Craft.frame({
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Radius = 8,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 4,
            Parent = field,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = sat,
        })

        local val = Craft.frame({
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            Radius = 8,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 5,
            Parent = field,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Parent = val,
        })

        local cursor = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Radius = UDim.new(1, 0),
            ZIndex = 7,
            Parent = field,
        })
        Util.stroke(cursor, Color3.fromRGB(255, 255, 255), 2, 0)

        local hueBar = Craft.frame({
            Radius = UDim.new(1, 0),
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            LayoutOrder = 2,
            ZIndex = 3,
            Parent = panel,
        })
        Util.new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
            Parent = hueBar,
        })

        local hueKnob = Craft.frame({
            Token = "white",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(h, 0, 0.5, 0),
            ZIndex = 5,
            Parent = hueBar,
        })
        Util.stroke(hueKnob, Theme.get("line"), 2, 0.4)

        local footer = Craft.frame({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = 3,
            ZIndex = 3,
            Parent = panel,
        })

        local preview = Craft.frame({
            BackgroundColor3 = control.Value,
            Radius = 7,
            Size = UDim2.fromOffset(30, 30),
            ZIndex = 4,
            Parent = footer,
        })

        local hexBox = Craft.frame({
            Token = "surfaceAlt",
            Radius = 7,
            Size = UDim2.new(1, -38, 1, 0),
            Position = UDim2.fromOffset(38, 0),
            ZIndex = 4,
            Parent = footer,
        })
        Util.pad(hexBox, 0, 9, 0, 9)
        local hex = Util.new("TextBox", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            FontFace = Theme.font.semi,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Text = "#" .. control.Value:ToHex():upper(),
            ZIndex = 5,
            Parent = hexBox,
        })
        Theme.bind(hex, "TextColor3", "text")

        local function push(silent)
            local color = Color3.fromHSV(h, s, v)
            field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.fromScale(s, 1 - v)
            hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
            preview.BackgroundColor3 = color
            hex.Text = "#" .. color:ToHex():upper()
            control:Set(color, silent)
        end

        push(true)

        field.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                return
            end
            s = Util.clamp((input.Position.X - field.AbsolutePosition.X) / math.max(field.AbsoluteSize.X, 1), 0, 1)
            v = 1 - Util.clamp((input.Position.Y - field.AbsolutePosition.Y) / math.max(field.AbsoluteSize.Y, 1), 0, 1)
            push()
        end)

        field.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            s = Util.clamp((input.Position.X - field.AbsolutePosition.X) / math.max(field.AbsoluteSize.X, 1), 0, 1)
            v = 1 - Util.clamp((input.Position.Y - field.AbsolutePosition.Y) / math.max(field.AbsoluteSize.Y, 1), 0, 1)
            push()
        end)

        Util.slide(hueBar, function(a)
            h = a
            push()
        end)

        hex.FocusLost:Connect(function()
            local ok, color = pcall(Color3.fromHex, (hex.Text:gsub("#", "")))
            if ok and color then
                h, s, v = hsvFrom(color)
                push()
            else
                hex.Text = "#" .. control.Value:ToHex():upper()
            end
        end)
    end

    custom.MouseButton1Click:Connect(function()
        Overlay.toggle({ Key = custom, Anchor = custom, Width = 224, Build = picker, Align = "left" })
    end)

    function control:Set(value, silent)
        if typeof(value) ~= "Color3" then
            return
        end
        control.Value = value
        markSelection()
        if not silent then
            emit(control, opts, value)
        end
    end

    control.Frame = root
    markSelection()
    Theme.watch(function()
        if not root.Parent then
            return false
        end
        markSelection()
    end)
    bindFlag(control, opts)
    return control
end

function Controls.label(parent, opts)
    local root = shell(parent, opts)
    Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = root })
    return { Frame = root }
end

function Controls.divider(parent, opts)
    local root = Craft.frame({
        Name = "Divider",
        Token = "lineSoft",
        Size = UDim2.new(1, 0, 0, 1),
        LayoutOrder = (opts and opts.LayoutOrder) or 0,
        Parent = parent,
    })
    return { Frame = root }
end

return Controls
end

__flowStartupCheckpoint()

end