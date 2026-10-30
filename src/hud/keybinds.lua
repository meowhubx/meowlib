return function(__modules, __service, __flowStartupCheckpoint)
__modules["hud/keybinds"] = function(require)
__flowStartupCheckpoint()
local Util = require("core/util")
local Theme = require("core/theme")
local Panel = require("hud/panel")

local Keybinds = {}
Keybinds.__index = Keybinds

function Keybinds.new(props)
    local self = setmetatable({}, Keybinds)
    self.panel = Panel.new({
        Title = props.Title or "Keybinds",
        Icon = "keyboard",
        Width = props.Width or 212,
        Position = props.Position or UDim2.fromOffset(18, 300),
        AnchorPoint = props.AnchorPoint,
        Parent = props.Parent,
        OnMove = props.OnMove,
    })
    self.Frame = self.panel.Frame
    self.source = props.Modules or {}
    self.binds = props.Binds or {}
    self:Sync()
    return self
end

function Keybinds:Sync()
    self.panel:Clear()
    local shown = 0
    for _, card in ipairs(self.source) do
        if card.Bind then
            shown = shown + 1
            self.panel:Row({
                Name = card.Name,
                Icon = card.Icon,
                Value = Util.keyName(card.Bind),
                Color = card.Enabled and Theme.get("accent") or Theme.get("textFaint"),
                LayoutOrder = shown,
            })
        end
    end

    -- a keybind added as a control rather than on a module header still belongs
    -- on this list; without it a script's binds are invisible
    for _, entry in ipairs(self.binds) do
        local key = entry.Control and entry.Control.Value or entry.Bind
        if key then
            shown = shown + 1
            self.panel:Row({
                Name = entry.Name,
                Icon = entry.Icon,
                Value = Util.keyName(key),
                Color = Theme.get("accent"),
                LayoutOrder = shown,
            })
        end
    end

    self.Frame.Visible = shown > 0 and not self.Hidden
end

function Keybinds:SetVisible(state)
    self.Hidden = not state
    self:Sync()
end

return Keybinds
end

__flowStartupCheckpoint()

end