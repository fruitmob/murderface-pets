# murderface-pets

**A free, open-source pet companion system for FiveM — built on the Qbox/ox stack.**

Most pet scripts on Tebex charge $15–$30 for a fraction of what this does. murderface-pets gives you 27 animals (16 vanilla + 11 addon), a full XP and progression system, K9 police functionality, hunting, leash system, guard mode, specializations, stray taming, breeding, and more — all config-driven, all free.

## Why This Script

- **Zero performance overhead** — no per-frame loops, no streaming assets. Stat updates tick every 10 seconds. Client-to-server sync is event-driven, not polled.
- **Drop-in install** — one SQL file, paste item defs into ox_inventory, copy images, `ensure`. Five minutes and you're live.
- **Everything is config-driven** — XP rates, level gates, food/thirst drain, K9 illegal items, shop prices, pet stats. Tune your server without touching Lua.
- **Built on the modern stack** — qbx_core, ox_lib, ox_inventory, ox_target, oxmysql. No legacy QB dependencies, no spaghetti wrappers.
- **Database-backed persistence** — pet metadata lives in ox_inventory items and is automatically backed up to MySQL every save tick. Admin restore command included.

## Features at a Glance

### 27 Unique Companions
Dogs, cats, big cats, primates, small animals, and addon breeds — each with per-model health, pricing, animations, and trait flags.

| Category | Animals | Highlights |
|----------|---------|------------|
| Large Dogs | Husky, German Shepherd, Rottweiler, Retriever, Chop | Tricks, petting, hunting |
| Small Dogs | Westie, Pug, Poodle | Tricks, petting |
| Cats | House Cat | Petting animations |
| Wild | Black Panther, Mountain Lion, Coyote | Hunting predators |
| Small Animals | Chicken, Rabbit | Idle companions |
| Primates | Chimpanzee, Rhesus Monkey | Build 3258+ |
| Addon Dogs | K9 M/F, K9 Original, Dalmatian, Doberman, Chow Chow, Robot Dog, Police K9 | Hunting, K9, multiple coats |
| Addon Exotic | Armadillo, Giant Cockroach, Tarantula | Novelty pets |

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
- **Command menu** (default: `O` key) — follow, wait, sit, tricks, hunt, go there, get in car, toggle leash
- **ox_target interactions** — pet, view stats, heal, revive, give water
- **Petting animations** — player and pet play synced animations, awards XP, relieves stress (configurable HUD integration)
- **Tricks** — sit, beg, shake paw, play dead (level-gated, per-trick unlock)
- **Auto vehicle enter/exit** — pet hops in when you get in a car, hops out when you leave
- **Leash system** — rope-based visual leash for dogs, enforces distance, syncs across clients, auto-detaches on vehicle entry/death/despawn
- **Guard mode** — pet holds position and attacks intruding NPCs (optionally players), owner gets notified
- **Pet name overhead** — 3D floating name and level title above each active pet
- **Pet emotes** — `/petemote` command with moods, vocalizations, and animations

### Hunting System
Dogs and wild cats can hunt local wildlife. Level-gated at level 5. Pets chase, attack, and return with the kill. Awards XP on successful hunts.

### K9 Police System
K9-eligible breeds (German Shepherd, Rottweiler) can be used by officers to:
- **Search players** for contraband (configurable illegal item list)
- **Search vehicles** for drugs and paraphernalia

Requires a configurable job (default: `police`) and level 10+.

### Guard Mode
Set your pet to guard a location. The pet holds position and attacks any NPC (optionally player peds) that enters the configurable guard radius. The owner receives a notification when intruders are detected. Recall the pet to resume following.

- Level 10+ required, dogs and wild species only
- Combat attributes fully configurable (ability, range, movement)
- Can't guard while leashed; can't hunt while guarding
- Auto-stops on vehicle entry, pet death, despawn, or logout

### Specialization System
At level 20, pets unlock a permanent one-time specialization choice:

| Specialization | Effect |
|----------------|--------|
| **Guardian** | 1.5x guard radius, +50 combat ability |
| **Tracker** | "Track Nearby" action detects peds within 50m, draws markers for 10s |
| **Companion** | 2x stress relief, 2x health regen, 1.25x XP gain |

Choice is confirmed with a dialog ("This is permanent!"), stored in metadata, and displayed in View Stats.

### Stray/Wild Pet Taming
Config-driven stray animal spawn points in the world. Players feed strays repeatedly to build trust (stored in MySQL). At full trust, the stray converts into a pet item — some with rare coat variants only obtainable through taming.

- 3 initial stray locations (Sandy Shores, Paleto Bay, City) — add more in config
- Feed cooldown prevents spam (default 5 minutes between feeds per stray)
- Proximity-based spawning (100m in / 150m out) keeps entity count low
- Spawn chance roll + respawn timer after taming (default 1 hour)

### Breeding System
Players buy a Dog House from the supply shop, place it as a prop in the world, and breed matching pets at it.

- **Same-model breeding** — Husky + Husky, not Husky + Rottweiler
- **Requires** opposite gender, both level 10+, 24-hour real-time cooldown per parent
- **Gestation = next server restart** — offspring status promoted from pending to ready on resource start
- **Offspring** get a random name, gender, and coat variation; level 0, fresh stats, parent lineage tracked
- **Dog house rest bonus** — pets within 15m get 50% less food/thirst drain + bonus HP regen
- **Placeable prop** — interactive placement with ghost preview, rotation controls, ground snapping
- 1 dog house per player, persisted in MySQL, pick up to relocate

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

### Optional Addon Models

These free streaming resources add 11 extra pet models. Download them separately and `ensure` them before `murderface-pets`. The script detects available models automatically — addon pets that aren't installed simply won't spawn.

| Resource | Models | Author | License |
|----------|--------|--------|---------|
| [popcornrp-pets](https://github.com/alberttheprince/popcornrp-pets) | K9 M/F, K9 Original, Dalmatian, Doberman, Chow Chow, Robot Dog, Armadillo, Cockroach, Tarantula | alberttheprince | Use permitted, no resale |
| [AddonPDK9](https://github.com/12LetterMeme/AddonPDK9) | Police K9 (German Shepherd) | 12LetterMeme | GPL-3.0 |

The K9 models from popcornrp-pets include built-in component accessories (vests, collars, glasses, nameplates) that can be accessed via `SetPedComponentVariation`. Full accessory menus are planned for a future update.

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

	['murderface_leash'] = {
		label = 'Pet Leash',
		weight = 100,
		consume = 0,
		description = 'Attach a leash to your pet',
		server = { export = 'murderface-pets.murderface_leash' },
	},

	['murderface_doghouse'] = {
		label = 'Dog House',
		weight = 5000,
		consume = 0,
		description = 'A placeable dog house for pet breeding and resting',
		server = { export = 'murderface-pets.murderface_doghouse' },
	},
```

<details>
<summary><strong>Addon pet items (click to expand)</strong> — only add these if you install the corresponding streaming resources</summary>

```lua
	-- ========================================
	--  murderface-pets: Addon Pet Items
	--  Requires: popcornrp-pets and/or AddonPDK9 streaming resources
	-- ========================================

	['murderface_k9m'] = {
		label = 'K9 Shepherd (M)',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A male K9 German Shepherd companion',
		server = { export = 'murderface-pets.murderface_k9m' },
	},

	['murderface_k9f'] = {
		label = 'K9 Shepherd (F)',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A female K9 German Shepherd companion',
		server = { export = 'murderface-pets.murderface_k9f' },
	},

	['murderface_k9'] = {
		label = 'K9 Original',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'An original K9 companion',
		server = { export = 'murderface-pets.murderface_k9' },
	},

	['murderface_dalmatian'] = {
		label = 'Dalmatian',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A spotted Dalmatian companion',
		server = { export = 'murderface-pets.murderface_dalmatian' },
	},

	['murderface_doberman'] = {
		label = 'Doberman',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A sleek Doberman companion',
		server = { export = 'murderface-pets.murderface_doberman' },
	},

	['murderface_chowchow'] = {
		label = 'Chow Chow',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A fluffy Chow Chow companion',
		server = { export = 'murderface-pets.murderface_chowchow' },
	},

	['murderface_robotdog'] = {
		label = 'Robot Dog',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A mechanical canine companion',
		server = { export = 'murderface-pets.murderface_robotdog' },
	},

	['murderface_armadillo'] = {
		label = 'Armadillo',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A tough little Armadillo companion',
		server = { export = 'murderface-pets.murderface_armadillo' },
	},

	['murderface_cockroach'] = {
		label = 'Giant Cockroach',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A surprisingly resilient companion',
		server = { export = 'murderface-pets.murderface_cockroach' },
	},

	['murderface_tarantula'] = {
		label = 'Tarantula',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A hairy eight-legged companion',
		server = { export = 'murderface-pets.murderface_tarantula' },
	},

	-- AddonPDK9 (https://github.com/12LetterMeme/AddonPDK9)
	['murderface_pdk9'] = {
		label = 'Police K9',
		weight = 100,
		stack = false,
		consume = 0,
		description = 'A trained Police K9 German Shepherd',
		server = { export = 'murderface-pets.murderface_pdk9' },
	},
```

</details>

### 3. Inventory images

Copy all `.png` files from the `inventory_images/` folder into your ox_inventory web images directory (typically `ox_inventory/web/images/`). All 24 images (16 pets + 8 supplies/accessories) are included. Addon pet images are not included — you'll need to create or source your own if using addon models.

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
| `Config.activityCooldowns` | Seconds between repeat XP awards per activity |
| `Config.progression` | Level gates, follow speed tiers, milestones, health regen |
| `Config.trickLevels` | Per-trick unlock levels |
| `Config.levelTitles` | Rank title thresholds |
| `Config.balance` | Food/thirst drain rates, AFK timers |
| `Config.items` | Item names, durations, heal percentages |
| `Config.k9` | Eligible jobs, illegal item list for searches |
| `Config.petShop` | Shop NPC model, coords, blip settings |
| `Config.suppliesShop` | Supply shop NPC model, coords, blip settings |
| `Config.stressRelief` | Stress reduction from petting (for HUD scripts) |
| `Config.leash` | Leash length, rope type, allowed species |
| `Config.guard` | Guard radius, check interval, player targeting, species |
| `Config.specializations` | Guardian/Tracker/Companion multipliers and thresholds |
| `Config.strays` | Stray spawn points, trust threshold, feed cooldown, rare coats |
| `Config.breeding` | Breed level, cooldown, rest bonus, placement distance, species |
| `Config.nameTag` | Overhead pet name display settings |
| `Config.petEmotes` | Emote definitions for `/petemote` command |
| `Config.blip` | Map blip settings for active pets |

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
│   ├── functions.lua       -- Spawn helpers, attack/hunt/K9/tracker logic
│   ├── client.lua          -- ActivePed tracking, core interactions
│   ├── leash.lua           -- Rope-based leash system + network sync
│   ├── guard.lua           -- Guard mode enforcement + combat
│   ├── strays.lua          -- Stray taming proximity spawning
│   ├── doghouse.lua        -- Placeable dog house + breeding menu
│   └── menu.lua            -- Context menus (ox_lib)
└── inventory_images/       -- Item icons for ox_inventory
```

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE). You are free to use, modify, and distribute this software under the terms of the GPL-3.0. See the [LICENSE](LICENSE) file for details.
