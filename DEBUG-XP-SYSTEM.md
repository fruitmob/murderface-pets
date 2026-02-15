# Debug: XP & Progression System Not Working

## Problem
Pets have been spawned for a while and multiple actions performed (petting, tricks, etc.), but XP does not appear to increase when checking View Stats.

## What Was Changed (2026-02-15 XP Overhaul)
6 files modified — see `CHANGELOG-MURDERFACE.md` for full details.

### Key files:
- `config.lua` — New `Config.xp`, `Config.progression`, `Config.trickLevels`, `Config.levelTitles`, shared helpers (`Config.xpForLevel`, `Config.getLevelTitle`, `Config.getFollowSpeed`)
- `server/functions.lua` — New `Update.xpAward()`, `Update.healthRegen()`, `IsOnActivityCooldown()`, `ClearActivityCooldowns()`. Updated `xpPerTick()` to use `Config.xp.passive`.
- `server/server.lua` — `updatePetStats` event expanded with `key = 'activity'` branch. XP added to `feedPet`, `healPet`, `decreaseThirst` handlers. `healthRegen` added to `saveData` tick. Disconnect cleanup.
- `client/client.lua` — View Stats shows XP/title. Petting ox_target fires XP. Milestone event handler. Follow speed at spawn reverted to 3.0 (speed handled inside `TaskFollowTargetedPlayer`).
- `client/menu.lua` — Level-gated tricks/hunt/K9. Petting + trick XP triggers.
- `client/functions.lua` — `TaskFollowTargetedPlayer` uses level-based speed. Hunt kill + K9 XP triggers.

## Debugging Checklist

### 1. Is passive XP ticking server-side?
The passive XP path: `client/client.lua:createActivePetThread` sends `{ key = 'XP' }` every `Config.dataUpdateInterval` (10s) → `server/server.lua:updatePetStats` → `Update.xp(src, petData)` in `server/functions.lua`.

**Check:** Add a temporary print inside `Update.xp()` (server/functions.lua ~line 219):
```lua
function Update.xp(src, petData)
    print(('[murderface-pets] ^3Update.xp^0: src=%d XP=%d level=%d'):format(src, petData.metadata.XP, petData.metadata.level or 0))
    ...
```

### 2. Is activity XP reaching the server?
The activity path: client fires `TriggerServerEvent('murderface-pets:server:updatePetStats', hash, { key = 'activity', action = 'petting' })` → server checks `data.key == 'activity'` → validates `Config.xp[data.action]` → checks cooldown → calls `Update.xpAward()`.

**Check:** Add a print in the `updatePetStats` handler (server/server.lua ~line 475):
```lua
if data.key == 'XP' then
    Update.xp(src, petData)
elseif data.key == 'activity' then
    print(('[murderface-pets] ^3Activity XP^0: src=%d action=%s amount=%s'):format(src, tostring(data.action), tostring(Config.xp[data.action])))
    ...
```

### 3. Is the client View Stats reading stale data?
**LIKELY ROOT CAUSE:** View Stats reads from `pd.item.metadata.XP` which is the client-side `ActivePed` data captured at spawn time. The server updates XP in its own `Pet.players[src][hash].metadata` and writes to ox_inventory via `SetMetadata`, but the client's `ActivePed.pets[hash].item.metadata` object is **never refreshed** after spawn.

The XP may actually be accumulating correctly server-side, but the client shows the spawn-time value.

**How to verify:** After spawning a pet and waiting 30+ seconds, despawn and respawn it. If the XP jumps up on respawn, this confirms the data is stale client-side.

**Fix approach:** Either:
- (A) Have the server periodically send updated XP/level to the client (new event or piggyback on existing save tick)
- (B) Have the client request fresh metadata from the server when opening View Stats
- (C) Have `Update.xp()` and `Update.xpAward()` trigger a client event that updates `ActivePed.pets[hash].item.metadata.XP` and `.level` in real-time

Option (C) is cleanest — minimal traffic, updates exactly when XP changes.

### 4. Are the item-based XP awards working? (feed/water/heal)
These call `Update.xpAward()` directly in server handlers without going through the `updatePetStats` event. They should work but also have the same stale-client-display issue.

### 5. Check the XP formula edge case
In `Update.xp()` (the passive tick), there's this block:
```lua
if petData.metadata.XP == 0 then
    petData.metadata.XP = 75
end
```
This jumps brand-new pets to 75 XP instantly. Level 1 requires `75 + (1*1*15) = 90` XP. So after the jump to 75, the pet needs just 15 more passive XP ticks to hit level 1. Verify this isn't causing confusion.

### 6. Admin test command
Consider adding a temporary `/petdebug` command that prints the server-side pet stats for the calling player's active pets, to compare against what View Stats shows on the client.

## Architecture Reference

```
Client                              Server
──────                              ──────
createActivePetThread
  every 10s: { key = 'XP' }  ───►  updatePetStats → Update.xp()
                                      └─ petData.metadata.XP += xpPerTick()
                                      └─ level-up check + notify

petting/trick/hunt/k9
  { key = 'activity',        ───►  updatePetStats → IsOnActivityCooldown()
    action = 'petting' }                             → Update.xpAward()
                                      └─ petData.metadata.XP += amount
                                      └─ level-up check + milestone

feed/water/heal (items)             feedPet/healPet/decreaseThirst
  (server-side directly)              └─ Update.xpAward() called inline

                                    Pet:saveData() every 5s
                                      └─ ox_inventory:SetMetadata()
                                      └─ backupToDb()

View Stats (client)
  └─ reads ActivePed.pets[hash].item.metadata  ← STALE after spawn
```
