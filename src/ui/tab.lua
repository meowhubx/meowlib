return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/tab"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local Card = require("ui/card")
local Item = require("ui/item")
local Audio = require("core/audio")

local Tab = {}
Tab.__index = Tab

function Tab.new(window, opts)
    local self = setmetatable({}, Tab)
    self.flow = window.flow
    self.window = window
    self.Name = opts.Name or "Tab"
    self.Icon = opts.Icon or "cube"
    self.cards = {}
    self.slot = 0

    local page = Util.new("CanvasGroup", {
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1,
        Visible = false,
        Parent = window.Body,
    })
    self.Page = page

    local scroller = Craft.scroll({
        Name = "Scroller",
        Size = UDim2.fromScale(1, 1),
        Parent = page,
    })
    -- Theme.gutter, not a local guess: the header, the tab strip and these lanes
    -- all start at the same x, so the left edge of a card lines up with the logo
    -- and the first tab. They used to sit at 16, 18 and 18.
    local padLeft, padRight = Theme.gutter, Theme.gutter
    local padTop, padBottom = 12, 14
    Util.pad(scroller, padTop, padRight, padBottom, padLeft)
    self.Scroller = scroller
    -- what the page costs on top of the lanes themselves, so Window:Resize can
    -- turn a lane height into a window height
    self.pageInset = padTop + padBottom

    local gap = Theme.chrome.gap

    local lanes = Craft.frame({
        Name = "Lanes",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -(padLeft + padRight), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = scroller,
    })
    Util.list(lanes, gap, Enum.FillDirection.Horizontal)
    self.Lanes = lanes
    self.gap = gap

    local count = window.columns
    self.columns = {}
    for i = 1, count do
        local lane = Craft.frame({
            Name = "Lane" .. i,
            BackgroundTransparency = 1,
            Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = i,
            Parent = lanes,
        })
        Util.list(lane, gap)
        self.columns[i] = lane
    end
    self.active = count
    self.spread = count

    -- cards expanding, a filter hiding half of them, a lane rebalance: all of it
    -- lands here as a lane height change, and the window follows it
    -- no tween: a card expanding is already animating its own height, so setting
    -- the window directly makes the frame grow in lockstep with the card instead
    -- of chasing it a beat behind
    lanes:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if window.active == self then
            window:Resize(false)
        end
    end)

    -- Tabs are laid out as: [divider] [tab] [divider] [tab] ... so each one owns a
    -- padded footprint with a hairline between neighbours. Explicit LayoutOrder
    -- keeps that interleaving stable.
    local slot = (#window.tabs + 1) * 10

    if #window.tabs > 0 then
        Craft.frame({
            Name = "Split",
            Token = "line",
            Size = UDim2.fromOffset(1, 14),
            BackgroundTransparency = 0.55,
            LayoutOrder = slot - 5,
            ZIndex = 3,
            Parent = window.Strip,
        })
    end

    local button = Craft.button({
        Name = "",
        Token = "surfaceAlt",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, Theme.chrome.tab),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = slot,
        ZIndex = 3,
        Parent = window.Strip,
    })
    Util.corner(button, 8)
    Util.list(
        button,
        7,
        Enum.FillDirection.Horizontal,
        Enum.HorizontalAlignment.Center,
        Enum.VerticalAlignment.Center
    )
    Util.pad(button, 0, 11, 0, 11)
    self.Button = button

    local holder = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15, 15),
        LayoutOrder = 1,
        ZIndex = 4,
        Parent = button,
    })
    self.Glyph = Icons.draw({ Icon = self.Icon, Size = 15, Color = Theme.get("textFaint"), ZIndex = 5, Parent = holder })

    self.Label = Craft.text({
        Text = self.Name,
        Token = "textFaint",
        TextSize = 13.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 4,
        Parent = button,
    })

    button.MouseButton1Click:Connect(function()
        if window.active ~= self then
            Audio.play("click")
        end
        window:Select(self)
    end)

    -- inactive tabs had no hover feedback at all; now they lift toward the
    -- active colour so the strip feels clickable
    button.MouseEnter:Connect(function()
        self.hot = true
        self:Paint()
    end)
    button.MouseLeave:Connect(function()
        self.hot = false
        self:Paint()
    end)

    Theme.watch(function()
        if not button.Parent then
            return false
        end
        self:Paint()
        return true
    end)

    return self
end

function Tab:Module(opts)
    self.slot = self.slot + 1
    opts.LayoutOrder = self.slot
    -- Balance settles this properly a frame or two later; the point of picking a
    -- lane now is only that the card is never parented to a folded-away one and
    -- flickers out of sight until then
    local lanes = math.clamp(self.spread or #self.columns, 1, #self.columns)
    local pick = opts.Column and math.min(opts.Column, lanes) or ((self.slot - 1) % lanes + 1)
    opts.Parent = self.columns[pick]
    local card = Card.new(self, opts)
    card.pinned = opts.Column
    table.insert(self.cards, card)
    table.insert(self.flow.modules, card)
    self:Balance()
    return card
end

-- Shelves and item cards sit in the lanes the same way modules do, but they are
-- not modules: no switch, no flag, nothing for the keybind handler to walk, so
-- they stay out of flow.modules. Tab:Balance only needs a Frame, a pinned lane
-- and a Match, which both of them have.
local function place(self, opts, build)
    self.slot = self.slot + 1
    opts.LayoutOrder = self.slot
    local lanes = math.clamp(self.spread or #self.columns, 1, #self.columns)
    local pick = opts.Column and math.min(opts.Column, lanes) or ((self.slot - 1) % lanes + 1)
    opts.Parent = self.columns[pick]
    local piece = build(self, opts)
    piece.pinned = opts.Column
    table.insert(self.cards, piece)
    self:Balance()
    return piece
end

-- a titled grid of item cards (shop, killers, perks, loadouts...)
function Tab:Shelf(opts)
    return place(self, opts or {}, Item.Shelf.new)
end

-- a single item card, laid out like a module
function Tab:Item(opts)
    return place(self, opts or {}, function(tab, o)
        return Item.new(o, nil, tab.flow)
    end)
end

-- lane widths are set here and nowhere else, so the two things that decide them
-- can't disagree: how wide the window is (Reflow) and how many cards there are
-- to fill them (Balance)
function Tab:Spread(count)
    count = math.clamp(count, 1, #self.columns)
    if self.spread == count then
        return
    end
    self.spread = count
    local gap = self.gap or Theme.chrome.gap
    for i, lane in ipairs(self.columns) do
        lane.Visible = i <= count
        lane.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0)
    end
end

-- narrow screens fold the card lanes down rather than squeezing three columns
-- into an unreadable width
function Tab:Reflow(count)
    count = math.clamp(count, 1, #self.columns)
    if self.active == count then
        return
    end
    self.active = count
    self:Balance()
end

function Tab:Balance()
    self.pending = (self.pending or 0) + 1
    local token = self.pending
    task.delay(0.08, function()
        if self.pending ~= token then
            return
        end
        local room = self.active or #self.columns
        -- a three-column tab holding two modules used to draw them a third of the
        -- way across and leave the last lane blank. Fold to the number of cards
        -- instead, but never past two: one module stretched over a whole window
        -- is a row of very lonely toggles.
        local lanes = math.clamp(#self.cards, math.min(2, room), room)
        -- a tab made only of shelves (a shop page) wants the full width, so its
        -- shelves stack in one lane instead of sitting half a window wide
        local full = #self.cards > 0
        for _, card in ipairs(self.cards) do
            if not card.Full then
                full = false
                break
            end
        end
        if full then
            lanes = 1
        end
        self:Spread(lanes)
        local gap = self.gap or Theme.chrome.gap
        local heights = table.create(lanes, 0)
        for i, card in ipairs(self.cards) do
            local pinned = card.pinned and math.min(card.pinned, lanes) or nil
            if pinned then
                local lane = self.columns[pinned]
                heights[pinned] = heights[pinned] + card.Frame.AbsoluteSize.Y + gap
                card.Frame.LayoutOrder = i
                card.Frame.Parent = lane
            else
                local pick = 1
                for c = 2, lanes do
                    if heights[c] + 0.5 < heights[pick] then
                        pick = c
                    end
                end
                heights[pick] = heights[pick] + card.Frame.AbsoluteSize.Y + gap
                card.Frame.LayoutOrder = i
                if card.Frame.Parent ~= self.columns[pick] then
                    card.Frame.Parent = self.columns[pick]
                end
            end
        end
    end)
end

function Tab:Filter(query)
    local hits = 0
    for _, card in ipairs(self.cards) do
        local ok = card:Match(query)
        card.Frame.Visible = ok
        if ok then
            hits = hits + 1
        end
    end
    return hits
end

-- single source of truth for tab colour: active beats hover beats idle
function Tab:Paint()
    local live = self.window.active == self
    local label = live and Theme.get("text") or (self.hot and Theme.get("textDim") or Theme.get("textFaint"))
    local glyph = live and Theme.get("accent") or (self.hot and Theme.get("textDim") or Theme.get("textFaint"))
    local fill = live and 0.45 or (self.hot and 0.75 or 1)
    Util.tween(self.Label, { TextColor3 = label }, Util.ease.snap)
    Util.tween(self.Button, { BackgroundTransparency = fill }, Util.ease.snap)
    Icons.tint(self.Glyph, glyph)
end

function Tab:Show()
    self.Page.Visible = true
    self.Page.Position = UDim2.fromOffset(0, 8)
    Util.tween(self.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Util.ease.glide)
    self:Paint()
    -- tabs are rarely the same length, so the window has to re-measure on a swap
    -- rather than keep whatever the last one asked for
    self.window:Resize()
end

function Tab:Hide()
    Util.tween(self.Page, { GroupTransparency = 1 }, Util.ease.snap)
    self:Paint()
    task.delay(0.14, function()
        if self.window.active ~= self then
            self.Page.Visible = false
        end
    end)
end

return Tab
end

__flowStartupCheckpoint()

end