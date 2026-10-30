return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/card"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Controls = require("ui/controls")
local Audio = require("core/audio")

local Card = {}
Card.__index = Card

function Card.new(tab, opts)
    local self = setmetatable({}, Card)
    self.tab = tab
    self.flow = tab.flow
    self.Name = opts.Name or "Module"
    self.Icon = opts.Icon or "cube"
    self.Flag = opts.Flag
    self.Enabled = opts.Default and true or false
    self.Bind = opts.Keybind
    self.BindMode = opts.BindMode or "Toggle"
    self.Callback = opts.Callback
    self.terms = self.Name:lower()
    self.controls = {}

    local root = Craft.frame({
        -- deliberately unnamed: on an executor without gethui the tree ends up in
        -- PlayerGui, and "Silent Aim" in the hierarchy is a free confession
        Name = "",
        Token = "surface",
        Radius = Theme.radius.card,
        Edge = "lineSoft",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder or 0,
        ClipsDescendants = true,
        Parent = opts.Parent,
    })
    Util.list(root, 0)
    self.Frame = root
    self.edge = root:FindFirstChildWhichIsA("UIStroke")

    local header = Craft.button({
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.card),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(header, 0, 12, 0, 12)
    self.Header = header

    local tile = Craft.tile({
        Icon = self.Icon,
        Size = 26,
        Token = "surfaceAlt",
        IconToken = "accent",
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 4,
        Parent = header,
    })
    self.Tile = tile

    local title = Craft.text({
        Name = "Title",
        Text = self.Name,
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -126, 1, 0),
        ZIndex = 4,
        Parent = header,
    })
    self.Title = title

    local cluster = Craft.frame({
        Name = "Cluster",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        ZIndex = 4,
        Parent = header,
    })
    Util.list(
        cluster,
        6,
        Enum.FillDirection.Horizontal,
        Enum.HorizontalAlignment.Right,
        Enum.VerticalAlignment.Center
    )

    local caretCell = Craft.frame({
        Name = "CaretCell",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Visible = false,
        LayoutOrder = 0,
        ZIndex = 5,
        Parent = cluster,
    })
    self.CaretCell = caretCell
    self.Caret = Icons.draw({ Icon = "chevron-down", Size = 14, Token = "textFaint", ZIndex = 6, Parent = caretCell })

    local bindChip
    bindChip = Controls.keybind(cluster, {
        Default = self.Bind,
        LayoutOrder = 1,
        ZIndex = 5,
        Callback = function(key)
            self.Bind = key
            self.flow:rebind()
        end,
        OnPress = function()
            if self.BindMode == "Toggle" then
                self:Set(not self.Enabled)
            end
        end,
        OnRightClick = function(chip)
            self:BindMenu(chip, bindChip)
        end,
    })
    self.BindControl = bindChip

    local switch = Controls.switch(cluster, {
        Default = self.Enabled,
        LayoutOrder = 3,
        ZIndex = 5,
        Callback = function(v)
            self:Set(v, true)
        end,
    })
    self.Switch = switch

    local clip = Craft.frame({
        Name = "Clip",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 2,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = root,
    })
    self.Clip = clip

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
        Parent = clip,
    })
    Util.list(body, 11)
    Util.pad(body, 0, 12, 12, 12)
    self.Body = body

    self.Expanded = opts.Expanded and true or false

    local function resize(animate)
        local target = self.Expanded and body.AbsoluteSize.Y or 0
        if animate == false then
            clip.Size = UDim2.new(1, 0, 0, target)
        else
            Util.tween(clip, { Size = UDim2.new(1, 0, 0, target) }, Util.ease.glide)
        end
    end
    self.resize = resize

    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if self.Expanded then
            clip.Size = UDim2.new(1, 0, 0, body.AbsoluteSize.Y)
        end
    end)

    header.MouseButton1Click:Connect(function()
        if not self.expandable then
            return
        end
        self:Expand(not self.Expanded)
    end)

    Util.hover(header, self.edge, { Transparency = 0 }, { Transparency = 0.45 })

    self.holdBegan = Util.onInput("began", function(input, typing)
        if typing or self.BindMode ~= "Hold" or not self.Bind then
            return
        end
        if input.KeyCode == self.Bind or input.UserInputType == self.Bind then
            self:Set(true)
        end
    end)

    self.holdEnded = Util.onInput("ended", function(input)
        if self.BindMode ~= "Hold" or not self.Bind then
            return
        end
        if input.KeyCode == self.Bind or input.UserInputType == self.Bind then
            self:Set(false)
        end
    end)

    --[[
        These two are engine-wide handlers, and nothing used to take them back.
        A script that reloads twenty times — which is the whole executor
        workflow — left forty dead cards listening on every key press, each one
        reaching into a destroyed frame.

        Destroying is the right hook rather than an explicit Destroy call: it
        fires however the card dies, including Root:Destroy() on unload.
    ]]
    root.Destroying:Connect(function()
        self.holdBegan()
        self.holdEnded()
        if self.Flag then
            State.release(self.Flag, self)
        end
    end)

    if self.Flag then
        State.register(self.Flag, self)
        State.flags[self.Flag] = self.Enabled
    end

    Theme.watch(function()
        if not root.Parent then
            return false
        end
        self:paint()
    end)

    task.defer(function()
        resize(false)
        self:paint()
        self:refresh()
    end)

    return self
end

-- right-clicking the keybind chip: pick how the key behaves, rebind it, or clear it
function Card:BindMenu(anchor, chip)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 186,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 6)
            Util.list(panel, 2)

            local function row(order, height)
                local button = Overlay.row({ Parent = panel, LayoutOrder = order, Height = height or 32 })
                Util.pad(button, 0, 9, 0, 9)
                return button
            end

            local function label(parent, text, token, size, x)
                return Craft.text({
                    Text = text,
                    Token = token,
                    TextSize = size or 12.5,
                    Position = UDim2.fromOffset(x or 0, 0),
                    Size = UDim2.new(1, -(x or 0), 1, 0),
                    ZIndex = 5,
                    Parent = parent,
                })
            end

            label(
                Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16),
                    LayoutOrder = 1,
                    ZIndex = 3,
                    Parent = panel,
                }),
                "Key behaviour",
                "textFaint",
                11,
                2
            )

            for i, mode in ipairs({ "Toggle", "Hold" }) do
                local button = row(i + 1, 32)
                local live = self.BindMode == mode

                local cell = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(15, 15),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = button,
                })
                Icons.draw({
                    Icon = mode == "Toggle" and "power" or "target",
                    Size = 14,
                    Token = live and "accent" or "textFaint",
                    ZIndex = 5,
                    Parent = cell,
                })

                local text = label(button, mode, live and "text" or "textDim", 12.5, 24)
                text.FontFace = live and Theme.font.semi or Theme.font.medium

                if live then
                    local tick = Craft.frame({
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(14, 14),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        ZIndex = 4,
                        Parent = button,
                    })
                    Icons.draw({ Icon = "check", Size = 13, Token = "accent", ZIndex = 5, Parent = tick })
                end

                button.MouseButton1Click:Connect(function()
                    self.BindMode = mode
                    -- leaving hold mode with the key down would strand the module on
                    if mode == "Toggle" and self.Enabled and self.heldOn then
                        self.heldOn = false
                    end
                    Overlay.close()
                end)
            end

            Craft.divider(panel, 4)

            local rebind = row(5)
            local rebindCell = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                ZIndex = 4,
                Parent = rebind,
            })
            Icons.draw({ Icon = "keyboard", Size = 14, Token = "textFaint", ZIndex = 5, Parent = rebindCell })
            label(rebind, "Rebind key", "textDim", 12.5, 24)
            rebind.MouseButton1Click:Connect(function()
                Overlay.close()
                task.defer(chip.Capture, chip)
            end)

            local clear = row(6)
            local clearCell = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(15, 15),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                ZIndex = 4,
                Parent = clear,
            })
            Icons.draw({ Icon = "close", Size = 13, Token = "danger", ZIndex = 5, Parent = clearCell })
            label(clear, "Clear bind", "danger", 12.5, 24)
            clear.MouseButton1Click:Connect(function()
                chip:Set(nil)
                Overlay.close()
            end)
        end,
    })
end

function Card:paint()
    local glyph = self.Tile:FindFirstChild("Icon")
    if glyph then
        Icons.tint(glyph, self.Enabled and Theme.get("accent") or Theme.get("textFaint"))
    end
    self.Tile.BackgroundColor3 = self.Enabled and Theme.get("accentSoft") or Theme.get("surfaceAlt")
end

function Card:Set(value, fromSwitch)
    self.Enabled = value and true or false
    if not fromSwitch then
        -- the switch only makes noise when clicked, so a keybind toggle speaks here
        self.Switch:Set(self.Enabled, true)
        Audio.play(self.Enabled and "on" or "off")
    end
    if self.Flag then
        State.set(self.Flag, self.Enabled, true)
    end

    local glyph = self.Tile:FindFirstChild("Icon")
    if glyph then
        Icons.tint(glyph, self.Enabled and Theme.get("accent") or Theme.get("textFaint"))
    end
    Util.tween(self.Tile, {
        BackgroundColor3 = self.Enabled and Theme.get("accentSoft") or Theme.get("surfaceAlt"),
    }, Util.ease.snap)

    if self.Callback then
        task.spawn(self.Callback, self.Enabled)
    end
    self.flow:announce(self, self.Enabled)
end

function Card:Expand(open)
    self.Expanded = open and true or false
    self.resize(true)
    Util.tween(self.Caret, { Rotation = self.Expanded and 180 or 0 }, Util.ease.out)
end

-- the chevron is the only hint that a card opens, so it appears the moment the
-- card gains its first control and hides again if it has none
function Card:refresh()
    self.expandable = #self.controls > 0
    self.CaretCell.Visible = self.expandable
    self.Header.AutoButtonColor = false
end

function Card:Match(query)
    if query == "" then
        return true
    end
    return self.terms:find(query, 1, true) ~= nil
end

function Card:Remember(name)
    if name then
        self.terms = self.terms .. " " .. tostring(name):lower()
    end
end

local function order(self)
    self.slot = (self.slot or 0) + 1
    task.defer(function()
        self:refresh()
    end)
    return self.slot
end

function Card:Toggle(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.toggle(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Slider(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.slider(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Segmented(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.segmented(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Icons(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.iconpicker(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Dropdown(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.dropdown(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Buttons(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.buttons(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Button(opts)
    return self:Buttons({ Name = opts.Name, Desc = opts.Desc, Buttons = { opts } })
end

function Card:Color(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.color(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Input(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local c = Controls.input(self.Body, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Keybind(opts)
    opts.LayoutOrder = order(self)
    self:Remember(opts.Name)
    local row = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = opts.LayoutOrder,
        Parent = self.Body,
    })
    local head = Craft.head({ Name = opts.Name, Desc = opts.Desc, Parent = row })
    head.Size = UDim2.new(1, -70, 0, 0)
    opts.Position = UDim2.new(1, 0, 0, 9)
    opts.AnchorPoint = Vector2.new(1, 0.5)
    local c = Controls.keybind(row, opts)
    table.insert(self.controls, c)
    return c
end

function Card:Label(opts)
    opts.LayoutOrder = order(self)
    return Controls.label(self.Body, opts)
end

function Card:Divider()
    return Controls.divider(self.Body, { LayoutOrder = order(self) })
end

return Card
end

__flowStartupCheckpoint()

end