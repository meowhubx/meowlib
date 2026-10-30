return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/stats"] = function(require)
__flowStartupCheckpoint()
local Players = __service("Players")

local Util = require("core/util")
local Theme = require("core/theme")
local Craft = require("core/craft")
local Panel = require("hud/panel")

local Stats = {}
Stats.__index = Stats

local lp = Players.LocalPlayer

local function rootOf(player)
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Stats.new(props)
    local self = setmetatable({}, Stats)
    self.rows = {}
    self.auto = props.Auto ~= false
    self.limit = props.Limit or 6

    self.panel = Panel.new({
        Title = props.Title or "Stats",
        Icon = props.Icon or "user",
        Width = props.Width or 232,
        Position = props.Position,
        Parent = props.Parent,
        OnMove = props.OnMove,
    })
    self.Frame = self.panel.Frame
    self.Body = self.panel.Body

    self.alive = true
    if self.auto then
        local interval = props.Interval or 1
        task.spawn(function()
            while self.alive do
                -- a panel the user has switched off still ran a full distance
                -- sort against every player in the server, once a second
                if not self.Hidden then
                    self:Sync()
                end
                task.wait(interval)
            end
        end)
    end

    return self
end

-- one line: avatar, display name, right-aligned readout
function Stats:Row(props)
    local row = Craft.frame({
        Name = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 33),
        LayoutOrder = props.LayoutOrder or (#self.rows + 1),
        Parent = self.Body,
    })

    local avatar = Util.new("ImageLabel", {
        Name = "Face",
        BackgroundColor3 = Theme.get("raised"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(23, 23),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 3,
        Parent = row,
    })
    Util.corner(avatar, 6)
    Theme.bind(avatar, "BackgroundColor3", "raised")
    if props.UserId then
        avatar.Image = Util.thumbnail(props.UserId)
    end

    Craft.frame({
        Token = "line",
        Size = UDim2.fromOffset(1, 14),
        Position = UDim2.new(0, 45, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.5,
        ZIndex = 3,
        Parent = row,
    })

    local label = Craft.text({
        Text = props.Name or "",
        Token = props.Live and "text" or "textDim",
        TextSize = 12.5,
        FontFace = props.Live and Theme.font.semi or Theme.font.medium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(57, 0),
        Size = UDim2.new(1, -120, 1, 0),
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
        Size = UDim2.new(0, 60, 1, 0),
        ZIndex = 3,
        Parent = row,
    })
    if props.Color then
        value.TextColor3 = props.Color
    end

    local entry = { Frame = row, Label = label, Value = value, Avatar = avatar }
    table.insert(self.rows, entry)
    return entry
end

function Stats:Clear()
    for _, entry in ipairs(self.rows) do
        entry.Frame:Destroy()
    end
    table.clear(self.rows)
end

--[[
    Nearest players first, distance in studs.

    This used to Clear() and rebuild: every row destroyed and re-created once a
    second, eight instances apiece, each one firing off a yielding thumbnail
    request. Rows are kept and rewritten now, and the ones past the end of the
    list are hidden rather than destroyed — so a steady server costs a sort and a
    handful of string writes, and nothing is allocated at all.
]]
function Stats:Sync()
    local hrp = rootOf(lp)
    local found = self.scratch or {}
    self.scratch = found
    table.clear(found)

    for _, plr in ipairs(Players:GetPlayers()) do
        local other = rootOf(plr)
        local distance
        if plr == lp then
            distance = 0
        elseif hrp and other then
            distance = (other.Position - hrp.Position).Magnitude
        end
        if distance then
            table.insert(found, { player = plr, distance = distance })
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)

    local shown = math.min(#found, self.limit)
    for i = 1, shown do
        local hit = found[i]
        local mine = hit.player == lp
        local entry = self.rows[i]
        if not entry then
            entry = self:Row({ LayoutOrder = i })
        end
        entry.Frame.Visible = true

        local name = hit.player.DisplayName
        if entry.name ~= name then
            entry.name = name
            entry.Label.Text = name
        end

        local face = Util.thumbnail(hit.player.UserId)
        if entry.face ~= face then
            entry.face = face
            entry.Avatar.Image = face
        end

        local text = mine and "you" or string.format("%dm", math.floor(hit.distance + 0.5))
        if entry.text ~= text then
            entry.text = text
            entry.Value.Text = text
        end

        if entry.mine ~= mine then
            entry.mine = mine
            entry.Label.FontFace = mine and Theme.font.semi or Theme.font.medium
            Theme.rebind(entry.Label, "TextColor3", mine and "text" or "textDim")
            Theme.rebind(entry.Value, "TextColor3", mine and "accent" or "textFaint")
        end
    end

    for i = shown + 1, #self.rows do
        self.rows[i].Frame.Visible = false
    end
end

function Stats:SetVisible(state)
    self.Hidden = not state
    self.Frame.Visible = state and true or false
end

function Stats:Destroy()
    self.alive = false
    self.Frame:Destroy()
end

return Stats
end

__flowStartupCheckpoint()

end