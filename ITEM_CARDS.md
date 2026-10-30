# Item cards (shop / killer / perk tiles)

Flow now has a card for picking or buying things: a picture, a name, a line of
text, tags, a price and a button. Two pieces:

- `tab:Shelf(opts)`: a titled panel with a responsive grid of item cards
- `tab:Item(opts)`: one item card on its own, laid out like a module

```lua
local shelf = tab:Shelf({
    Name = "Killers", Icon = "skull",
    Columns = 3,        -- max columns; folds to fewer when the window is narrow
    MinWidth = 148,     -- narrowest a card may get before a column is dropped
    Single = true,      -- pick exactly one (radio). Leave off for a shop
    Desc = "Pick one.", -- optional line under the title
})

shelf:Item({
    Name = "The Trapper",
    Desc = "Sets bear traps.",
    Image = "rbxassetid://123",  -- id, number or url. Missing / fails to load -> Flow.DefaultImage
    Icon = "skull",              -- drawn instead when there is no Image
    Tag = "Killer",              -- chip, top left of the picture
    Badge = "NEW",               -- chip, top right
    Rarity = "epic",             -- common | uncommon | rare | epic | legendary | mythic, or a Color3
    Tags = { "Traps", "Slow" },  -- chips under the description
    Price = 1500,                -- number or text; 0 shows "Free"
    Currency = "coin",           -- icon name for the price, false for none
    Action = "Buy",              -- button text (false hides the button)
    ActionOn = "Equipped",       -- button text while selected
    Locked = false,              -- veil + lock; OnLocked fires when pressed
    Default = true,              -- starts selected (makes the card selectable)
    Flag = "killer_trapper",     -- saved / restored with configs, like any control
    Selectable = true,           -- toggle on press; false = plain button
    Callback = function(item) print(item.Name, item.Selected) end,
})
```

Item methods: `Set(bool)`, `Get()`, `SetName`, `SetDesc`, `SetImage`, `SetPrice`,
`SetLocked`, `SetBadge`, `SetTag`, `SetRarity`, `SetAction`, `Destroy`.
Shelf methods: `Item(opts)`, `Items(list)`, `Selected()`, `Clear()`, `SetTitle(text)`.

The tab search box filters items by name, description, tag, rarity and tags.
A tab that contains only shelves gives them the full width.

## Defaults

- `Flow.DefaultImage` = `rbxassetid://73763240772265`. Shown on any card without an Image.
- `Flow.Discord` = `https://discord.gg/G7FCTC2mEk`. Pass it as `Discord = Flow.Discord`
  to `window:Footer{...}` for the invite button.
- Add rarities: `Flow.Item.Rarities.cursed = Color3.fromRGB(...)`.

See the "Shop" tab in `TestSuite.lua` for a working example.
