return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/item"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Audio = require("core/audio")
local ContentProvider = __service("ContentProvider")

--[[
    Item cards: the "shop tile" — a picture, a name, a line of text, a price and
    a button. Built for game menus (killers, perks, skins, loadouts, shops) where
    a toggle row is the wrong shape for the thing being picked.

        local shelf = tab:Shelf({ Name = "Killers", Icon = "skull", Columns = 3, Single = true })
        shelf:Item({
            Name = "The Trapper",
            Desc = "Sets bear traps around the map.",
            Image = "rbxassetid://123",   -- optional, falls back to Flow.DefaultImage
            Tag = "Killer",
            Rarity = "epic",
            Price = 1500,
            Callback = function(item) print(item.Name, item.Selected) end,
        })

    Two pieces:
      Item   one card. Usable on its own through tab:Item(), or inside a shelf.
      Shelf  a titled panel holding a responsive grid of Items.
]]

local rgb = Color3.fromRGB

local Item = {}
Item.__index = Item

-- shown whenever a card has no Image (or its Image fails to load)
Item.DefaultImage = "rbxassetid://73763240772265"
Item.Discord = "https://discord.gg/G7FCTC2mEk"

-- Rarity names resolve to a colour. Add your own: Flow.Item.Rarities.cursed = Color3...
Item.Rarities = {
    common = rgb(150, 147, 166),
    uncommon = rgb(72, 205, 141),
    rare = rgb(74, 144, 255),
    epic = rgb(168, 85, 247),
    legendary = rgb(240, 178, 78),
    mythic = rgb(238, 92, 100),
}

local function unit(self)
    local flow = self.flow
    local scale = flow and flow.scale and flow.scale.Scale or 1
    return math.max(scale, 0.01)
end

local function imageOf(image)
    if image == nil or image == "" then
        return nil
    end
    if type(image) == "number" then
        return "rbxassetid://" .. tostring(math.floor(image))
    end
    if type(image) == "string" and image:match("^%d+$") then
        return "rbxassetid://" .. image
    end
    return image
end

local function money(value)
    if type(value) ~= "number" then
        return tostring(value)
    end
    if value == 0 then
        return "Free"
    end
    if value ~= math.floor(value) then
        return tostring(value)
    end
    local text = tostring(value)
    local n
    repeat
        text, n = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until n == 0
    return text
end

function Item.new(opts, shelf, flow)
    local self = setmetatable({}, Item)
    self.shelf = shelf
    self.flow = flow or (shelf and shelf.flow)

    self.Name = opts.Name or "Item"
    self.Desc = opts.Desc
    self.Tag = opts.Tag
    self.Badge = opts.Badge
    self.Tags = opts.Tags
    self.Price = opts.Price
    self.Currency = opts.Currency or "coin"
    self.Locked = opts.Locked and true or false
    self.Flag = opts.Flag
    self.Callback = opts.Callback
    self.OnLocked = opts.OnLocked
    self.Action = opts.Action
    self.ActionOn = opts.ActionOn
    self.Icon = opts.Icon
    self.Ratio = opts.Ratio or 1.4
    self.Selected = opts.Default and true or false
    self.Selectable = (opts.Selectable or opts.Flag ~= nil or opts.Default ~= nil) and true or false
    -- a Single shelf is a picker: every card in it is selectable unless it opts out
    if shelf and shelf.Single and opts.Selectable ~= false then
        self.Selectable = true
    end

    if typeof(opts.Rarity) == "Color3" then
        self.Color = opts.Rarity
    else
        self.Rarity = opts.Rarity
        self.Color = opts.Color
    end

    local inShelf = shelf ~= nil
    local root = Craft.frame({
        -- unnamed on purpose, same reason as module cards
        Name = "",
        Token = inShelf and "surfaceAlt" or "surface",
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

    ----------------------------------------------------------------------------
    -- thumbnail
    ----------------------------------------------------------------------------

    local thumb = Craft.button({
        Name = "Thumb",
        Token = inShelf and "raised" or "surfaceAlt",
        Size = UDim2.new(1, 0, 0, 100),
        LayoutOrder = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = root,
    })
    self.Thumb = thumb

    -- height follows width. UIAspectRatioConstraint refuses to size itself
    -- inside an automatically sized parent, so the ratio is applied by hand,
    -- in unscaled units so a UIScale on the window does not skew it
    local function fit()
        local width = root.AbsoluteSize.X
        if width <= 0 then
            return
        end
        local height = math.floor(width / unit(self) / self.Ratio + 0.5)
        if math.abs(thumb.Size.Y.Offset - height) >= 1 then
            thumb.Size = UDim2.new(1, 0, 0, height)
        end
    end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    task.defer(fit)

    local image = Util.new("ImageLabel", {
        Name = "Image",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 3,
        Parent = thumb,
    })
    self.Image = image

    local glyph = Util.new("Frame", {
        Name = "Glyph",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
        Visible = false,
        Parent = thumb,
    })
    self.GlyphHolder = glyph

    -- rarity stripe along the foot of the picture
    self.Stripe = Craft.frame({
        Name = "Stripe",
        BackgroundColor3 = Theme.get("accent"),
        Size = UDim2.new(1, 0, 0, 3),
        Position = UDim2.new(0, 0, 1, -3),
        ZIndex = 5,
        Visible = false,
        Parent = thumb,
    })

    local tag = Craft.chip({ Text = "", Token = "surface", TextToken = "textDim", Height = 20, TextSize = 11, ZIndex = 6, Parent = thumb })
    tag.Position = UDim2.fromOffset(8, 8)
    tag.BackgroundTransparency = 0.12
    self.TagChip = tag
    self.TagLabel = tag:FindFirstChild("Value")

    local badge = Craft.chip({ Text = "", Token = "accent", TextToken = "white", Height = 20, TextSize = 11, ZIndex = 6, Parent = thumb })
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, -8, 0, 8)
    self.BadgeChip = badge
    self.BadgeLabel = badge:FindFirstChild("Value")

    local mark = Craft.frame({
        Name = "Picked",
        Token = "accent",
        Radius = 11,
        Size = UDim2.fromOffset(22, 22),
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -8, 1, -10),
        ZIndex = 6,
        Visible = false,
        Parent = thumb,
    })
    Icons.draw({ Icon = "check", Size = 13, Token = "white", ZIndex = 7, Parent = mark })
    self.Mark = mark

    local veil = Craft.frame({
        Name = "Veil",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 8,
        Visible = false,
        Parent = thumb,
    })
    Icons.draw({ Icon = "lock", Size = 22, Color = Theme.get("white"), ZIndex = 9, Parent = veil })
    self.Veil = veil

    ----------------------------------------------------------------------------
    -- text, tags and footer
    ----------------------------------------------------------------------------

    local info = Craft.button({
        Name = "Info",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        ZIndex = 2,
        Parent = root,
    })
    Util.list(info, 5)
    Util.pad(info, 10, 10, 10, 10)
    self.Info = info

    self.Title = Craft.text({
        Name = "Title",
        Text = self.Name,
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, 17),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = info,
    })

    self.RarityText = Craft.text({
        Name = "Rarity",
        Text = "",
        TextColor3 = Theme.get("accent"),
        TextSize = 11,
        FontFace = Theme.font.semi,
        Size = UDim2.new(1, 0, 0, 13),
        LayoutOrder = 2,
        ZIndex = 4,
        Visible = false,
        Parent = info,
    })

    self.DescText = Craft.text({
        Name = "Desc",
        Text = "",
        Token = "textFaint",
        TextSize = 12,
        FontFace = Theme.font.regular,
        TextWrapped = true,
        LineHeight = 1.15,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,
        ZIndex = 4,
        Visible = false,
        Parent = info,
    })

    local tags = Craft.frame({
        Name = "Tags",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 4,
        ZIndex = 3,
        Visible = false,
        Parent = info,
    })
    local tagList = Util.list(tags, 4, Enum.FillDirection.Horizontal)
    tagList.Wraps = true
    self.TagsRow = tags

    local foot = Craft.frame({
        Name = "Foot",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        LayoutOrder = 5,
        ZIndex = 3,
        Parent = info,
    })
    self.Foot = foot

    local price = Craft.frame({
        Name = "Price",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
        Parent = foot,
    })
    Util.list(price, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.PriceRow = price

    self.CoinHolder = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15, 15),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = price,
    })
    self.PriceText = Craft.text({
        Name = "Value",
        Text = "",
        Token = "text",
        TextSize = 12.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = price,
    })

    local action = Craft.button({
        Name = "Action",
        Token = "accent",
        Radius = Theme.radius.control,
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        ZIndex = 5,
        Parent = foot,
    })
    Util.pad(action, 0, 11, 0, 11)
    self.ActionButton = action
    self.ActionLabel = Craft.text({
        Name = "Label",
        Text = "",
        Token = "white",
        TextSize = 12,
        FontFace = Theme.font.semi,
        TextXAlignment = Enum.TextXAlignment.Center,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 6,
        Parent = action,
    })

    ----------------------------------------------------------------------------
    -- input
    ----------------------------------------------------------------------------

    for _, surface in ipairs({ thumb, info }) do
        surface.MouseButton1Click:Connect(function()
            self:Press()
        end)
        surface.MouseEnter:Connect(function()
            self.hot = true
            self:paint()
        end)
        surface.MouseLeave:Connect(function()
            self.hot = false
            self:paint()
        end)
    end
    action.MouseButton1Click:Connect(function()
        self:Press()
    end)

    root.Destroying:Connect(function()
        if self.Flag then
            State.release(self.Flag, self)
        end
    end)

    if self.Flag then
        State.register(self.Flag, self)
        State.flags[self.Flag] = self.Selected
    end

    Theme.watch(function()
        if not root.Parent then
            return false
        end
        self:refresh()
    end)

    self:SetImage(opts.Image)
    self:refresh()

    return self
end

-- the colour the card is "worth", if it has one
function Item:tone()
    if typeof(self.Color) == "Color3" then
        return self.Color
    end
    if type(self.Rarity) == "string" then
        return Item.Rarities[self.Rarity:lower()]
    end
    return nil
end

function Item:actionText()
    if self.Locked then
        return "Locked"
    end
    if self.Selectable then
        if self.Selected then
            return self.ActionOn or "Selected"
        end
        return self.Action or "Select"
    end
    return self.Action or (self.Price ~= nil and "Buy" or "Use")
end

-- state -> pixels, in one place, so a setter only has to change a field and call this
function Item:refresh()
    local tone = self:tone()

    self.Title.Text = tostring(self.Name)

    local desc = self.Desc and tostring(self.Desc) or ""
    self.DescText.Text = desc
    self.DescText.Visible = desc ~= ""

    local rarity = type(self.Rarity) == "string" and self.Rarity or ""
    self.RarityText.Text = rarity:upper()
    self.RarityText.Visible = rarity ~= ""
    if tone then
        self.RarityText.TextColor3 = tone
    end

    self.Stripe.Visible = tone ~= nil
    if tone then
        self.Stripe.BackgroundColor3 = tone
    end

    local tag = self.Tag and tostring(self.Tag) or ""
    self.TagLabel.Text = tag
    self.TagChip.Visible = tag ~= ""

    local badge = self.Badge and tostring(self.Badge) or ""
    self.BadgeLabel.Text = badge
    self.BadgeChip.Visible = badge ~= "" and not self.Selected

    -- tag chips under the description
    for _, child in ipairs(self.TagsRow:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local count = 0
    if type(self.Tags) == "table" then
        for i, text in ipairs(self.Tags) do
            count = count + 1
            Craft.chip({
                Text = tostring(text),
                Token = "raised",
                TextToken = "textDim",
                Height = 20,
                TextSize = 11,
                LayoutOrder = i,
                ZIndex = 4,
                Parent = self.TagsRow,
            })
        end
    end
    self.TagsRow.Visible = count > 0

    -- price + button
    local hasPrice = self.Price ~= nil
    self.PriceRow.Visible = hasPrice
    if hasPrice then
        self.PriceText.Text = money(self.Price)
        for _, child in ipairs(self.CoinHolder:GetChildren()) do
            child:Destroy()
        end
        if self.Currency and self.Currency ~= false and self.Price ~= 0 then
            Icons.draw({ Icon = self.Currency, Size = 14, Token = "warning", ZIndex = 5, Parent = self.CoinHolder })
            self.CoinHolder.Visible = true
        else
            self.CoinHolder.Visible = false
        end
    end

    local showAction = self.Action ~= false and (self.Selectable or self.Callback ~= nil or self.Locked or hasPrice)
    self.ActionButton.Visible = showAction
    self.Foot.Visible = hasPrice or showAction
    if showAction then
        self.ActionLabel.Text = self:actionText()
    end

    self.Veil.Visible = self.Locked
    self.Mark.Visible = self.Selected and not self.Locked

    self:paint()
end

-- colours that depend on state; hover only nudges the edge and the picture
function Item:paint()
    local hot = self.hot and not self.Locked
    Theme.rebind(self.edge, "Color", self.Selected and "accent" or (hot and "line" or "lineSoft"))
    Util.tween(self.edge, { Transparency = (self.Selected or hot) and 0 or 0.3 }, Util.ease.snap)

    local grow = hot and 1.06 or 1
    Util.tween(self.Image, { Size = UDim2.fromScale(grow, grow) }, Util.ease.out)

    if self.Locked then
        Theme.rebind(self.ActionButton, "BackgroundColor3", "raised")
        Theme.rebind(self.ActionLabel, "TextColor3", "textFaint")
    elseif self.Selectable and self.Selected then
        Theme.rebind(self.ActionButton, "BackgroundColor3", "accentSoft")
        Theme.rebind(self.ActionLabel, "TextColor3", "accent")
    else
        Theme.rebind(self.ActionButton, "BackgroundColor3", "accent")
        Theme.rebind(self.ActionLabel, "TextColor3", "white")
    end
end

function Item:Press()
    if self.Locked then
        Audio.play("off")
        if self.OnLocked then
            task.spawn(self.OnLocked, self)
        end
        return
    end

    if self.Selectable then
        if self.shelf and self.shelf.Single then
            -- radio behaviour: clicking the picked one again keeps it picked
            if not self.Selected then
                self:Set(true)
            end
        else
            self:Set(not self.Selected)
        end
        return
    end

    Audio.play("click")
    if self.Callback then
        task.spawn(self.Callback, self)
    end
end

function Item:Set(value, silent)
    value = value and true or false
    self.Selected = value

    if self.Flag then
        State.set(self.Flag, value, true)
    end

    if value and self.shelf and self.shelf.Single then
        for _, other in ipairs(self.shelf.items) do
            if other ~= self and other.Selected then
                other:Set(false, silent)
            end
        end
    end

    self:refresh()

    if not silent then
        Audio.play(value and "on" or "off")
        if self.Callback then
            task.spawn(self.Callback, self)
        end
    end
end

function Item:Get()
    return self.Selected
end

local function loadImage(self, asset)
    local image = self.Image
    image.Image = asset
    if asset == Item.DefaultImage then
        return
    end
    -- a missing or moderated id draws nothing and leaves a hole in the grid
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ image })
        end)
        if image.Parent and image.Image == asset and not image.IsLoaded then
            image.Image = Item.DefaultImage
        end
    end)
end

function Item:SetImage(image)
    local asset = imageOf(image)
    if asset then
        self.GlyphHolder.Visible = false
        self.Image.Visible = true
        loadImage(self, asset)
    elseif self.Icon then
        self.Image.Visible = false
        self.GlyphHolder.Visible = true
        for _, child in ipairs(self.GlyphHolder:GetChildren()) do
            child:Destroy()
        end
        Icons.draw({ Icon = self.Icon, Size = 40, Token = "accent", ZIndex = 4, Parent = self.GlyphHolder })
    else
        self.GlyphHolder.Visible = false
        self.Image.Visible = true
        self.Image.Image = Item.DefaultImage
    end
    return self
end

function Item:SetName(text)
    self.Name = text
    self:refresh()
    return self
end

function Item:SetDesc(text)
    self.Desc = text
    self:refresh()
    return self
end

function Item:SetPrice(price, currency)
    self.Price = price
    if currency ~= nil then
        self.Currency = currency
    end
    self:refresh()
    return self
end

function Item:SetLocked(value)
    self.Locked = value and true or false
    self:refresh()
    return self
end

function Item:SetBadge(text)
    self.Badge = text
    self:refresh()
    return self
end

function Item:SetTag(text)
    self.Tag = text
    self:refresh()
    return self
end

function Item:SetRarity(rarity)
    if typeof(rarity) == "Color3" then
        self.Color, self.Rarity = rarity, nil
    else
        self.Rarity, self.Color = rarity, nil
    end
    self:refresh()
    return self
end

function Item:SetAction(text, selectedText)
    self.Action = text
    if selectedText ~= nil then
        self.ActionOn = selectedText
    end
    self:refresh()
    return self
end

function Item:Match(query)
    if query == "" then
        return true
    end
    local parts = { tostring(self.Name), tostring(self.Desc or ""), tostring(self.Tag or ""), tostring(self.Rarity or "") }
    if type(self.Tags) == "table" then
        for _, text in ipairs(self.Tags) do
            table.insert(parts, tostring(text))
        end
    end
    return table.concat(parts, " "):lower():find(query, 1, true) ~= nil
end

function Item:Destroy()
    local shelf = self.shelf
    if shelf then
        for i, item in ipairs(shelf.items) do
            if item == self then
                table.remove(shelf.items, i)
                break
            end
        end
    end
    self.Frame:Destroy()
    if shelf then
        shelf:Layout(true)
        shelf:Count()
    end
end

--------------------------------------------------------------------------------
-- Shelf
--------------------------------------------------------------------------------

local Shelf = {}
Shelf.__index = Shelf

function Shelf.new(tab, opts)
    local self = setmetatable({}, Shelf)
    self.tab = tab
    self.flow = tab.flow
    self.Name = opts.Name or "Shop"
    self.Icon = opts.Icon or "cube"
    self.Max = math.max(math.floor(opts.Columns or 3), 1)
    self.MinWidth = opts.MinWidth or 148
    self.Single = opts.Single and true or false
    -- a shelf wants the whole width; Tab:Balance reads this to stack shelves in one lane
    self.Full = opts.Full ~= false
    self.gap = opts.Gap or 8
    self.count = self.Max
    self.items = {}

    local root = Craft.frame({
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

    local header = Craft.frame({
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.card),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(header, 0, 12, 0, 12)

    Craft.tile({
        Icon = self.Icon,
        Size = 26,
        Token = "accentSoft",
        IconToken = "accent",
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 4,
        Parent = header,
    })

    self.Title = Craft.text({
        Name = "Title",
        Text = self.Name,
        Token = "text",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -80, 1, 0),
        ZIndex = 4,
        Parent = header,
    })

    local chip, label = Craft.chip({ Text = "0", Token = "surfaceAlt", TextToken = "textDim", Height = 22, ZIndex = 4, Parent = header })
    chip.AnchorPoint = Vector2.new(1, 0.5)
    chip.Position = UDim2.new(1, 0, 0.5, 0)
    self.CountLabel = label

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        ZIndex = 2,
        Parent = root,
    })
    Util.list(body, 10)
    Util.pad(body, 0, 12, 12, 12)

    if opts.Desc and opts.Desc ~= "" then
        Craft.text({
            Name = "Desc",
            Text = opts.Desc,
            Token = "textFaint",
            TextSize = 12,
            FontFace = Theme.font.regular,
            TextWrapped = true,
            LineHeight = 1.15,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 3,
            Parent = body,
        })
    end

    local grid = Craft.frame({
        Name = "Grid",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        ZIndex = 2,
        Parent = body,
    })
    Util.list(grid, self.gap, Enum.FillDirection.Horizontal)
    self.Grid = grid

    self.lanes = {}
    for i = 1, self.Max do
        local lane = Craft.frame({
            Name = "Lane" .. i,
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / self.Max, -self.gap * (self.Max - 1) / self.Max, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = i,
            Parent = grid,
        })
        Util.list(lane, self.gap)
        self.lanes[i] = lane
    end

    -- the shelf folds to fewer columns when the window is narrow
    grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:Layout()
    end)
    task.defer(function()
        self:Layout()
    end)

    return self
end

function Shelf:Layout(force)
    local count = self.Max
    local width = self.Grid.AbsoluteSize.X / unit(self)
    if width > 0 then
        count = Util.clamp(math.floor((width + self.gap) / (self.MinWidth + self.gap)), 1, self.Max)
    end
    if count == self.count and not force then
        return
    end
    self.count = count
    for i, lane in ipairs(self.lanes) do
        lane.Visible = i <= count
        lane.Size = UDim2.new(1 / count, -self.gap * (count - 1) / count, 0, 0)
    end
    for i, item in ipairs(self.items) do
        item.Frame.LayoutOrder = i
        local lane = self.lanes[(i - 1) % count + 1]
        if item.Frame.Parent ~= lane then
            item.Frame.Parent = lane
        end
    end
end

function Shelf:Count()
    self.CountLabel.Text = tostring(#self.items)
end

function Shelf:Item(opts)
    opts = opts or {}
    local index = #self.items + 1
    opts.Parent = self.lanes[(index - 1) % self.count + 1]
    opts.LayoutOrder = index
    local item = Item.new(opts, self)
    table.insert(self.items, item)
    self:Count()
    return item
end

function Shelf:Items(list)
    local made = {}
    for _, opts in ipairs(list) do
        table.insert(made, self:Item(opts))
    end
    return made
end

function Shelf:Selected()
    local picked = {}
    for _, item in ipairs(self.items) do
        if item.Selected then
            table.insert(picked, item)
        end
    end
    return picked
end

function Shelf:Clear()
    for i = #self.items, 1, -1 do
        self.items[i].Frame:Destroy()
        self.items[i] = nil
    end
    self:Count()
end

function Shelf:SetTitle(text)
    self.Name = text
    self.Title.Text = text
    return self
end

-- the tab search box lands here: hide the items that miss, keep the shelf if any hit
function Shelf:Match(query)
    local any = false
    for _, item in ipairs(self.items) do
        local ok = item:Match(query)
        item.Frame.Visible = ok
        any = any or ok
    end
    if query == "" then
        return true
    end
    return any or self.Name:lower():find(query, 1, true) ~= nil
end

Item.Shelf = Shelf

return Item
end

__flowStartupCheckpoint()

end
