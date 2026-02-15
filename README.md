# murderface-pets

**A free, open-source pet companion system for FiveM — built on the Qbox/ox stack.**

Most pet scripts on Tebex charge $15–$30 for a fraction of what this does. murderface-pets gives you 16 animals, a full XP and progression system, K9 police functionality, hunting, tricks, grooming, and more — all config-driven, all free.

## Why This Script

- **Zero performance overhead** — no per-frame loops, no streaming assets. Stat updates tick every 10 seconds. Client-to-server sync is event-driven, not polled.
- **Drop-in install** — one SQL file, paste item defs into ox_inventory, copy images, `ensure`. Five minutes and you're live.
- **Everything is config-driven** — XP rates, level gates, food/thirst drain, K9 illegal items, shop prices, pet stats. Tune your server without touching Lua.
- **Built on the modern stack** — qbx_core, ox_lib, ox_inventory, ox_target, oxmysql. No legacy QB dependencies, no spaghetti wrappers.
- **Database-backed persistence** — pet metadata lives in ox_inventory items and is automatically backed up to MySQL every save tick. Admin restore command included.

## Features at a Glance

### 16 Unique Companions
Dogs, cats, big cats, primates, and small animals — each with per-model health, pricing, animations, and trait flags.

| Category | Animals | Highlights |
|----------|---------|------------|
| Large Dogs | Husky, German Shepherd, Rottweiler, Retriever, Chop | Tricks, petting, hunting |
| Small Dogs | Westie, Pug, Poodle | Tricks, petting |
| Cats | House Cat | Petting animations |
| Wild | Black Panther, Mountain Lion, Coyote | Hunting predators |
| Small Animals | Chicken, Rabbit | Idle companions |
| Primates | Chimpanzee, Rhesus Monkey | Build 3258+ |

### XP & Progression System
Pets level up from 0 to 50 through **7 active XP sources** and passive XP ticks. Progression unlocks new abilities as your pet grows.

| XP Source | Amount | Cooldown |
|-----------|--------|----------|
| Passive (while spawned) | 10/tick (scales down) | Every 10s |
| Hunt kill | 50 | 30s |
| K9 search | 40 | 30s |
| Feeding | 20 | — |
| Petting | 15 | 60s |
| Watering | 15 | — |
| Trick performance | 10 | 15s |
| Healing | 10 | — |

**Level-gated unlocks:**
- Level 5 — Hunting
- Level 5/10/20 — Trick tiers (beg, paw, play dead)
- Level 10 — K9 police searches
- Level 15/30 — Faster follow speed
- Level 25 — Passive health regeneration

**Rank titles:** Puppy → Trained → Veteran → Elite → Legendary

Real-time XP display in the View Stats panel — no need to despawn/respawn to check progress. Milestone celebrations at levels 10, 25, and 50 with notifications and pet vocalizations.

### Full Interaction System
- **Command menu** (default: `O` key) — follow, wait, sit, tricks, hunt, go there, get in car
- **ox_target interactions** — pet, view stats, heal, revive, give water
- **Petting animations** — player and pet play synced animations, awards XP, relieves stress (configurable HUD integration)
- **Tricks** — sit, beg, shake paw, play dead (level-gated, per-trick unlock)
- **Auto vehicle enter/exit** — pet hops in when you get in a car, hops out when you leave

### Hunting System
Dogs and wild cats can hunt local wildlife. Level-gated at level 5. Pets chase, attack, and return with the kill. Awards XP on successful hunts.

### K9 Police System
K9-eligible breeds (German Shepherd, Rottweiler) can be used by officers to:
- **Search players** for contraband (configurable illegal item list)
- **Search vehicles** for drugs and paraphernalia

Requires a configurable job (default: `police`) and level 10+.

### Care System
- **Hunger** drains over time — feed with pet food items
- **Thirst** builds over time — fill and use water bottles (refillable)
- **Health** drains when starving or dehydrated — heal with first aid kits
- **Death & revival** — pets can die and be revived with first aid (ox_target)
- **Health regeneration** — level 25+ pets slowly regenerate HP

### Customization & Economy
- **Pet shop NPC** with configurable location and pricing
- **Supply shop NPC** with food, water bottles, first aid, collars, nametags, grooming kits
- **Grooming** — change your pet's coat/variation with a grooming kit
- **Renaming** — rename your pet with a nametag item (profanity filter included)
- **Ownership transfer** — give your pet to another player with a collar item

## Dependencies

| Resource | Link |
|----------|------|
| qbx_core | [Qbox-project/qbx_core](https://github.com/Qbox-project/qbx_core) |
| ox_lib | [overextended/ox_lib](https://github.com/overextended/ox_lib) |
| ox_inventory | [overextended/ox_inventory](https://github.com/overextended/ox_inventory) |
| ox_target | [overextended/ox_target](https://github.com/overextended/ox_target) |
| oxmysql | [overextended/oxmysql](https://github.com/overextended/oxmysql) |

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

## Configuration

All settings are in `config.lua` with inline comments. Everything is tunable without touching any other file.

| Section | What it controls |
|---------|-----------------|
| `Config.maxActivePets` | Max simultaneously spawned pets (default: 2) |
| `Config.petMenuKeybind` | Key to open companion menu (default: `O`) |
| `Config.xp` | Per-action XP awards for all 7 sources |
| `Config.progression` | Level gates, follow speed tiers, milestones, health regen |
| `Config.trickLevels` | Per-trick unlock levels |
| `Config.levelTitles` | Rank title thresholds |
| `Config.balance` | Food/thirst drain rates, AFK timers |
| `Config.items` | Item names, durations, heal percentages |
| `Config.k9` | Eligible jobs, illegal item list for searches |
| `Config.petShop` | Shop NPC model, coords, blip settings |
| `Config.suppliesShop` | Supply shop NPC model, coords, blip settings |
| `Config.stressRelief` | Stress reduction from petting (for HUD scripts) |
| `Config.blip` | Map blip settings for active pets |

## Developer Notes

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

## File Structure

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

## License

Free and open source. Use it, modify it, share it.
