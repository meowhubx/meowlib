return function(__modules, __service, __flowStartupCheckpoint)
__modules["ui/legacy"] = function(require)
__flowStartupCheckpoint()
local Luarmor = require("core/luarmor")

return function(Flow)
    local Compat = {}
    Compat.Flow = Flow

    -- the old library exposed these at its top level and scripts reach for them
    -- directly (`Library.Icons` and friends), so mirror them rather than
    -- handing back nil
    Compat.Version = Flow.Version
    Compat.Icons = Flow.Icons
    Compat.Theme = Flow.Theme
    Compat.Util = Flow.Util
    Compat.State = Flow.State
    Compat.Audio = Flow.Audio
    Compat.Luarmor = Flow.Luarmor
    Compat.Controls = Flow.Controls
    Compat.Protected = Flow.Protected

    -- background pollers started for dropdown auto-refresh, stopped on unload
    local refreshers = {}

    local function stopRefreshers()
        for i = #refreshers, 1, -1 do
            refreshers[i].alive = false
            refreshers[i] = nil
        end
    end

    local function schedule(interval, fn)
        local handle = { alive = true }
        table.insert(refreshers, handle)
        task.spawn(function()
            while handle.alive do
                task.wait(interval)
                if not handle.alive then
                    return
                end
                pcall(fn)
            end
        end)
        return handle
    end

    -- old scripts pass bare numeric asset ids in a few places
    local function icon(...)
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if type(value) == "number" then
                return "rbxassetid://" .. tostring(value)
            end
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
        return nil
    end

    -- `:Get()` and friends that the old control objects exposed
    local function augment(control)
        if type(control) ~= "table" then
            return control
        end
        if not control.Get then
            function control:Get()
                return self.Value
            end
        end
        if control.Options and not control.UpdateOptions then
            control.UpdateOptions = control.Options
            control.SetOptions = control.Options
            control.SetValues = control.Options

            --[[
                Scripts probe for whichever of these the old library happened to
                expose, in their own order:

                    if type(d.Refresh) == "function" then d:Refresh(list)
                    elseif type(d.SetOptions) == "function" then ...

                A no-op Refresh satisfies the first branch and swallows the
                update, leaving the list empty with nothing raised. So every name
                a script might reach for has to actually do the work.
            ]]
            function control:Refresh(list)
                if type(list) == "table" then
                    self:Options(list)
                elseif self.Pull then
                    self:Pull()
                end
            end

            -- and the rebuild-one-at-a-time shape
            function control:Clear()
                self.staged = {}
                self:Options({})
            end

            function control:Add(item)
                self.staged = self.staged or {}
                table.insert(self.staged, item)
                self:Options(self.staged)
            end
        end
        if not control.Refresh then
            -- a toggle or slider has nothing to refresh; keep the call safe
            function control:Refresh() end
        end
        return control
    end

    local function labelText(control, text)
        local head = control and control.Frame and control.Frame:FindFirstChild("Head")
        if not head then
            return
        end
        local desc = head:FindFirstChild("Desc")
        local title = head:FindFirstChild("Title")
        local target = (desc and desc.Text ~= "" and desc) or title or desc
        if target then
            target.Text = tostring(text)
        end
    end

    -- -----------------------------------------------------------------------
    -- Group  ->  Module card
    -- -----------------------------------------------------------------------

    local Group = {}
    Group.__index = Group

    function Group.new(card)
        return setmetatable({ card = card, Frame = card.Frame, Card = card }, Group)
    end

    function Group:AddToggle(opts)
        opts = opts or {}
        return augment(self.card:Toggle({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    function Group:AddSlider(opts)
        opts = opts or {}
        -- the slider derives its decimal places from the step, so `Decimals`
        -- only matters when it is finer than the increment
        local step = opts.Increment or opts.Step
        if opts.Decimals and opts.Decimals > 0 then
            local fromDecimals = 10 ^ -opts.Decimals
            if not step or step > fromDecimals then
                step = step or fromDecimals
            end
        end
        return augment(self.card:Slider({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Min = opts.Min,
            Max = opts.Max,
            Default = opts.Default,
            Step = step,
            Suffix = opts.Suffix,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    local function buildDropdown(self, opts, multi)
        opts = opts or {}
        local list = opts.Options
        if not list and type(opts.OptionsProvider) == "function" then
            local ok, provided = pcall(opts.OptionsProvider)
            list = (ok and type(provided) == "table") and provided or {}
        end

        local control = self.card:Dropdown({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Options = list or {},
            Default = opts.Default,
            Multi = multi,
            Empty = opts.Empty,
            Flag = opts.Flag,
            Callback = opts.Callback,
        })

        -- the old library refreshed dropdown contents from a provider on a timer
        if type(opts.OptionsProvider) == "function" then
            local function flatten(values)
                local flat = {}
                for _, v in ipairs(values or {}) do
                    flat[#flat + 1] = tostring(v)
                end
                return table.concat(flat, "\0")
            end
            local last = flatten(list)
            local function pull()
                local ok, provided = pcall(opts.OptionsProvider)
                if not ok or type(provided) ~= "table" then
                    return
                end
                local key = flatten(provided)
                if key ~= last then
                    last = key
                    control:Options(provided)
                end
            end
            if opts.AutoRefresh then
                control.refresher = schedule(tonumber(opts.RefreshInterval) or 5, pull)
            end
            control.Pull = pull
        end

        return augment(control)
    end

    function Group:AddDropdown(opts)
        return buildDropdown(self, opts, false)
    end

    function Group:AddMultiDropdown(opts)
        return buildDropdown(self, opts, true)
    end

    function Group:AddButton(opts)
        opts = opts or {}
        return augment(self.card:Button({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Icon = icon(opts.Icon),
            Accent = opts.Accent,
            Callback = opts.Callback,
        }))
    end

    function Group:AddLabel(opts)
        if type(opts) == "string" then
            opts = { Text = opts }
        end
        opts = opts or {}
        local text = opts.Text or opts.Name or ""
        local control = self.card:Label(opts.Wrap and { Desc = text } or { Name = text })
        control.Wrapped = opts.Wrap and true or false

        -- Craft.head always lays out a 17px title row; on a wrapped label that
        -- row is empty and would sit as a blank gap above the body copy
        if control.Wrapped then
            local head = control.Frame and control.Frame:FindFirstChild("Head")
            local title = head and head:FindFirstChild("Title")
            if title and title.Text == "" then
                title.Visible = false
            end
        end

        function control:SetText(value)
            labelText(self, value)
        end
        control.Set = control.SetText
        return control
    end

    function Group:AddDivider()
        return self.card:Divider()
    end

    function Group:AddKeybind(opts)
        opts = opts or {}
        local flow = self.card.flow
        -- old: Callback fires on press, ChangedCallback fires on rebind.
        -- new: OnPress fires on press, Callback fires on rebind.
        local control = self.card:Keybind({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Flag = opts.Flag,
            OnPress = opts.Callback,
            Callback = function(key)
                -- keep the Keybinds panel in step with a rebind
                if flow.hud and flow.hud.keybinds then
                    flow.hud.keybinds:Sync()
                end
                if opts.ChangedCallback then
                    opts.ChangedCallback(key)
                end
            end,
        })
        control.Mode = opts.Mode or "Toggle"

        -- list it on the Keybinds panel; a module header bind lands there
        -- automatically, a control one has to be registered
        table.insert(flow.binds, {
            Name = opts.Name or self.Name or "Keybind",
            Icon = icon(opts.Icon, self.Icon, "keyboard"),
            Control = control,
        })
        if flow.hud and flow.hud.keybinds then
            flow.hud.keybinds:Sync()
        end

        return augment(control)
    end

    function Group:AddColorPicker(opts)
        opts = opts or {}
        return augment(self.card:Color({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Default = opts.Default,
            Presets = opts.Presets,
            Flag = opts.Flag,
            Callback = opts.Callback,
        }))
    end

    local function buildInput(self, opts)
        opts = opts or {}
        return augment(self.card:Input({
            Name = opts.Name,
            Desc = opts.Desc or opts.Description,
            Placeholder = opts.Placeholder,
            Default = opts.Default,
            Flag = opts.Flag,
            -- old `EnterOnly` means "only fire once the user commits with return"
            OnEnter = opts.EnterOnly and true or nil,
            Callback = opts.Callback,
        }))
    end

    function Group:AddTextInput(opts)
        return buildInput(self, opts)
    end

    function Group:AddTextbox(opts)
        return buildInput(self, opts)
    end

    function Group:AddInput(opts)
        return buildInput(self, opts)
    end

    -- a few scripts nest named pages inside a group. There is no level below a
    -- card, so each page becomes its own sibling card titled "<Group> · <Page>",
    -- keeping the controls grouped and in the same column.
    function Group:AddTabs(names)
        local pages = {}
        for _, name in ipairs(names or {}) do
            pages[name] = self.tab:AddGroup({
                Name = self.Name and (self.Name .. " · " .. name) or name,
                Side = self.Side,
                Icon = self.Icon,
            })
        end
        return pages
    end

    function Group:Set(state)
        self.card:Set(state)
    end

    function Group:Destroy()
        self.card.Frame:Destroy()
    end

    -- -----------------------------------------------------------------------
    -- Tab
    -- -----------------------------------------------------------------------

    local Tab = {}
    Tab.__index = Tab

    function Tab.new(tab, sectionIcon)
        return setmetatable({ tab = tab, Frame = tab.Frame, sectionIcon = sectionIcon }, Tab)
    end

    function Tab:AddGroup(opts)
        if type(opts) == "string" then
            opts = { Name = opts }
        end
        opts = opts or {}

        local card = self.tab:Module({
            Name = opts.Name or "Group",
            Icon = icon(opts.Icon, opts.FallbackIcon, self.sectionIcon, "cube"),
            Column = (opts.Side == "Right") and 2 or 1,
            Default = true,
            Expanded = true,
        })

        -- an old Group is a plain container: no switch, no keybind chip, and it
        -- can never be turned off from the header
        if card.Switch and card.Switch.Frame then
            card.Switch.Frame.Visible = false
        end
        if card.BindControl and card.BindControl.Frame then
            card.BindControl.Frame.Visible = false
        end
        card.Enabled = true

        local group = Group.new(card)
        group.Name = opts.Name
        group.Side = opts.Side
        group.Icon = opts.Icon
        group.tab = self
        return group
    end

    function Tab:Select()
        self.tab.window:Select(self.tab)
    end

    -- -----------------------------------------------------------------------
    -- Section — collapses away; only its icon survives as a per-tab fallback
    -- -----------------------------------------------------------------------

    local Section = {}
    Section.__index = Section

    function Section.new(window, opts)
        return setmetatable({
            window = window,
            Name = opts.Name or opts.Title,
            Icon = icon(opts.Icon, opts.FallbackIcon),
        }, Section)
    end

    function Section:AddTab(opts)
        opts = opts or {}
        local name = opts.Name or "Tab"

        -- two sections can each own a tab called "Main"; with the section level
        -- gone those would collide in one strip, so the section name splits them
        local taken = self.window.tabNames
        if taken[name] and self.Name then
            name = self.Name .. " · " .. name
        end
        taken[name] = true

        local tab = self.window.win:Tab({
            Name = name,
            Icon = icon(opts.Icon, opts.FallbackIcon, self.Icon, "cube"),
        })

        -- `Description` was a subtitle under the old tab name. The strip is a
        -- single row of labelled buttons with nowhere to put it, and Tab carries
        -- no search terms of its own, so it is dropped rather than faked.

        local proxy = Tab.new(tab, self.Icon)
        if opts.Default then
            self.window.win:Select(tab)
        end
        return proxy
    end

    -- -----------------------------------------------------------------------
    -- Window — what Library.new() returned
    --
    -- The old library table *was* the window class: scripts called
    -- `Library.new(...)` and the result answered `:CreateSection`, `:Notify`
    -- and `:Destroy`. Some scripts validate the download by checking for those
    -- very fields, so Compat is the class rather than a separate table.
    -- -----------------------------------------------------------------------

    Compat.__index = Compat

    function Compat.new(opts)
        opts = opts or {}

        local ui = Flow.new({
            Accent = opts.AccentColor,
            Key = opts.ToggleKey,
            Folder = opts.Folder or "flow",
            Scale = opts.Scale,
            Sound = opts.Sound,
            Volume = opts.Volume,
        })

        -- the old library previewed a key state through its own options
        if opts.LuarmorSecondsLeft then
            Luarmor.override = { SecondsLeft = opts.LuarmorSecondsLeft }
        end

        local title = opts.Name or opts.Title or "FLOW"

        local win = ui:Window({
            Title = title,
            Build = opts.Subtitle or opts.Build,
            Size = opts.Size,
            -- old groups pick a side, so two lanes reproduce that exactly
            Columns = opts.Columns or 2,
            MinColumns = opts.MinColumns or 1,
            User = opts.User,
            Mark = opts.Mark,
        })

        --[[
            The old library built a status pill at top centre on its own — script
            name, ping and fps, doubling as the menu toggle. HUD widgets are
            opt-in here, so a converted script would come up with none at all and
            "No HUD widgets loaded" under Interface elements.

            Trigger is that top-centre toggle; Watermark carries the ping/fps
            readout the old pill showed alongside it. Both appear as switches in
            settings, so anyone who does not want them can turn them off, and the
            choice is saved with the config.
        ]]
        if opts.Hud ~= false then
            pcall(function()
                ui:Trigger({ Text = title })
            end)
            pcall(function()
                ui:Watermark({ Name = opts.User, Tag = opts.Tag })
            end)
            pcall(function()
                ui:Keybinds()
            end)
        end

        return setmetatable({
            ui = ui,
            win = win,
            Flow = Flow,
            Options = ui.Options,
            tabNames = {},
        }, Compat)
    end

    function Compat:CreateSection(opts)
        if type(opts) == "string" then
            opts = { Name = opts }
        end
        return Section.new(self, opts or {})
    end

    function Compat:SetToggleKey(key)
        self.ui.menuKey = key
        return self
    end

    function Compat:Notify(opts)
        opts = opts or {}
        return self.ui:Notify({
            Title = opts.Title,
            Text = opts.Description or opts.Content or opts.Text or opts.SubText,
            Icon = icon(opts.Icon),
            Kind = opts.Kind,
            Duration = opts.Duration,
        })
    end

    function Compat:SetAccentColor(color)
        self.ui:SetAccent(color)
    end

    function Compat:Toggle(state)
        self.ui:ToggleMenu(state)
    end

    function Compat:Get(flag)
        return self.ui:Get(flag)
    end

    function Compat:Set(flag, value)
        return self.ui:Set(flag, value)
    end

    function Compat:Destroy()
        stopRefreshers()
        self.ui:Unload()
    end

    Compat.Unload = Compat.Destroy

    -- callable as both Legacy.new{...} and Legacy{...}
    setmetatable(Compat, {
        __call = function(_, opts)
            return Compat.new(opts)
        end,
    })

    return Compat
end
end

end