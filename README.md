# murderface-pets

Pet companion system for FiveM (Qbox framework). Players can buy, customize, and interact with animal companions. Includes an XP/leveling system, hunger/thirst needs, K9 police functionality, and database backup persistence.

## Dependencies

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

### 1. Database

Run the SQL file against your database **before** starting the resource:

```sql
source sql/install.sql
```

Or paste the contents of `sql/install.sql` into your database manager. This creates the `murderface_pets` backup table.

### 2. Add items to ox_inventory

Open `ox_inventory/data/items.lua` and paste the following block inside the `return { }` table. Pet items use `stack = false` because each pet carries unique metadata (name, level, XP, health, coat, etc). Supply items stack normally.

```lua
	-- ========================================
	--  murderface-pets: Pet Items
	--  consume = 0: usable but not consumed on use
	--  server.export: links to murderface-pets resource handler
	-- ========================================

	['murderface_husky'] = {
		label = 'Husky',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A loyal Husky companion',
		server = { export = 'murderface-pets.murderface_husky' },
	},

	['murderface_shepherd'] = {
		label = 'German Shepherd',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A brave German Shepherd companion',
		server = { export = 'murderface-pets.murderface_shepherd' },
	},

	['murderface_rottweiler'] = {
		label = 'Rottweiler',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A powerful Rottweiler companion',
		server = { export = 'murderface-pets.murderface_rottweiler' },
	},

	['murderface_retriever'] = {
		label = 'Golden Retriever',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A friendly Golden Retriever companion',
		server = { export = 'murderface-pets.murderface_retriever' },
	},

	['murderface_chop'] = {
		label = 'Chop',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A tough old dog with character',
		server = { export = 'murderface-pets.murderface_chop' },
	},

	['murderface_westy'] = {
		label = 'Westie',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A spirited West Highland Terrier companion',
		server = { export = 'murderface-pets.murderface_westy' },
	},

	['murderface_pug'] = {
		label = 'Pug',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'An adorable Pug companion',
		server = { export = 'murderface-pets.murderface_pug' },
	},

	['murderface_poodle'] = {
		label = 'Poodle',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'An elegant Poodle companion',
		server = { export = 'murderface-pets.murderface_poodle' },
	},

	['murderface_cat'] = {
		label = 'House Cat',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'An independent feline companion',
		server = { export = 'murderface-pets.murderface_cat' },
	},

	['murderface_panther'] = {
		label = 'Black Panther',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A sleek and dangerous Black Panther',
		server = { export = 'murderface-pets.murderface_panther' },
	},

	['murderface_mtlion'] = {
		label = 'Mountain Lion',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A fierce Mountain Lion companion',
		server = { export = 'murderface-pets.murderface_mtlion' },
	},

	['murderface_coyote'] = {
		label = 'Coyote',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A cunning Coyote companion',
		server = { export = 'murderface-pets.murderface_coyote' },
	},

	['murderface_hen'] = {
		label = 'Chicken',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A trusty Chicken companion',
		server = { export = 'murderface-pets.murderface_hen' },
	},

	['murderface_rabbit'] = {
		label = 'Rabbit',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A fluffy Rabbit companion',
		server = { export = 'murderface-pets.murderface_rabbit' },
	},

	['murderface_chimp'] = {
		label = 'Chimpanzee',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A clever Chimpanzee companion (build 3258+)',
		server = { export = 'murderface-pets.murderface_chimp' },
	},

	['murderface_rhesus'] = {
		label = 'Rhesus Monkey',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A mischievous Rhesus Monkey companion (build 3258+)',
		server = { export = 'murderface-pets.murderface_rhesus' },
	},

	-- ========================================
	--  murderface-pets: Supply Items
	--  consume = 0: usable but not consumed (resource handles removal)
	-- ========================================

	['murderface_food'] = {
		label = 'Pet Food',
		weight = 200,
		consume = 0,
		description = 'Nutritious food for your pet',
		server = { export = 'murderface-pets.murderface_food' },
	},

	['murderface_firstaid'] = {
		label = 'Pet First Aid',
		weight = 300,
		consume = 0,
		description = 'Heals or revives your pet (use via 3rd eye)',
		server = { export = 'murderface-pets.murderface_firstaid' },
	},

	['murderface_waterbottle'] = {
		label = 'Water Bottle',
		weight = 500,
		consume = 0,
		description = 'Refillable water bottle for your pet',
		server = { export = 'murderface-pets.murderface_waterbottle' },
	},

	['murderface_collar'] = {
		label = 'Pet Collar',
		weight = 100,
		consume = 0,
		description = 'Transfer pet ownership to another player',
		server = { export = 'murderface-pets.murderface_collar' },
	},

	['murderface_nametag'] = {
		label = 'Pet Nametag',
		weight = 50,
		consume = 0,
		description = 'Rename your pet companion',
		server = { export = 'murderface-pets.murderface_nametag' },
	},

	['murderface_groomingkit'] = {
		label = 'Grooming Kit',
		weight = 400,
		consume = 0,
		description = 'Change your pet\'s coat and appearance',
		server = { export = 'murderface-pets.murderface_groomingkit' },
	},
```

### 3. Inventory images

Copy all `.png` files from the `inventory_images/` folder into your ox_inventory web images directory (typically `ox_inventory/web/images/`). All 22 images (16 pets + 6 supplies) are included.

### 4. Start the resource

Add to your `server.cfg`:

```
ensure murderface-pets
```

Make sure it starts **after** all dependencies (qbx_core, ox_lib, ox_inventory, ox_target, oxmysql).

### 5. Game build requirement

The chimpanzee (`a_c_chimp_02`) and rhesus monkey (`a_c_rhesus`) models require **build 3258+**. If your server runs a lower build, remove those two entries from `Config.pets` in `config.lua`.

## Features

### Pets (16 animals)

| Animal | Model | Animations | Special |
|--------|-------|-----------|---------|
| Husky | A_C_Husky | Sit, sleep, bark, tricks, petting | Can hunt |
| German Shepherd | A_C_shepherd | Sit, sleep, bark, tricks, petting | Can hunt, K9 eligible |
| Rottweiler | A_C_Rottweiler | Sit, sleep, bark, tricks, petting | Can hunt, K9 eligible |
| Golden Retriever | A_C_Retriever | Sit, sleep, bark, tricks, petting | Can hunt |
| Chop | a_c_chop_02 | Sit, sleep, bark, tricks, petting | Can hunt |
| Westie | A_C_Westy | Sit, sleep, tricks, petting | - |
| Pug | A_C_Pug | Sit, sleep, tricks, petting | - |
| Poodle | A_C_Poodle | Sit, sleep, tricks, petting | - |
| House Cat | A_C_Cat_01 | Sit, sleep, petting | - |
| Black Panther | A_C_Panther | Sit, sleep | Can hunt |
| Mountain Lion | A_C_MtLion | Sit, sleep | Can hunt |
| Coyote | A_C_Coyote | Sit, sleep | Can hunt |
| Chicken | A_C_Hen | Basic idle | - |
| Rabbit | A_C_Rabbit_01 | Basic idle | - |
| Chimpanzee | a_c_chimp_02 | Sit, sleep | Build 3258+ |
| Rhesus Monkey | a_c_rhesus | Sit, sleep | Build 3258+ |

### Player interactions

- **Spawn/despawn** pets from inventory (up to 2 active at once)
- **Feed** and **water** your pet to keep it healthy
- **Heal** or **revive** with first aid kits (via ox_target)
- **Rename** with nametag items
- **Groom** to change coat/variation with grooming kits
- **Transfer ownership** with collar items
- **Command menu** (default: `O` key) with actions like follow, wait, sit, tricks, hunt, go there, get in car
- **Petting** animation (ox_target interaction)
- **XP and leveling** system (max level 50) — pets gain XP passively while spawned

### K9 system

Police officers (configurable job list) with K9-eligible pets can:
- **Search players** for illegal items
- **Search vehicles** for contraband

### Pet shop

An NPC pet shop and supply shop are included. Edit coordinates and pricing in `config.lua` under `Config.petShop` and `Config.suppliesShop`.

### Database backup

Pet metadata is automatically backed up to the `murderface_pets` MySQL table on every save. This provides a safety net if ox_inventory items are lost. Admin restore command: `/petrestore [citizenid] [hash]`.

## Configuration

All settings are in `config.lua` with inline comments. Key sections:

| Section | What it controls |
|---------|-----------------|
| `Config.maxActivePets` | Max simultaneously spawned pets (default: 2) |
| `Config.petMenuKeybind` | Key to open companion menu (default: `o`) |
| `Config.balance` | XP rates, food/thirst drain, AFK timers |
| `Config.items` | Item names, durations, heal percentages |
| `Config.k9` | Eligible jobs, illegal item list for searches |
| `Config.petShop` | Shop NPC model, coords, blip settings |
| `Config.suppliesShop` | Supply shop NPC model, coords, blip settings |
| `Config.stressRelief` | Stress reduction from petting (for HUD scripts) |
| `Config.blip` | Map blip settings for active pets |

## Developer notes

### ox_inventory export signature — no `_` placeholder

ox_inventory's `useExport` wrapper (`modules/items/shared.lua`) prepends a `nil` argument when calling item exports:

```lua
-- ox_inventory source (DO NOT rely on this nil arriving)
return exports[resource][export](nil, ...)
```

**FiveM's cross-resource export marshaling drops leading `nil` arguments.** The `nil` never reaches the target function. All export handlers must use the direct signature:

```lua
-- CORRECT — arguments arrive as (event, item, inventory, slot)
local function handler(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    -- ...
    return false  -- prevent consumption
end
exports('item_name', handler)
```

```lua
-- WRONG — nil is dropped, shifts all args by one position
-- event receives the item table, item receives inventory, etc.
-- The guard `event ~= 'usingItem'` silently aborts every use.
local function handler(_, event, item, inventory, slot)
```

This applies to **any** resource using `server = { export = 'resource.item' }` in ox_inventory `data/items.lua`. The ox_inventory docs and source code suggest the `_` placeholder is needed, but in practice it breaks the handler.

### consume = 0

Pet items use `consume = 0` in their ox_inventory item definitions. In Lua, `0` is truthy (unlike JavaScript), so ox_inventory enters the consume branch but the handler returns `false` to prevent the item from being removed. This keeps the pet item in the player's inventory after use.

### Startup diagnostics

`server/server.lua` includes a startup diagnostic thread that runs 5 seconds after boot. It queries `exports.ox_inventory:Items()` to verify ox_inventory has loaded the murderface items with proper `cb` callbacks. Check the server console for output prefixed with `[murderface-pets]`.

### Item images

PNGs must be in `ox_inventory/web/images/` with exact lowercase names matching the item key (e.g., `murderface_husky.png`). The NUI constructs the path as `nui://ox_inventory/web/images/{item.name}.png`. After adding new images, a full server restart (or `restart ox_inventory` + client cache clear) is needed for the NUI to pick them up.

## File structure

```
murderface-pets/
├── fxmanifest.lua
├── config.lua
├── sql/
│   └── install.sql
├── locales/
│   └── en.lua
├── shared/
│   ├── animations.lua      -- Animation data by animal class
│   ├── variations.lua      -- Coat/texture variations per model
│   └── namevalidation.lua  -- Pet name filter
├── server/
│   ├── functions.lua       -- XP, cooldowns, pet init helpers
│   └── server.lua          -- Pet class, events, callbacks, DB layer
├── client/
│   ├── functions.lua       -- Spawn helpers, attack/hunt/K9 logic
│   ├── client.lua          -- ActivePed tracking, core interactions
│   └── menu.lua            -- Context menus (ox_lib)
└── inventory_images/       -- Item icons for ox_inventory
```
