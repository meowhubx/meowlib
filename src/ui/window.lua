return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/window"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")
local UserInputService = __service("UserInputService")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Icons = require("core/icons")
local State = require("core/state")
local Overlay = require("ui/overlay")
local Controls = require("ui/controls")
local Tab = require("ui/tab")
local Audio = require("core/audio")
local Luarmor = require("core/luarmor")
local Notify = require("hud/notify")

local Window = {}
Window.__index = Window

local lp = Players.LocalPlayer

local swatches = {
    Color3.fromRGB(124, 92, 255),
    Color3.fromRGB(92, 124, 255),
    Color3.fromRGB(70, 178, 240),
    Color3.fromRGB(64, 206, 186),
    Color3.fromRGB(80, 205, 137),
    Color3.fromRGB(240, 178, 78),
    Color3.fromRGB(238, 108, 92),
    Color3.fromRGB(236, 94, 178),
}

local function iconButton(parent, icon, order, size)
    local button = Craft.button({
        Name = icon,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size or 30, size or 30),
        LayoutOrder = order,
        ZIndex = 4,
        Parent = parent,
    })
    Util.corner(button, 8)
    local glyph = Icons.draw({ Icon = icon, Size = math.floor((size or 30) * 0.52), Token = "textDim", ZIndex = 5, Parent = button })
    Util.hover(button, button, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })
    Theme.bind(button, "BackgroundColor3", "surfaceAlt")
    return button, glyph
end

function Window.new(flow, opts)
    local self = setmetatable({}, Window)
    self.flow = flow
    self.tabs = {}
    self.columns = opts.Columns or 3
    self.open = true

    local size = opts.Size or UDim2.fromOffset(900, 580)
    self.wanted = Vector2.new(size.X.Offset, size.Y.Offset)
    self.minColumns = opts.MinColumns or 1
    -- Size is a ceiling, not a fixed height: the window ends where the page it is
    -- showing ends. AutoHeight = false pins it to the ceiling instead.
    self.autoHeight = opts.AutoHeight ~= false
    self.chromeTop = Theme.chrome.top
    self.footerHeight = 0
    self.width = size.X.Offset
    self.room = size.Y.Offset
    local bleed = 36
    self.baseSize = UDim2.new(size.X.Scale, size.X.Offset + bleed, size.Y.Scale, size.Y.Offset + bleed)

    local shell = Util.new("CanvasGroup", {
        Name = "Window",
        BackgroundTransparency = 1,
        Size = self.baseSize,
        Position = opts.Position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Parent = flow.layers.window,
    })
    self.Shell = shell

    for i = 1, 3 do
        Craft.frame({
            Name = "Halo",
            Token = "black",
            Radius = Theme.radius.window + i * 4,
            BackgroundTransparency = 0.72 + i * 0.08,
            Size = UDim2.new(1, -bleed + i * 11, 1, -bleed + i * 11),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 4 - i,
            Parent = shell,
        })
    end

    local root = Craft.frame({
        Name = "Chrome",
        Token = "backdrop",
        Radius = Theme.radius.window,
        Size = UDim2.new(1, -bleed, 1, -bleed),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true,
        ZIndex = 5,
        Parent = shell,
    })
    local edge = Util.stroke(root, Theme.get("line"), 1, 0.15)
    Theme.bind(edge, "Color", "line")
    self.Frame = root

    local header = Craft.frame({
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.header),
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(header, 0, Theme.gutter, 0, Theme.gutter)
    self.Header = header
    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        -- bleeds back out through the padding to stop 2px short of each edge
        Size = UDim2.new(1, Theme.gutter * 2 - 4, 0, 1),
        Position = UDim2.new(0, -Theme.gutter + 2, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        ZIndex = 4,
        Parent = header,
    })

    local brand = Craft.frame({
        Name = "Brand",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
        Parent = header,
    })
    Util.list(brand, 9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local markName = opts.Mark or "brand"
    local mark

    if Icons.images[markName] then
        -- a logo already reads as its own shape, so it sits bare rather than in a
        -- tile; ScaleType.Fit keeps it square inside the cell whatever its aspect
        mark = Craft.frame({
            Name = "Mark",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(36, 36),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = brand,
        })
        Icons.draw({ Icon = markName, Size = 36, ZIndex = 6, Parent = mark })
    else
        mark = Craft.frame({
            Name = "Mark",
            Token = "accent",
            Radius = 9,
            Size = UDim2.fromOffset(30, 30),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = brand,
        })
        self.MarkGradient = Craft.gradient(mark, Theme.get("accentGlow"), Theme.get("accentDeep"), 62)
        Theme.watch(function()
            if not mark.Parent then
                return false
            end
            self.MarkGradient.Color = ColorSequence.new(Theme.get("accentGlow"), Theme.get("accentDeep"))
        end)
        Icons.draw({ Icon = markName, Size = 17, Color = Theme.get("white"), ZIndex = 6, Parent = mark })
    end

    local words = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        LayoutOrder = 2,
        ZIndex = 5,
        Parent = brand,
    })
    Util.list(words, 1)
    self.BrandWords = words

    Craft.text({
        Name = "Title",
        Text = opts.Title or "FLOW",
        Token = "text",
        TextSize = 17,
        FontFace = Theme.font.bold,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 19),
        ZIndex = 6,
        Parent = words,
    })
    -- the strap under the title is opt-in; nothing is drawn unless Build is given
    if opts.Build then
        local buildRow = Craft.frame({
            Name = "BuildRow",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 14),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            ZIndex = 6,
            Parent = words,
        })
        Util.list(buildRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        Craft.frame({
            Name = "Live",
            Token = "accent",
            Radius = UDim.new(1, 0),
            Size = UDim2.fromOffset(5, 5),
            LayoutOrder = 1,
            ZIndex = 7,
            Parent = buildRow,
        })

        Craft.text({
            Name = "Build",
            Text = opts.Build,
            Token = "textFaint",
            TextSize = 11.5,
            FontFace = Theme.font.regular,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
            ZIndex = 7,
            Parent = buildRow,
        })
    end

    local actions = Craft.frame({
        Name = "Actions",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        ZIndex = 4,
        Parent = header,
    })
    Util.list(actions, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local searchBox = Craft.frame({
        Name = "Search",
        Token = "surfaceAlt",
        Radius = Theme.radius.control,
        Edge = "lineSoft",
        Size = UDim2.fromOffset(opts.SearchWidth or 200, Theme.chrome.field),
        LayoutOrder = 1,
        ZIndex = 5,
        Parent = actions,
    })
    self.SearchBox = searchBox
    self.SearchWidth = opts.SearchWidth or 200
    Util.pad(searchBox, 0, 9, 0, 29)
    Icons.draw({
        Icon = "search",
        Size = 14,
        Token = "textFaint",
        Position = UDim2.new(0, -19, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 6,
        Parent = searchBox,
    })
    local search = Util.new("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        PlaceholderText = "Search",
        FontFace = Theme.font.medium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 6,
        Parent = searchBox,
    })
    Theme.bind(search, "TextColor3", "text")
    Theme.bind(search, "PlaceholderColor3", "textFaint")
    self.Search = search

    local bell = iconButton(actions, "bell", 2, Theme.chrome.icon)
    local gear = iconButton(actions, "gear", 3, Theme.chrome.icon)

    Craft.frame({
        Name = "Split",
        Token = "line",
        Size = UDim2.fromOffset(1, 18),
        LayoutOrder = 4,
        ZIndex = 5,
        Parent = actions,
    })

    local account = Craft.button({
        Name = "Account",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 5,
        ZIndex = 5,
        Parent = actions,
    })
    Util.corner(account, 9)
    Util.pad(account, 0, 7, 0, 4)
    Theme.bind(account, "BackgroundColor3", "surfaceAlt")
    Util.hover(account, account, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })

    local accountRow = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 6,
        Parent = account,
    })
    Util.list(accountRow, 7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local avatar = Util.new("ImageLabel", {
        Name = "Avatar",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(27, 27),
        LayoutOrder = 1,
        ZIndex = 7,
        Parent = accountRow,
    })
    Util.corner(avatar, 7)
    task.spawn(function()
        avatar.Image = Util.thumbnail(lp.UserId)
    end)

    local names = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 27),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        ZIndex = 7,
        Parent = accountRow,
    })
    Util.list(names, 0)
    self.AccountNames = names

    Craft.text({
        Text = opts.User or lp.DisplayName,
        Token = "text",
        TextSize = 13,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 14),
        ZIndex = 8,
        Parent = names,
    })
    self.PlanLabel = Craft.text({
        Text = opts.Tag or Luarmor.plan(),
        -- premium wears the accent, free wears green; set here as well as in
        -- RefreshPlan so the tag never changes colour on the first profile open
        Token = Luarmor.isPremium() and "accent" or "success",
        TextSize = 10.5,
        FontFace = Theme.font.semi,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 12),
        ZIndex = 8,
        Parent = names,
    })
    -- an explicit Tag is the caller's to own; otherwise the plan tracks the key
    self.PlanFixed = opts.Tag ~= nil

    local caret = Craft.frame({
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        LayoutOrder = 3,
        ZIndex = 7,
        Parent = accountRow,
    })
    Icons.draw({ Icon = "chevron-down", Size = 11, Token = "textFaint", ZIndex = 8, Parent = caret })

    --[[
        The strip scrolls horizontally. A window fits about nine tabs across, and
        a plain frame simply drew the rest past its own edge where they could
        never be clicked. The scrollbar is hidden — it would land on the rule
        below — so the strip is driven by wheel and drag, and Window:Reveal
        brings a selected tab into view.

        A hidden scrollbar and a mouse wheel are both desktop assumptions, and a
        phone has neither: nothing said there were more tabs and nothing but a
        lucky swipe would reach them. Window:Rail adds an arrow at each end that
        appears only when there is something past it — see below.
    ]]
    local strip = Craft.scroll({
        Name = "Strip",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.chrome.strip),
        Position = UDim2.fromOffset(0, Theme.chrome.header),
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = root,
    })
    Util.pad(strip, 0, Theme.gutter, 0, Theme.gutter)
    Util.list(strip, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.Strip = strip

    -- the marker sits outside the strip, so scrolling has to drag it along or it
    -- would drift away from the tab it belongs to
    strip:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if self.active then
            self:Mark(self.active, false)
        end
        self:Rail()
    end)

    self:BuildRail(root)

    local top = Theme.chrome.top

    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, top - 1),
        ZIndex = 4,
        Parent = root,
    })

    local marker = Craft.frame({
        Name = "Marker",
        Token = "accent",
        Radius = UDim.new(1, 0),
        Size = UDim2.fromOffset(0, 2),
        Position = UDim2.fromOffset(Theme.gutter, top - 3),
        ZIndex = 5,
        Parent = root,
    })
    self.Marker = marker

    local body = Craft.frame({
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -top),
        Position = UDim2.fromOffset(0, top),
        ZIndex = 2,
        Parent = root,
    })
    self.Body = body

    Util.drag(header, shell)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        self:Filter(search.Text)
    end)

    search.FocusLost:Connect(function(_, cause)
        if cause and cause.KeyCode == Enum.KeyCode.Escape then
            search.Text = ""
        end
    end)

    account.MouseButton1Click:Connect(function()
        self:Profile(account)
    end)
    gear.MouseButton1Click:Connect(function()
        self:Settings(gear)
    end)
    bell.MouseButton1Click:Connect(function()
        Notify.panel(bell)
    end)

    self.Account = { Name = opts.User or lp.DisplayName, Tag = opts.Tag or Luarmor.plan() }

    return self
end

--[[
    A bar across the bottom of the window: who made it, where the connection is,
    and a way out to a community. Purely cosmetic, but a sparse tab leaves a lot
    of empty surface and a hub with nothing along the bottom reads unfinished.

    Every slot is optional and nothing is drawn for one that is not configured.
]]

-- Region comes from a public IP lookup, which means two things worth knowing:
-- it geolocates whoever is RUNNING the script, not the Roblox server, and it
-- hands their IP to a third party. Pass a plain string instead to skip both.
local function lookupRegion(done)
    task.spawn(function()
        local ok, body = pcall(function()
            return game:HttpGet("http://ip-api.com/json/?fields=status,country,countryCode,city")
        end)
        if not ok then
            return done(nil)
        end
        local parsed
        ok, parsed = pcall(function()
            return __service("HttpService"):JSONDecode(body)
        end)
        if not ok or type(parsed) ~= "table" or parsed.status ~= "success" then
            return done(nil)
        end
        if parsed.city and parsed.countryCode then
            return done(parsed.city .. ", " .. parsed.countryCode)
        end
        done(parsed.country or parsed.countryCode)
    end)
end

function Window:Footer(opts)
    opts = opts or {}
    if self.FooterBar then
        self.FooterBar:Destroy()
        self.FooterBar = nil
    end

    local height = opts.Height or Theme.chrome.footer
    local bar = Craft.frame({
        Name = "Footer",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        ZIndex = 3,
        Parent = self.Frame,
    })
    Util.pad(bar, 0, Theme.gutter, 0, Theme.gutter)
    self.FooterBar = bar

    Craft.frame({
        Name = "Rule",
        Token = "lineSoft",
        Size = UDim2.new(1, Theme.gutter * 2 - 4, 0, 1),
        Position = UDim2.new(0, -Theme.gutter + 2, 0, 0),
        ZIndex = 4,
        Parent = bar,
    })

    -- pages stop above the bar rather than scrolling underneath it
    self.footerHeight = height
    self.Body.Size = UDim2.new(1, 0, 1, -(self.chromeTop + height))
    self:Resize(false)

    ----------------------------------------------------------------------------
    -- left: sticker + credit
    ----------------------------------------------------------------------------

    local left = Craft.frame({
        Name = "Credit",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 4,
        Parent = bar,
    })
    Util.list(left, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local function emoji()
        if not opts.Emoji then
            return nil
        end
        return Craft.text({
            Name = "Sticker",
            -- BuilderSans has no glyph for these, so the engine falls back to its
            -- emoji font: a text label, not an icon
            Text = opts.Emoji,
            TextSize = 15,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 18),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = left,
        })
    end

    if opts.Sticker then
        local size = opts.StickerSize or 24
        -- the usual thing to put here is a profile picture, so it is cropped to
        -- a circle by default. StickerRound = false leaves a fitted square for a
        -- transparent sticker that should not lose its corners.
        local round = opts.StickerRound ~= false
        local image = Util.new("ImageLabel", {
            Name = "Sticker",
            BackgroundTransparency = 1,
            Image = opts.Sticker,
            ScaleType = round and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
            Size = UDim2.fromOffset(size, size),
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = left,
        })
        if round then
            Util.corner(image, UDim.new(1, 0))
        end

        -- an id that is still in moderation, private, or simply wrong resolves to
        -- nothing and leaves a hole in the row. Fall back to the emoji instead.
        task.spawn(function()
            pcall(function()
                __service("ContentProvider"):PreloadAsync({ image })
            end)
            if image.Parent and not image.IsLoaded and opts.Emoji then
                image:Destroy()
                emoji()
            end
        end)
    else
        emoji()
    end

    if opts.Credit then
        Craft.text({
            Name = "Text",
            Text = opts.Credit,
            Token = "textDim",
            TextSize = 12.5,
            FontFace = Theme.font.medium,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16),
            LayoutOrder = 2,
            ZIndex = 5,
            Parent = left,
        })
    end

    ----------------------------------------------------------------------------
    -- right: region readout + link out
    ----------------------------------------------------------------------------

    local right = Craft.frame({
        Name = "Links",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        ZIndex = 4,
        Parent = bar,
    })
    Util.list(right, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    if opts.Region then
        local row = Craft.frame({
            Name = "Region",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 1,
            ZIndex = 5,
            Parent = right,
        })
        Util.list(row, 5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

        -- Icons.draw centres itself by default, which a list layout then shifts
        -- by half its own size; anchoring at the corner puts it back
        local mark = Icons.draw({
            Icon = "signal",
            Size = 12,
            Token = "textFaint",
            Position = UDim2.new(),
            AnchorPoint = Vector2.new(0, 0),
            ZIndex = 6,
            Parent = row,
        })
        mark.LayoutOrder = 1

        local text = Craft.text({
            Name = "Value",
            Text = type(opts.Region) == "string" and opts.Region or "Locating",
            Token = "textFaint",
            TextSize = 12,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16),
            LayoutOrder = 2,
            ZIndex = 6,
            Parent = row,
        })

        if opts.Region == true then
            lookupRegion(function(value)
                if text.Parent then
                    text.Text = value or "Unknown"
                end
            end)
        end
    end

    if opts.Discord then
        -- an invite is a link to follow, a username is a name to add: show the
        -- name itself rather than hiding it behind the word "Discord"
        local invite = opts.Discord:match("^https?://") ~= nil or opts.Discord:match("discord%.gg/") ~= nil
        local label = opts.DiscordLabel or (invite and "Discord" or opts.Discord)

        local button = Craft.button({
            Name = "Discord",
            Token = "surfaceAlt",
            Radius = Theme.radius.chip,
            Edge = "lineSoft",
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
            ZIndex = 5,
            Parent = right,
        })
        Util.pad(button, 0, 11, 0, 11)

        -- no icon: the name is the label, and a glyph in front of it only
        -- repeated what the text already said
        Craft.text({
            Name = "Value",
            Text = label,
            Token = "textDim",
            TextSize = 12,
            FontFace = Theme.font.semi,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 6,
            Parent = button,
        })

        Util.hover(button, button, { BackgroundColor3 = Theme.get("surfaceAlt") }, { BackgroundColor3 = Theme.get("raised") })

        -- opening a browser is not something a UI library should do behind the
        -- user's back, so the invite goes to the clipboard and says so
        button.MouseButton1Click:Connect(function()
            Audio.play("click")
            local copied = setclipboard ~= nil and pcall(setclipboard, opts.Discord)
            self.flow:Notify({
                Title = copied and (invite and "Invite copied" or "Username copied") or "Discord",
                Text = opts.Discord,
                Icon = invite and "link" or "user",
                Kind = copied and "success" or nil,
                Duration = 4,
            })
        end)
    end

    return bar
end

--[[
    The window is exactly as tall as the page it is showing, up to the ceiling
    Fit worked out from Size and the viewport. A tab with two cards used to draw
    them into the top corner of a 680px frame and leave the rest empty; now the
    frame ends where the cards do, and a tab with more than fits scrolls.

    Nothing here touches width — lanes are fractional, so a narrower window would
    only make the cards narrower, not the layout tighter.
]]
function Window:Resize(animate)
    local height = self.room

    if self.autoHeight then
        local tab = self.active
        local lanes = tab and tab.Lanes
        if lanes then
            -- AbsoluteSize is in screen pixels, so undo the interface scale to get
            -- back to the offsets the window is actually built in
            local k = math.max(self.flow.scale.Scale, 0.01)
            local chrome = self.chromeTop + self.footerHeight + (tab.pageInset or 0)
            -- a tab with nothing in it still needs somewhere to say so
            local least = math.min(chrome + 90, self.room)
            height = math.clamp(lanes.AbsoluteSize.Y / k + chrome, least, self.room)
        end
    end

    height = math.floor(height + 0.5)
    if self.height == height and self.shellWidth == self.width then
        return
    end
    self.height = height
    self.shellWidth = self.width

    local bleed = 36
    self.baseSize = UDim2.fromOffset(self.width + bleed, height + bleed)
    if not self.open then
        return
    end

    -- a plain assignment loses to a tween that is still running, and the window
    -- ends up wherever the stale one was headed. Every size change goes through
    -- here so there is exactly one to cancel.
    if self.sizeTween then
        self.sizeTween:Cancel()
        self.sizeTween = nil
    end
    if animate == false then
        self.Shell.Size = self.baseSize
    else
        self.sizeTween = Util.tween(self.Shell, { Size = self.baseSize }, Util.ease.glide)
    end
end

--[[
    The header is two independently anchored halves: the brand on the left, the
    actions on the right. Neither knew how much room the other needed, so on a
    phone the search field simply drew straight over the logo.

    Three tiers, widest first. The account avatar, the bell and the gear survive
    all of them — they are the ones that are actually pressed.
]]
function Window:Compress(width)
    local tier = (width < 470 and 2) or (width < 640 and 1) or 0
    if self.tier == tier then
        return
    end
    self.tier = tier

    if self.BrandWords then
        self.BrandWords.Visible = tier == 0
    end
    if self.AccountNames then
        self.AccountNames.Visible = tier == 0
    end
    if self.SearchBox then
        self.SearchBox.Visible = tier < 2
        if tier == 1 then
            self.SearchBox.Size = UDim2.fromOffset(124, Theme.chrome.field)
        else
            self.SearchBox.Size = UDim2.fromOffset(self.SearchWidth or 200, Theme.chrome.field)
        end
        -- a hidden field that still holds a query would filter every tab with no
        -- way to see or clear it
        if tier == 2 and self.Search and self.Search.Text ~= "" then
            self.Search.Text = ""
        end
    end
end

-- Keep the window inside the viewport and drop card lanes when it gets narrow,
-- so a phone gets one readable column instead of three slivers.
function Window:Fit(viewport)
    viewport = viewport or Util.viewport()

    local margin = viewport.X < 700 and 12 or 40
    local width = math.min(self.wanted.X, viewport.X - margin * 2)
    local room = math.min(self.wanted.Y, viewport.Y - margin * 2)
    self.width = math.max(width, 280)
    self.room = math.max(room, 240)

    self:Compress(self.width)

    -- roughly 300px of usable width per lane before cards stop being readable
    local lanes = math.clamp(math.floor(self.width / 300), self.minColumns, self.columns)
    for _, tab in ipairs(self.tabs) do
        tab:Reflow(lanes)
    end

    self:Resize(false)

    -- keep the window on screen after a resize or rotation
    local half = self.Shell.AbsoluteSize / 2
    local pos = self.Shell.Position
    self.Shell.Position = UDim2.new(
        pos.X.Scale,
        Util.clamp(pos.X.Offset, -viewport.X * pos.X.Scale + half.X, viewport.X - viewport.X * pos.X.Scale - half.X),
        pos.Y.Scale,
        Util.clamp(pos.Y.Offset, -viewport.Y * pos.Y.Scale + half.Y, viewport.Y - viewport.Y * pos.Y.Scale - half.Y)
    )

    return lanes
end

function Window:Tab(opts)
    local tab = Tab.new(self, opts)
    table.insert(self.tabs, tab)
    if not self.active then
        self:Select(tab)
    end
    return tab
end

-- slide the underline to a tab. Positions are read live rather than cached so
-- this stays correct while the strip scrolls.
function Window:Mark(tab, animate)
    if not tab or not tab.Button then
        return
    end
    local k = math.max(self.flow.scale.Scale, 0.01)
    local origin = self.Strip.AbsolutePosition.X
    local target = {
        Position = UDim2.fromOffset(math.floor((tab.Button.AbsolutePosition.X - origin) / k), self.chromeTop - 3),
        Size = UDim2.fromOffset(math.floor(tab.Button.AbsoluteSize.X / k), 2),
    }
    if animate == false then
        self.Marker.Position = target.Position
        self.Marker.Size = target.Size
    else
        Util.tween(self.Marker, target, Util.ease.glide)
    end
end

--[[
    An arrow at each end of the tab strip.

    A hidden scrollbar leaves nothing on screen to say the strip goes further, and
    on a phone there is no wheel to find out with. Roblox will scroll the frame
    from a touch drag, but only if you already know to try — and a drag that
    starts on a tab reads as a press until the finger moves, which is not a thing
    to make someone discover.

    So: a tappable arrow, which every pointer has, showing only on the side that
    has something past it. It sits outside the strip rather than inside, or it
    would scroll away with the tabs it belongs to.
]]
function Window:BuildRail(root)
    local size = math.max(Theme.chrome.strip - 12, 24)
    local pad = Theme.chrome.strip

    local function arrow(icon, side)
        local button = Craft.button({
            Name = "Rail",
            Token = "backdrop",
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(pad, Theme.chrome.strip),
            Position = UDim2.new(side, 0, 0, Theme.chrome.header),
            AnchorPoint = Vector2.new(side, 0),
            Visible = false,
            ZIndex = 6,
            Parent = root,
        })
        -- the tabs fade out under the arrow instead of being cut off by it
        local wash = Craft.gradient(button, Theme.get("backdrop"), Theme.get("backdrop"), side == 0 and 0 or 180)
        wash.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.55, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        Theme.watch(function()
            if not button.Parent then
                return false
            end
            local backdrop = Theme.get("backdrop")
            wash.Color = ColorSequence.new(backdrop, backdrop)
        end)

        local glyph = Icons.draw({
            Icon = icon,
            Size = math.floor(size * 0.62),
            Token = "textDim",
            ZIndex = 7,
            Parent = button,
        })

        button.MouseEnter:Connect(function()
            Icons.tint(glyph, Theme.get("text"))
        end)
        button.MouseLeave:Connect(function()
            Icons.tint(glyph, Theme.get("textDim"))
        end)
        button.MouseButton1Click:Connect(function()
            Audio.play("click")
            self:Nudge(side == 0 and -1 or 1)
        end)

        return button
    end

    self.RailLeft = arrow("chevron-left", 0)
    self.RailRight = arrow("chevron-right", 1)

    -- a tab being added changes the canvas without moving it, so CanvasPosition
    -- alone would never fire
    self.Strip:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
        self:Rail()
    end)
    self.Strip:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
        self:Rail()
    end)
end

--[[
    How far the strip can travel, and where it is.

    Worth stating because it is not what the property names suggest: under a
    UIScale, CanvasPosition lives in the same scaled space as AbsoluteCanvasSize
    and AbsoluteWindowSize, not in the frame's own offsets. Measured, not
    assumed — the engine clamps CanvasPosition to exactly this difference.
]]
function Window:railRange()
    local strip = self.Strip
    local span = strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X
    return math.max(span, 0), strip.CanvasPosition.X
end

function Window:Rail()
    if not self.RailLeft then
        return
    end
    local span, at = self:railRange()
    self.RailLeft.Visible = span > 2 and at > 2
    self.RailRight.Visible = span > 2 and at < span - 2
end

-- one arrow tap moves most of a screenful, keeping a tab or two of overlap so
-- the strip does not feel like it jumped somewhere unrelated
function Window:Nudge(direction)
    local strip = self.Strip
    local span, at = self:railRange()
    local step = math.max(strip.AbsoluteWindowSize.X * 0.7, 60)
    local target = Util.clamp(at + step * direction, 0, span)
    Util.tween(strip, { CanvasPosition = Vector2.new(target, 0) }, Util.ease.out)
end

-- scroll a tab into view, so selecting one that sits past the strip's edge
-- actually shows it
function Window:Reveal(tab)
    local strip = self.Strip
    if not tab or not tab.Button or not strip:IsA("ScrollingFrame") then
        return
    end
    local left = tab.Button.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X
    local right = left + tab.Button.AbsoluteSize.X
    local view = strip.AbsoluteWindowSize.X
    -- leave room for the arrow rather than tucking the tab underneath it
    local margin = Theme.chrome.strip
    local target = strip.CanvasPosition.X
    if left - margin < target then
        target = math.max(left - margin, 0)
    elseif right + margin > target + view then
        target = right - view + margin
    end
    local span = select(1, self:railRange())
    target = Util.clamp(target, 0, span)
    if math.abs(target - strip.CanvasPosition.X) > 1 then
        Util.tween(strip, { CanvasPosition = Vector2.new(target, 0) }, Util.ease.out)
    end
end

function Window:Select(tab)
    if self.active == tab then
        return
    end
    -- swap the pointer first: Tab:Paint() derives its state from window.active,
    -- so hiding before the swap would repaint the outgoing tab as still active
    local previous = self.active
    self.active = tab
    if previous then
        previous:Hide()
    end
    tab:Show()
    task.defer(function()
        self:Reveal(tab)
        self:Mark(tab, true)
    end)
end

function Window:Filter(query)
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local best
    for _, tab in ipairs(self.tabs) do
        local hits = tab:Filter(query)
        if hits > 0 and not best then
            best = tab
        end
    end
    if query ~= "" and best and self.active ~= best and self.active:Filter(query) == 0 then
        self:Select(best)
    end
end

function Window:Toggle(state)
    if state == nil then
        state = not self.open
    end
    self.open = state
    Overlay.close(true)
    if self.sizeTween then
        self.sizeTween:Cancel()
        self.sizeTween = nil
    end
    if state then
        self.Shell.Visible = true
        self.sizeTween = Util.tween(self.Shell, { GroupTransparency = 0, Size = self.baseSize }, Util.ease.out)
    else
        self.sizeTween = Util.tween(self.Shell, {
            GroupTransparency = 1,
            Size = UDim2.new(
                self.baseSize.X.Scale,
                self.baseSize.X.Offset - 26,
                self.baseSize.Y.Scale,
                self.baseSize.Y.Offset - 18
            ),
        }, Util.ease.snap)
        task.delay(0.2, function()
            if not self.open then
                self.Shell.Visible = false
            end
        end)
    end
end

-- key state is a countdown, so re-read it rather than trusting what was true at
-- construction; otherwise the header can say Free while the menu says 27d left
function Window:RefreshPlan()
    if self.PlanFixed or not self.PlanLabel or not self.PlanLabel.Parent then
        return
    end
    local plan = Luarmor.plan()
    self.Account.Tag = plan
    self.PlanLabel.Text = plan
    Theme.rebind(self.PlanLabel, "TextColor3", Luarmor.isPremium() and "accent" or "success")
end

function Window:Profile(anchor)
    self:RefreshPlan()
    local entries = self.ProfileItems
        or {
            { Name = "Profile", Icon = "user" },
            { Name = "Log out", Icon = "logout", Danger = true, Callback = function()
                self.flow:Unload()
            end },
        }
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 216,
        Align = "right",
        Build = function(panel)
            Util.pad(panel, 12, 10, 10, 10)
            Util.list(panel, 8)

            local top = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 38),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })
            local face = Util.new("ImageLabel", {
                BackgroundColor3 = Theme.get("raised"),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(36, 36),
                ZIndex = 4,
                Parent = top,
            })
            Util.corner(face, 10)
            task.spawn(function()
                face.Image = Util.thumbnail(lp.UserId)
            end)
            Craft.text({
                Text = self.Account.Name,
                Token = "text",
                TextSize = 13,
                FontFace = Theme.font.semi,
                Position = UDim2.fromOffset(46, 2),
                Size = UDim2.new(1, -46, 0, 16),
                ZIndex = 4,
                Parent = top,
            })
            Craft.text({
                Text = self.Account.Tag,
                Token = Luarmor.isPremium() and "accent" or "success",
                TextSize = 11,
                Position = UDim2.fromOffset(46, 18),
                Size = UDim2.new(1, -46, 0, 14),
                ZIndex = 4,
                Parent = top,
            })

            -- real key state from Luarmor, not a made-up level
            local meter = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                LayoutOrder = 2,
                ZIndex = 3,
                Parent = panel,
            })
            Craft.text({
                Text = "Subscription",
                Token = "textDim",
                TextSize = 12,
                FontFace = Theme.font.semi,
                Size = UDim2.new(0.5, 0, 0, 15),
                ZIndex = 4,
                Parent = meter,
            })
            Craft.text({
                Text = Luarmor.duration(),
                Token = Luarmor.isPremium() and "accent" or "textDim",
                TextSize = 12,
                FontFace = Theme.font.bold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Size = UDim2.new(0.5, 0, 0, 15),
                Position = UDim2.fromScale(0.5, 0),
                ZIndex = 4,
                Parent = meter,
            })

            local expiry = Luarmor.expiry()
            local footnote
            if expiry then
                footnote = "Expires " .. expiry
            elseif Luarmor.isLifetime() then
                footnote = "Never expires"
            else
                footnote = "No key detected"
            end

            local note = Luarmor.note()
            if note then
                footnote = footnote .. " · " .. note
            end

            Craft.text({
                Text = footnote,
                Token = "textFaint",
                TextSize = 11,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(0, 17),
                Size = UDim2.new(1, 0, 0, 14),
                ZIndex = 4,
                Parent = meter,
            })

            Craft.divider(panel, 3)

            local group = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 4,
                ZIndex = 3,
                Parent = panel,
            })
            Util.list(group, 1)

            for i, item in ipairs(entries) do
                local row = Overlay.row({ Parent = group, LayoutOrder = i, Height = 31 })
                Util.pad(row, 0, 8, 0, 8)
                local holder = Craft.frame({
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 4,
                    Parent = row,
                })
                Icons.draw({
                    Icon = item.Icon or "cube",
                    Size = 13,
                    Token = item.Danger and "danger" or "textFaint",
                    ZIndex = 5,
                    Parent = holder,
                })
                Craft.text({
                    Text = item.Name,
                    Token = item.Danger and "danger" or "textDim",
                    TextSize = 12,
                    Position = UDim2.fromOffset(22, 0),
                    Size = UDim2.new(1, -38, 1, 0),
                    ZIndex = 5,
                    Parent = row,
                })
                if not item.Danger then
                    local tip = Craft.frame({
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(12, 12),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(1, 0.5),
                        ZIndex = 4,
                        Parent = row,
                    })
                    Icons.draw({ Icon = "chevron-right", Size = 11, Token = "textFaint", ZIndex = 5, Parent = tip })
                end
                row.MouseButton1Click:Connect(function()
                    Overlay.close()
                    if item.Callback then
                        task.spawn(item.Callback)
                    end
                end)
            end
        end,
    })
end

function Window:Settings(anchor)
    Overlay.toggle({
        Key = anchor,
        Anchor = anchor,
        Width = 280,
        Align = "right",
        Build = function(host)
            Util.pad(host, 12, 8, 12, 12)

            local panel = Craft.scroll({
                Name = "Body",
                Size = UDim2.new(1, 0, 0, 0),
                Parent = host,
            })
            Util.list(panel, 12)
            Util.pad(panel, 0, 8, 0, 0)

            -- cap the height against the viewport rather than a fixed number
            task.defer(function()
                if not panel.Parent then
                    return
                end
                local screen = self.flow.layers.overlay.AbsoluteSize.Y
                local cap = math.max(math.min(screen - 140, 470), 220)
                panel.Size = UDim2.new(1, 0, 0, math.min(panel.AbsoluteCanvasSize.Y, cap))
            end)

            Craft.text({
                Text = "Interface",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 1,
                ZIndex = 3,
                Parent = panel,
            })

            -- Equal-width cells so the row spans the panel evenly, and the selection
            -- ring lives in its own frame rather than as an outward stroke on the dot
            -- (a 2px border on an 18px dot needs 22px of row and clips otherwise).
            local palette = Craft.frame({
                Name = "Palette",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 28),
                LayoutOrder = 2,
                ZIndex = 3,
                Parent = panel,
            })
            Util.list(palette, 0, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

            local rings = {}

            local function near(a, b)
                return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
            end

            local function markAccent()
                for _, entry in ipairs(rings) do
                    local same = near(entry.color, Theme.accent)
                    Util.tween(entry.ring, { Transparency = same and 0.15 or 1 }, Util.ease.snap)
                    Util.tween(entry.dot, {
                        Size = UDim2.fromOffset(same and 16 or 18, same and 16 or 18),
                    }, Util.ease.snap)
                end
            end

            for i, color in ipairs(swatches) do
                local cell = Craft.frame({
                    Name = "Cell",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1 / #swatches, 0, 1, 0),
                    LayoutOrder = i,
                    ZIndex = 3,
                    Parent = palette,
                })

                local halo = Craft.frame({
                    Name = "Ring",
                    BackgroundTransparency = 1,
                    Radius = UDim.new(1, 0),
                    Size = UDim2.fromOffset(26, 26),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 4,
                    Parent = cell,
                })
                local ring = Util.stroke(halo, color, 1.5, 1)

                local dot = Craft.button({
                    Name = "Swatch",
                    Radius = UDim.new(1, 0),
                    BackgroundColor3 = color,
                    BackgroundTransparency = 0,
                    Size = UDim2.fromOffset(18, 18),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 5,
                    Parent = cell,
                })

                rings[i] = { ring = ring, dot = dot, color = color }
                dot.MouseButton1Click:Connect(function()
                    Theme.setAccent(color)
                    markAccent()
                    self.flow:retint()
                end)
            end
            markAccent()

            Controls.slider(panel, {
                Name = "Interface scale",
                Min = 0.75,
                Max = 1.35,
                Step = 0.05,
                Default = self.flow.scale.Scale,
                LayoutOrder = 3,
                Callback = function(v)
                    self.flow:SetScale(v)
                end,
            })

            local bindRow = Craft.frame({
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 4,
                ZIndex = 3,
                Parent = panel,
            })
            local head = Craft.head({ Name = "Menu key", Desc = "Opens and closes this window.", Parent = bindRow })
            head.Size = UDim2.new(1, -70, 0, 0)
            Controls.keybind(bindRow, {
                Default = self.flow.menuKey,
                Position = UDim2.new(1, 0, 0, 9),
                AnchorPoint = Vector2.new(1, 0.5),
                ZIndex = 4,
                Callback = function(key)
                    self.flow.menuKey = key
                end,
            })

            Craft.divider(panel, 5)

            -- nothing is forced on: every HUD widget can be switched off here
            Craft.text({
                Text = "Interface elements",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 6,
                ZIndex = 3,
                Parent = panel,
            })

            local widgets = self.flow:HudWidgets()
            if #widgets == 0 then
                Craft.text({
                    Text = "No HUD widgets loaded.",
                    Token = "textFaint",
                    TextSize = 11.5,
                    Size = UDim2.new(1, 0, 0, 18),
                    LayoutOrder = 7,
                    ZIndex = 3,
                    Parent = panel,
                })
            end

            for i, widget in ipairs(widgets) do
                Controls.toggle(panel, {
                    Name = widget.Label,
                    Default = widget.Hidden ~= true,
                    LayoutOrder = 7 + i,
                    Callback = function(on)
                        widget:SetVisible(on)
                    end,
                })
            end

            Craft.divider(panel, 30)

            Craft.text({
                Text = "Sound",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 31,
                ZIndex = 3,
                Parent = panel,
            })

            Controls.toggle(panel, {
                Name = "Sound effects",
                Default = Audio.enabled,
                LayoutOrder = 32,
                Callback = function(on)
                    Audio.enabled = on
                    if on then
                        Audio.play("click")
                    end
                end,
            })

            Controls.slider(panel, {
                Name = "Volume",
                Min = 0,
                Max = 1,
                Step = 0.05,
                Default = Audio.volume,
                LayoutOrder = 33,
                Callback = function(v)
                    Audio.volume = v
                end,
            })

            Craft.divider(panel, 34)

            Craft.text({
                Text = "Configs",
                Token = "textFaint",
                TextSize = 10.5,
                FontFace = Theme.font.bold,
                Size = UDim2.new(1, 0, 0, 12),
                LayoutOrder = 35,
                ZIndex = 3,
                Parent = panel,
            })

            local nameField = Controls.input(panel, {
                Placeholder = "config name",
                Default = self.flow.configName or "default",
                LayoutOrder = 36,
                Height = 30,
            })

            Controls.buttons(panel, {
                LayoutOrder = 37,
                Height = 30,
                Buttons = {
                    {
                        Name = "Save",
                        Icon = "check",
                        Accent = true,
                        Callback = function()
                            local ok, err = State.save(nameField.Value, self.flow:layout())
                            self.flow.configName = nameField.Value
                            Notify.push({
                                Title = ok and "Config saved" or "Save failed",
                                Text = ok and nameField.Value or err,
                                Icon = ok and "check" or "alert",
                                Kind = ok and "success" or "danger",
                            })
                        end,
                    },
                    {
                        Name = "Load",
                        Icon = "folder",
                        Callback = function()
                            local ok, data = State.load(nameField.Value)
                            if ok then
                                self.flow:restore(data)
                            end
                            Notify.push({
                                Title = ok and "Config loaded" or "Load failed",
                                Text = ok and nameField.Value or tostring(data),
                                Icon = ok and "check" or "alert",
                                Kind = ok and "success" or "danger",
                            })
                        end,
                    },
                },
            })
        end,
    })
end

return Window
end

--[[
    Legacy API shim.

    Scripts written against the previous Flow library carried one nesting level
    more than this one:

        Library.new{...}          ->  Flow.new{...} + ui:Window{...}
        Window:CreateSection{...} ->  (no level of its own; supplies a fallback icon)
        Section:AddTab{...}       ->  win:Tab{...}
        Tab:AddGroup{Side=...}    ->  tab:Module{Column=1|2}
        Group:AddToggle{...}      ->  card:Toggle{...}

    A Module card owns an on/off switch and a keybind chip; an old Group was a
    plain titled box. Group-backed cards therefore hide both and stay enabled, so
    a card that was never meant to toggle cannot be switched off and silently
    kill the controls inside it.

    Control objects are augmented in place rather than wrapped, so `.Value`,
    `.Frame` and `:Set(v, silent)` keep working next to the legacy `:Get()` and
    `:UpdateOptions()` helpers.

    Reached as `loadstring(game:HttpGet(url))().Legacy` — kept off `Flow.new` so
    the two `.new({...})` signatures can never be confused for one another.
]]
__flowStartupCheckpoint()

end