--[[
    Flow UI — Full Component Test Suite
    6 tabs covering nearly every control, HUD widget, and window feature.
    Load Flow first, then run this file (or paste after loadstring).
]]

local Flow = rawget(_G, "Flow") or error("Flow not loaded — require/load Flow.lua first")

local ui = Flow.new({
    Accent = Color3.fromRGB(124, 92, 255),
    Key = Enum.KeyCode.RightControl,
    Folder = "flow-test",
    Scale = 1,
    Sound = true,
    Volume = 0.7,
})

local win = ui:Window({
    Title = "FLOW TEST",
    Build = "v1.0.0 · suite",
    Size = UDim2.fromOffset(960, 620),
    Columns = 2,
    MinColumns = 1,
    User = "Tester",
    Mark = "brand",
})

-- Optional footer
win:Footer({
    Credit = "Flow UI test suite",
    Emoji = "🧪",
    Discord = Flow.Discord,
})

---------------------------------------------------------------------------
-- HUD widgets (appear in Settings → Interface elements)
---------------------------------------------------------------------------
pcall(function()
    ui:Trigger({ Text = "FLOW", Mark = "brand" })
end)
pcall(function()
    ui:Watermark({ Name = "Tester", Tag = "DEV" })
end)
pcall(function()
    ui:Keybinds()
end)
pcall(function()
    ui:Stats({ Title = "Nearby", Limit = 5 })
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function toast(title, text, kind)
    ui:Notify({
        Title = title,
        Text = text or "",
        Icon = kind == "danger" and "alert" or kind == "success" and "check" or "info",
        Kind = kind or "info",
        Duration = 3.5,
    })
end

---------------------------------------------------------------------------
-- TAB 1 — Controls A (Toggle / Switch / Slider / Segmented)
---------------------------------------------------------------------------
local tab1 = win:Tab({ Name = "Controls A", Icon = "sliders" })

do
    local card = tab1:Module({
        Name = "Toggles & Switches",
        Icon = "power",
        Default = true,
        Expanded = true,
        Flag = "mod_toggles",
        Callback = function(on)
            toast("Toggles module", on and "enabled" or "disabled", on and "success" or "info")
        end,
    })

    card:Toggle({
        Name = "Master toggle",
        Desc = "Basic on/off with flag + callback",
        Default = true,
        Flag = "toggle_master",
        Callback = function(v)
            toast("Master toggle", tostring(v), v and "success" or "info")
        end,
    })

    card:Toggle({
        Name = "Silent flag",
        Desc = "No callback noise — value still stored",
        Default = false,
        Flag = "toggle_silent",
    })

    card:Toggle({
        Name = "Danger-ish option",
        Desc = "Just a second toggle for density",
        Default = false,
        Flag = "toggle_extra",
    })

    card:Divider()

    card:Label({ Name = "Standalone switch lives on the module header" })
end

do
    local card = tab1:Module({
        Name = "Sliders",
        Icon = "gauge",
        Default = true,
        Expanded = true,
        Flag = "mod_sliders",
    })

    card:Slider({
        Name = "Walk speed",
        Desc = "Integer range with suffix",
        Min = 0,
        Max = 100,
        Default = 16,
        Step = 1,
        Suffix = " studs",
        Flag = "slider_walk",
        Callback = function(v)
            -- live feedback only every few steps to avoid spam
        end,
    })

    card:Slider({
        Name = "Sensitivity",
        Desc = "Fine step (0.05)",
        Min = 0,
        Max = 2,
        Default = 0.5,
        Step = 0.05,
        Flag = "slider_sens",
    })

    card:Slider({
        Name = "Opacity",
        Min = 0,
        Max = 1,
        Default = 0.85,
        Step = 0.01,
        Suffix = "",
        Flag = "slider_opacity",
    })

    card:Slider({
        Name = "Wide range",
        Min = 0,
        Max = 2000,
        Default = 500,
        Step = 10,
        Flag = "slider_wide",
    })
end

do
    local card = tab1:Module({
        Name = "Segmented & Icon picker",
        Icon = "grid",
        Default = true,
        Expanded = true,
        Flag = "mod_segmented",
    })

    card:Segmented({
        Name = "Mode",
        Options = { "Smooth", "Snap", "Linear" },
        Default = "Smooth",
        Flag = "seg_mode",
        Callback = function(v)
            toast("Mode", v, "info")
        end,
    })

    card:Segmented({
        Name = "Target",
        Options = { "Players", "NPCs", "Both" },
        Default = "Players",
        Flag = "seg_target",
    })

    card:Icons({
        Name = "Hit style",
        Options = {
            { Icon = "target", Value = "crosshair", Name = "Crosshair" },
            { Icon = "swords", Value = "melee", Name = "Melee" },
            { Icon = "bolt", Value = "projectile", Name = "Projectile" },
            { Icon = "flame", Value = "aoe", Name = "AoE" },
        },
        Default = "crosshair",
        Flag = "icon_hit",
        Callback = function(v)
            toast("Hit style", tostring(v), "info")
        end,
    })
end

---------------------------------------------------------------------------
-- TAB 2 — Controls B (Dropdown / Multi / Buttons / Input)
---------------------------------------------------------------------------
local tab2 = win:Tab({ Name = "Controls B", Icon = "layers" })

do
    local card = tab2:Module({
        Name = "Dropdowns",
        Icon = "filter",
        Default = true,
        Expanded = true,
        Flag = "mod_dropdowns",
    })

    card:Dropdown({
        Name = "Primary weapon",
        Options = { "Sword", "Bow", "Staff", "Dagger", "Hammer", "Spear" },
        Default = "Sword",
        Flag = "dd_weapon",
        Callback = function(v)
            toast("Weapon", tostring(v), "info")
        end,
    })

    card:Dropdown({
        Name = "Multi select",
        Multi = true,
        Options = { "Head", "Torso", "Arms", "Legs", "Root" },
        Default = { Head = true, Torso = true },
        Empty = "None selected",
        MaxTags = 3,
        Flag = "dd_parts",
        Callback = function(v)
            local n = 0
            for _, on in pairs(v) do
                if on then
                    n = n + 1
                end
            end
            toast("Parts", n .. " selected", "info")
        end,
    })

    card:Dropdown({
        Name = "Empty list test",
        Options = {},
        Empty = "Nothing available",
        Flag = "dd_empty",
    })
end

do
    local card = tab2:Module({
        Name = "Buttons & Actions",
        Icon = "bolt",
        Default = true,
        Expanded = true,
        Flag = "mod_buttons",
    })

    card:Buttons({
        Name = "Quick actions",
        Buttons = {
            {
                Name = "Save",
                Icon = "check",
                Accent = true,
                Callback = function()
                    toast("Saved", "Config written", "success")
                end,
            },
            {
                Name = "Load",
                Icon = "folder",
                Callback = function()
                    toast("Loaded", "Config applied", "info")
                end,
            },
            {
                Name = "Reset",
                Icon = "refresh",
                Callback = function()
                    toast("Reset", "Defaults restored", "warning")
                end,
            },
        },
    })

    card:Button({
        Name = "Single accent button",
        Icon = "sparkle",
        Accent = true,
        Callback = function()
            toast("Clicked", "Single button fired", "success")
        end,
    })

    card:Button({
        Name = "Plain button",
        Icon = "cube",
        Callback = function()
            toast("Clicked", "Plain button", "info")
        end,
    })
end

do
    local card = tab2:Module({
        Name = "Text inputs",
        Icon = "code",
        Default = true,
        Expanded = true,
        Flag = "mod_inputs",
    })

    card:Input({
        Name = "Display name",
        Placeholder = "enter a name…",
        Default = "Tester",
        Flag = "input_name",
        Callback = function(text, enter)
            if enter then
                toast("Name committed", text, "success")
            end
        end,
    })

    card:Input({
        Name = "Webhook URL",
        Placeholder = "https://…",
        Default = "",
        Flag = "input_webhook",
    })

    card:Input({
        Name = "Command",
        Placeholder = "type a command",
        Default = "",
        OnEnter = true,
        Flag = "input_cmd",
        Callback = function(text)
            toast("Command", text ~= "" and text or "(empty)", "info")
        end,
    })
end

---------------------------------------------------------------------------
-- TAB 3 — Color / Keybind / Labels
---------------------------------------------------------------------------
local tab3 = win:Tab({ Name = "Color & Keys", Icon = "palette" })

do
    local card = tab3:Module({
        Name = "Color pickers",
        Icon = "palette",
        Default = true,
        Expanded = true,
        Flag = "mod_color",
    })

    card:Color({
        Name = "Accent override",
        Default = Color3.fromRGB(124, 92, 255),
        Flag = "color_accent",
        Callback = function(c)
            -- live preview of chosen color via toast title color not possible;
            -- just acknowledge
            toast("Accent", string.format("#%s", c:ToHex():upper()), "info")
        end,
    })

    card:Color({
        Name = "ESP box",
        Default = Color3.fromRGB(80, 205, 137),
        Flag = "color_esp",
    })

    card:Color({
        Name = "Tracer",
        Default = Color3.fromRGB(238, 108, 92),
        Flag = "color_tracer",
    })
end

do
    local card = tab3:Module({
        Name = "Keybinds",
        Icon = "keyboard",
        Default = true,
        Expanded = true,
        Keybind = Enum.KeyCode.X,
        BindMode = "Toggle",
        Flag = "mod_keys",
        Callback = function(on)
            toast("Keys module", on and "ON" or "OFF", on and "success" or "info")
        end,
    })

    card:Keybind({
        Name = "Panic key",
        Desc = "Right-click chip to clear / change mode",
        Default = Enum.KeyCode.P,
        Flag = "key_panic",
        OnPress = function()
            toast("Panic", "key pressed", "danger")
        end,
    })

    card:Keybind({
        Name = "Quick menu",
        Default = Enum.KeyCode.Q,
        Flag = "key_menu",
        OnPress = function()
            toast("Quick menu", "opened", "info")
        end,
    })

    card:Keybind({
        Name = "Unbound example",
        Default = nil,
        Flag = "key_empty",
    })

    card:Divider()

    card:Label({
        Name = "Hold vs Toggle",
        Desc = "Right-click any module keybind chip to switch behaviour between Toggle and Hold.",
    })
end

do
    local card = tab3:Module({
        Name = "Labels & Dividers",
        Icon = "info",
        Default = true,
        Expanded = true,
        Flag = "mod_labels",
    })

    card:Label({ Name = "Section header style" })
    card:Label({
        Name = "With description",
        Desc = "Labels can carry a short secondary line for context or warnings.",
    })
    card:Divider()
    card:Label({ Name = "After divider" })
    card:Label({
        Desc = "Description-only label (title row hidden when empty in some layouts).",
    })
end

---------------------------------------------------------------------------
-- TAB 4 — Dense / Mixed / Search targets
---------------------------------------------------------------------------
local tab4 = win:Tab({ Name = "Dense Mix", Icon = "grid" })

do
    local card = tab4:Module({
        Name = "Combat kit",
        Icon = "swords",
        Default = false,
        Expanded = true,
        Flag = "mod_combat",
        Keybind = Enum.KeyCode.C,
    })

    card:Toggle({ Name = "Silent aim", Default = false, Flag = "c_silent" })
    card:Toggle({ Name = "Triggerbot", Default = false, Flag = "c_trigger" })
    card:Slider({ Name = "FOV", Min = 10, Max = 360, Default = 90, Step = 1, Flag = "c_fov" })
    card:Slider({ Name = "Smoothness", Min = 0, Max = 1, Default = 0.35, Step = 0.01, Flag = "c_smooth" })
    card:Dropdown({
        Name = "Hit priority",
        Options = { "Closest", "Lowest HP", "Highest threat" },
        Default = "Closest",
        Flag = "c_priority",
    })
    card:Color({ Name = "FOV ring", Default = Color3.fromRGB(124, 92, 255), Flag = "c_fovcolor" })
end

do
    local card = tab4:Module({
        Name = "Movement",
        Icon = "chevrons-right",
        Default = false,
        Expanded = true,
        Flag = "mod_move",
        Keybind = Enum.KeyCode.V,
    })

    card:Toggle({ Name = "Speed", Default = false, Flag = "m_speed" })
    card:Slider({ Name = "Speed value", Min = 16, Max = 200, Default = 50, Step = 1, Flag = "m_speedval" })
    card:Toggle({ Name = "Jump power", Default = false, Flag = "m_jump" })
    card:Slider({ Name = "Jump value", Min = 50, Max = 300, Default = 50, Step = 5, Flag = "m_jumpval" })
    card:Toggle({ Name = "Fly", Default = false, Flag = "m_fly" })
    card:Toggle({ Name = "Noclip", Default = false, Flag = "m_noclip" })
    card:Segmented({
        Name = "Fly mode",
        Options = { "CFrame", "Velocity", "BodyMover" },
        Default = "CFrame",
        Flag = "m_flymode",
    })
end

do
    local card = tab4:Module({
        Name = "Visuals",
        Icon = "eye",
        Default = true,
        Expanded = false,
        Flag = "mod_visuals",
    })

    card:Toggle({ Name = "ESP boxes", Default = true, Flag = "v_boxes" })
    card:Toggle({ Name = "Nametags", Default = true, Flag = "v_names" })
    card:Toggle({ Name = "Tracers", Default = false, Flag = "v_tracers" })
    card:Toggle({ Name = "Chams", Default = false, Flag = "v_chams" })
    card:Color({ Name = "Enemy", Default = Color3.fromRGB(238, 92, 100), Flag = "v_enemy" })
    card:Color({ Name = "Team", Default = Color3.fromRGB(72, 205, 141), Flag = "v_team" })
    card:Slider({ Name = "Max distance", Min = 50, Max = 2000, Default = 500, Step = 25, Flag = "v_dist" })
end

do
    local card = tab4:Module({
        Name = "World",
        Icon = "orbit",
        Default = false,
        Expanded = false,
        Flag = "mod_world",
    })

    card:Toggle({ Name = "Fullbright", Default = false, Flag = "w_fb" })
    card:Toggle({ Name = "No fog", Default = false, Flag = "w_fog" })
    card:Slider({ Name = "Time of day", Min = 0, Max = 24, Default = 12, Step = 0.5, Flag = "w_time" })
    card:Input({ Name = "Teleport to", Placeholder = "player name", Flag = "w_tp" })
    card:Button({
        Name = "Server hop",
        Icon = "link",
        Callback = function()
            toast("Server hop", "Would hop now", "info")
        end,
    })
end

---------------------------------------------------------------------------
-- TAB 5 — Edge cases / Notifications / Flags
---------------------------------------------------------------------------
local tab5 = win:Tab({ Name = "Edge cases", Icon = "flask" })

do
    local card = tab5:Module({
        Name = "Notifications",
        Icon = "bell",
        Default = true,
        Expanded = true,
        Flag = "mod_notify",
    })

    card:Buttons({
        Buttons = {
            {
                Name = "Info",
                Icon = "info",
                Callback = function()
                    toast("Info toast", "Neutral information message", "info")
                end,
            },
            {
                Name = "Success",
                Icon = "check",
                Accent = true,
                Callback = function()
                    toast("Success", "Action completed cleanly", "success")
                end,
            },
            {
                Name = "Warning",
                Icon = "alert",
                Callback = function()
                    toast("Warning", "Something needs attention", "warning")
                end,
            },
            {
                Name = "Danger",
                Icon = "ban",
                Callback = function()
                    toast("Danger", "Destructive or failed action", "danger")
                end,
            },
        },
    })

    card:Button({
        Name = "Long duration toast",
        Callback = function()
            ui:Notify({
                Title = "Long message",
                Text = "This stays for 8 seconds so you can hover and read it. Hover pauses the countdown.",
                Icon = "clock",
                Kind = "info",
                Duration = 8,
            })
        end,
    })
end

do
    local card = tab5:Module({
        Name = "Flag inspection",
        Icon = "code",
        Default = true,
        Expanded = true,
        Flag = "mod_flags",
    })

    card:Button({
        Name = "Print all flags to console",
        Icon = "terminal",
        Callback = function()
            local State = Flow.State or (ui.State)
            if State and State.flags then
                print("── Flow flags ──")
                for k, v in pairs(State.flags) do
                    print(k, typeof(v) == "Color3" and v:ToHex() or tostring(v))
                end
                toast("Flags", "Dumped to console", "success")
            else
                toast("Flags", "State not exposed", "warning")
            end
        end,
    })

    card:Button({
        Name = "Save config “testsuite”",
        Icon = "check",
        Accent = true,
        Callback = function()
            local ok, err = (Flow.State or ui.State).save("testsuite", ui.layout and ui:layout() or nil)
            toast(ok and "Saved" or "Save failed", ok and "testsuite" or tostring(err), ok and "success" or "danger")
        end,
    })

    card:Button({
        Name = "Load config “testsuite”",
        Icon = "folder",
        Callback = function()
            local ok, data = (Flow.State or ui.State).load("testsuite")
            if ok and ui.restore then
                ui:restore(data)
            end
            toast(ok and "Loaded" or "Load failed", ok and "testsuite" or tostring(data), ok and "success" or "danger")
        end,
    })
end

do
    local card = tab5:Module({
        Name = "Layout & window",
        Icon = "expand",
        Default = true,
        Expanded = true,
        Flag = "mod_layout",
    })

    card:Label({
        Name = "Tips",
        Desc = "• Drag the header to move the window\n• Search box filters modules by name\n• Gear opens settings (accent, scale, keybind, HUD, sound, configs)\n• Bell opens notification history\n• Account chip opens profile / unload",
    })

    card:Button({
        Name = "Toggle window",
        Icon = "eye",
        Callback = function()
            win:Toggle()
        end,
    })

    card:Button({
        Name = "Unload library",
        Icon = "logout",
        Callback = function()
            toast("Unload", "Destroying in 1s…", "warning")
            task.delay(1, function()
                ui:Unload()
            end)
        end,
    })
end

---------------------------------------------------------------------------
-- Tab 6: Shop (item cards)
---------------------------------------------------------------------------
local tab6 = win:Tab({ Name = "Shop", Icon = "tag" })

do
    -- Single = true: pick exactly one, like choosing a killer
    local killers = tab6:Shelf({
        Name = "Killers",
        Icon = "skull",
        Desc = "Pick one. Cards fold to fewer columns when the window is narrow.",
        Columns = 3,
        Single = true,
    })

    killers:Item({
        Name = "The Trapper",
        Desc = "Sets bear traps around the map.",
        Tag = "Killer",
        Rarity = "epic",
        Tags = { "Traps", "Slow" },
        Default = true,
        Flag = "shop_killer_trapper",
        Callback = function(item)
            toast(item.Name, item.Selected and "Selected" or "Cleared", "info")
        end,
    })
    killers:Item({
        Name = "The Wraith",
        Desc = "Cloaks to move unseen.",
        Tag = "Killer",
        Rarity = "rare",
        Badge = "NEW",
        Callback = function(item)
            toast(item.Name, "Selected", "info")
        end,
    })
    killers:Item({
        Name = "The Nightmare",
        Desc = "Not unlocked yet.",
        Tag = "Killer",
        Rarity = "legendary",
        Price = 2500,
        Locked = true,
        OnLocked = function(item)
            toast(item.Name, "Locked. Reach level 30 first", "warning")
        end,
    })

    -- no Single: each card is its own button (a shop)
    local perks = tab6:Shelf({
        Name = "Perks",
        Icon = "star",
        Columns = 4,
        MinWidth = 130,
    })

    local owned = 0
    for i, perk in ipairs({
        { "Sprint Burst", "Run faster for a short time.", "common", 300 },
        { "Iron Will", "Stay quiet when injured.", "uncommon", 650 },
        { "Dead Hard", "Dash through a hit.", "rare", 1200 },
        { "Unbreakable", "Recover from downed once.", "epic", 2400 },
    }) do
        perks:Item({
            Name = perk[1],
            Desc = perk[2],
            Rarity = perk[3],
            Tag = "Perk",
            Price = perk[4],
            Icon = "shield", -- shown instead of a picture when no Image is given
            Callback = function(item)
                if item.bought then
                    return
                end
                item.bought = true
                owned = owned + 1
                item:SetAction("Owned")
                item:SetPrice(nil)
                toast("Purchased", item.Name .. " (" .. owned .. " owned)", "success")
            end,
        })
    end
end

-- Select first tab
win:Select(tab1)

toast("Test suite ready", "6 tabs · almost every control", "success")

return {
    Flow = Flow,
    ui = ui,
    win = win,
    tabs = { tab1, tab2, tab3, tab4, tab5, tab6 },
}
