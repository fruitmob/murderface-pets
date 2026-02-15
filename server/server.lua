-- murderface-pets: Main server logic
-- Pet lifecycle, inventory integration, shops, persistence, and database backup.

-- ============================
--      Local Helpers
-- ============================

local SAVE_INTERVAL = 5000
local MAX_AGE = 60 * 60 * 24 * 10 -- 10 days of active time
local pendingSpawns = {} -- { [src] = { [hash] = os.time() } } race-condition guard

local function round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

--- Find inventory slot containing a pet item with a specific hash
---@param src number Player source
---@param itemName string Item name
---@param hash string Pet hash
---@return number|nil slot
local function findSlotByHash(src, itemName, hash)
    local items = exports.ox_inventory:GetInventoryItems(src)
    if not items then return nil end
    for _, item in pairs(items) do
        if item.name == itemName and item.metadata and item.metadata.hash == hash then
            return item.slot
        end
    end
    return nil
end

--- Get first inventory item matching a name
---@param src number Player source
---@param itemName string Item name
---@return table|nil item
local function getItemByName(src, itemName)
    local items = exports.ox_inventory:GetInventoryItems(src)
    if not items then return nil end
    for _, item in pairs(items) do
        if item.name == itemName then
            return item
        end
    end
    return nil
end

-- ============================
--     Database Backup
-- ============================

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `murderface_pets` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `item_hash` VARCHAR(50) NOT NULL UNIQUE,
            `item_name` VARCHAR(50) NOT NULL,
            `metadata` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_citizenid` (`citizenid`),
            INDEX `idx_hash` (`item_hash`)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `murderface_stray_trust` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `stray_id` VARCHAR(50) NOT NULL,
            `trust` INT NOT NULL DEFAULT 0,
            `last_fed` TIMESTAMP NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY `idx_citizen_stray` (`citizenid`, `stray_id`),
            INDEX `idx_stray_id` (`stray_id`)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `murderface_doghouses` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `coords` VARCHAR(100) NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `placed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `idx_citizen_doghouse` (`citizenid`)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `murderface_breeding` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `parent1_hash` VARCHAR(50) NOT NULL,
            `parent2_hash` VARCHAR(50) NOT NULL,
            `offspring_item` VARCHAR(50) NOT NULL,
            `offspring_metadata` LONGTEXT NOT NULL,
            `status` ENUM('pending','ready','claimed') NOT NULL DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_citizen_breeding` (`citizenid`),
            INDEX `idx_status` (`status`)
        )
    ]])
end)

--- Async backup pet data to database
---@param citizenid string Player citizenid
---@param hash string Pet hash
---@param itemName string Item name
---@param metadata table Pet metadata
local function backupToDb(citizenid, hash, itemName, metadata)
    MySQL.query(
        'INSERT INTO murderface_pets (citizenid, item_hash, item_name, metadata) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE metadata = VALUES(metadata), updated_at = NOW()',
        { citizenid, hash, itemName, json.encode(metadata) }
    )
end

-- ============================
--          Pet Class
-- ============================

Pet = { players = {} }

--- Check if a pet is currently spawned for a player
---@param src number Player source
---@param hash string Pet hash
---@return boolean
function Pet:isSpawned(src, hash)
    return self.players[src] ~= nil and self.players[src][hash] ~= nil
end

--- Register a pet as spawned
---@param src number Player source
---@param data table { item = { name, metadata }, model, entity }
---@return boolean
function Pet:setAsSpawned(src, data)
    local metadata = data.item.metadata
    if not metadata or not metadata.hash then return false end

    local player = exports.qbx_core:GetPlayer(src)

    self.players[src] = self.players[src] or {}
    self.players[src][metadata.hash] = {
        model     = data.model,
        entity    = data.entity,
        itemName  = data.item.name,
        metadata  = metadata,
        citizenid = player and player.PlayerData.citizenid or nil,
    }
    return true
end

--- Unregister a pet as spawned
---@param src number Player source
---@param hash string Pet hash
function Pet:setAsDespawned(src, hash)
    if self.players[src] then
        self.players[src][hash] = nil
    end
end

--- Spawn or toggle-despawn a pet
---@param src number Player source
---@param model string Pet model name
---@param item table Inventory item { name, slot, metadata }
function Pet:spawnPet(src, model, item)
    local hash = item.metadata and item.metadata.hash
    if not hash then return end

    -- Toggle: if already spawned, despawn it
    if self:isSpawned(src, hash) then
        self:despawnPet(src, hash)
        return
    end

    -- Prevent double-spawn race condition (client hasn't registered yet)
    if pendingSpawns[src] and pendingSpawns[src][hash] then
        local elapsed = os.time() - pendingSpawns[src][hash]
        if elapsed < 30 then return end
        pendingSpawns[src][hash] = nil -- timed out, allow retry
    end

    -- Check spawn limit (registered + pending)
    local count = 0
    if self.players[src] then
        for _ in pairs(self.players[src]) do count = count + 1 end
    end
    if pendingSpawns[src] then
        local now = os.time()
        for _, t in pairs(pendingSpawns[src]) do
            if now - t < 30 then count = count + 1 end
        end
    end
    if count >= Config.maxActivePets then
        TriggerClientEvent('ox_lib:notify', src, {
            description = string.format(Lang:t('error.reached_max_allowed_pet'), Config.maxActivePets),
            type = 'error'
        })
        return
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Dead pet check (health <= 100 means dead in GTA terms)
    if item.metadata.health <= 100 then
        item.metadata.health = 0
        exports.ox_inventory:SetMetadata(src, item.slot, item.metadata)
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.your_pet_is_dead'),
            type = 'error'
        })
        return
    end

    -- Mark as pending spawn (cleared on registerPet callback or 30s timeout)
    pendingSpawns[src] = pendingSpawns[src] or {}
    pendingSpawns[src][hash] = os.time()

    local isOwner = item.metadata.owner and item.metadata.owner.phone == player.PlayerData.charinfo.phone
    TriggerClientEvent('murderface-pets:client:spawnPet', src, model, not isOwner, item)
end

--- Trigger client despawn
---@param src number Player source
---@param hash string Pet hash
---@param instant? boolean Skip despawn animation
function Pet:despawnPet(src, hash, instant)
    TriggerClientEvent('murderface-pets:client:despawnPet', src, hash, instant)
end

--- Find active pet data by hash
---@param src number Player source
---@param hash string Pet hash
---@return table|nil petData
function Pet:findByHash(src, hash)
    if not self.players[src] then return nil end
    return self.players[src][hash]
end

--- Save pet data to ox_inventory and database backup
---@param src number Player source
---@param hash string Pet hash
---@param silent? boolean Suppress client events (used during disconnect)
---@param processStats? boolean Process food/thirst/regen ticks (decoupled from save frequency)
function Pet:saveData(src, hash, silent, processStats)
    local petData = self:findByHash(src, hash)
    if not petData then return end

    -- Skip dead pets
    if petData.metadata.health <= 0 then return end

    -- Process stat updates only on stat ticks (decoupled from save frequency)
    if processStats then
        if petData.metadata.health > 100 then
            if petData.metadata.age < MAX_AGE then
                petData.metadata.age = petData.metadata.age + Config.dataUpdateInterval
            end
            Update.food(petData)
            Update.thirst(petData)
            Update.healthRegen(petData)

            -- Sync food/thirst to client so View Stats is accurate
            TriggerClientEvent('murderface-pets:client:syncStats', src, hash, {
                food = petData.metadata.food,
                thirst = petData.metadata.thirst,
            })
        else
            petData.metadata.health = 0
            if not silent then
                TriggerClientEvent('murderface-pets:client:forceKill', src, hash, 'hunger')
            end
        end
    end

    -- Round floating-point values
    petData.metadata.health = round(petData.metadata.health, 2)
    petData.metadata.thirst = round(petData.metadata.thirst, 2)
    petData.metadata.food   = round(petData.metadata.food, 2)

    -- Save to ox_inventory
    local slot = findSlotByHash(src, petData.itemName, hash)
    if slot then
        exports.ox_inventory:SetMetadata(src, slot, petData.metadata)
    end

    -- Database backup (attempt even if inventory save failed)
    if petData.citizenid then
        backupToDb(petData.citizenid, hash, petData.itemName, petData.metadata)
    end
end

--- Save and clean up all pets for a disconnecting player
---@param src number Player source
function Pet:cleanup(src)
    if not self.players[src] then return end
    for hash in pairs(self.players[src]) do
        self:saveData(src, hash, true)
    end
    self.players[src] = nil
end

-- ============================
--    Player Disconnect
-- ============================

AddEventHandler('playerDropped', function()
    local src = source
    Pet:cleanup(src)
    ClearCooldown(src)
    ClearActivityCooldowns(src)
    pendingSpawns[src] = nil
end)

-- ============================
--       Despawn Events
-- ============================

RegisterNetEvent('murderface-pets:server:setAsDespawned', function(hash)
    if not hash then return end
    Pet:setAsDespawned(source, hash)
end)

RegisterNetEvent('murderface-pets:server:spawnCancelled', function(hash)
    local src = source
    if pendingSpawns[src] then
        pendingSpawns[src][hash] = nil
    end
end)

RegisterNetEvent('murderface-pets:server:despawnNotOwned', function(hash)
    Pet:despawnPet(source, hash, true)
end)

RegisterNetEvent('murderface-pets:server:deleteEntity', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 then
        DeleteEntity(entity)
    end
end)

-- ============================
--    Pet Item Exports
-- ============================

--- Common handler for all pet items (ox_inventory server.export callback)
--- NOTE: ox_inventory's useExport calls exports[resource][export](nil, ...) but
--- FiveM's cross-resource export marshaling drops the leading nil. The actual
--- arguments received are (event, item, inventory, slot) — no placeholder.
---@param event string 'usingItem' | 'usedItem'
---@param item table Item definition from ox_inventory
---@param inventory table Full inventory object (has .id, .items)
---@param slot number Slot number
local function handlePetItem(event, item, inventory, slot)
    print(('[murderface-pets] ^3handlePetItem called^0: event=%s item=%s slot=%s'):format(
        tostring(event), tostring(item and item.name or 'nil'), tostring(slot)))

    if event ~= 'usingItem' then return end

    local src = inventory.id
    local petCfg = Config.petsByItem[item.name]
    if not petCfg then
        print(('[murderface-pets] ^1petCfg NOT FOUND^0 for item.name=%s'):format(tostring(item.name)))
        return false
    end

    local invItem = inventory.items[slot]
    local metadata = invItem and invItem.metadata

    -- First use: initialize if no hash
    if type(metadata) ~= 'table' or not metadata.hash then
        print(('[murderface-pets] ^2Initializing new pet^0: %s for player %s'):format(item.name, src))
        InitPet(src, { name = item.name, slot = slot, metadata = metadata })
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('success.pet_initialization_was_successful'),
            type = 'success'
        })
        return false
    end

    -- Cooldown check
    local remaining = CheckCooldown(src)
    if remaining > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            description = string.format(Lang:t('info.still_on_cooldown'), remaining),
            type = 'inform'
        })
        return false
    end

    print(('[murderface-pets] ^2Spawning pet^0: model=%s hash=%s'):format(petCfg.model, metadata.hash))
    Pet:spawnPet(src, petCfg.model, { name = item.name, slot = slot, metadata = metadata })
    return false
end

for _, pet in ipairs(Config.pets) do
    exports(pet.item, handlePetItem)
end
print(('[murderface-pets] ^2Registered %d pet item exports^0'):format(#Config.pets))

-- ============================
--    Supply Item Exports
-- ============================

exports(Config.items.food.name, function(event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:feedPet', inventory.id)
        return false
    end
end)

exports(Config.items.collar.name, function(event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:transferOwnership', inventory.id)
        return false
    end
end)

exports(Config.items.nametag.name, function(event, item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:renamePet', inventory.id, item)
        return false
    end
end)

exports(Config.items.firstaid.name, function(event)
    if event == 'usingItem' then
        return false -- consumed via ox_target heal/revive interaction
    end
end)

exports(Config.items.groomingkit.name, function(event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:groomPet', inventory.id)
        return false
    end
end)

exports(Config.items.waterbottle.name, function(event, item, inventory, slot)
    if event == 'usingItem' then
        local src = inventory.id
        local refillCost = Config.items.waterbottle.refillCost

        -- Accept either 'water' or 'water_bottle' (covers different server configs)
        local waterItem
        for _, name in ipairs({'water', 'water_bottle'}) do
            local c = exports.ox_inventory:GetItemCount(src, name)
            if c and c >= refillCost then
                waterItem = name
                break
            end
        end

        if not waterItem then
            TriggerClientEvent('ox_lib:notify', src, {
                description = string.format(Lang:t('error.not_enough_water_bottles'), refillCost),
                type = 'error'
            })
            return false
        end

        exports.ox_inventory:RemoveItem(src, waterItem, refillCost)
        local invItem = inventory.items[slot]
        local metadata = invItem and invItem.metadata or {}
        TriggerClientEvent('murderface-pets:client:fillBottle', src, { name = item.name, slot = slot, metadata = metadata })
        return false
    end
end)

-- ============================
--       Server Events
-- ============================

-- Feed pet
RegisterNetEvent('murderface-pets:server:feedPet', function(hash)
    local src = source
    if not hash then return end

    if not exports.ox_inventory:RemoveItem(src, Config.items.food.name, 1) then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_remove_item_from_inventory'),
            type = 'error'
        })
        return
    end

    local petData = Pet:findByHash(src, hash)
    if not petData then return end

    petData.metadata.food = math.min(100, petData.metadata.food + Config.balance.food.feedAmount)
    Update.xpAward(src, petData, Config.xp.feeding)

    -- Sync updated food to client
    TriggerClientEvent('murderface-pets:client:syncStats', src, hash, {
        food = petData.metadata.food,
        thirst = petData.metadata.thirst,
    })
    TriggerClientEvent('ox_lib:notify', src, {
        description = string.format('Fed! Food: %.0f%%', petData.metadata.food),
        type = 'success'
    })
end)

-- Heal or revive pet
RegisterNetEvent('murderface-pets:server:healPet', function(hash, model, processType)
    local src = source
    if not hash then return end

    local petData = Pet:findByHash(src, hash)
    if not petData then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_start_process'),
            type = 'error'
        })
        return
    end

    local petCfg = Config.petsByModel[model]
    if not petCfg then return end

    local maxHP = petCfg.maxHealth
    local healPercent = Config.items.firstaid.healPercent
    local healAmount = math.floor(maxHP * (healPercent / 100))

    if petData.metadata.health >= maxHP then
        petData.metadata.health = maxHP
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('info.full_life_pet'),
            type = 'inform'
        })
        return
    end

    if not exports.ox_inventory:RemoveItem(src, Config.items.firstaid.name, 1) then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_remove_item_from_inventory'),
            type = 'error'
        })
        return
    end

    if processType == 'Heal' then
        petData.metadata.health = math.min(maxHP, petData.metadata.health + healAmount)
        Update.xpAward(src, petData, Config.xp.healing)
        Pet:saveData(src, hash)
        local msg = string.format(Lang:t('success.healing_was_successful'), petData.metadata.health, maxHP)
        TriggerClientEvent('murderface-pets:client:updateHealth', src, hash, petData.metadata.health)
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'success' })
    else
        -- Revive
        petData.metadata.health = 100 + Config.items.firstaid.reviveBonus
        Pet:saveData(src, hash)
        Pet:despawnPet(src, hash, true)
        local msg = string.format(Lang:t('success.successful_revive'), petData.metadata.name)
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'success' })
    end
end)

-- Update XP or health from client
RegisterNetEvent('murderface-pets:server:updatePetStats', function(hash, data)
    local src = source
    if not hash or type(data) ~= 'table' then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local petData = Pet:findByHash(src, hash)
    if not petData then return end

    if data.key == 'XP' then
        Update.xp(src, petData)
    elseif data.key == 'activity' then
        local amount = Config.xp[data.action]
        if amount and not IsOnActivityCooldown(src, data.action) then
            Update.xpAward(src, petData, amount)
        end
    else
        Update.health(src, data, petData)
    end
end)

-- Grooming process
RegisterNetEvent('murderface-pets:server:startGrooming', function(item)
    local src = source
    local petCfg = Config.petsByItem[item.name]
    if not petCfg then return end

    TriggerClientEvent('murderface-pets:client:customizePet', src, item, {
        coats         = Variations.getNames(petCfg.model),
        petConfig     = petCfg,
        disableRename = true,
        processType   = Config.items.groomingkit.name,
    })
end)

-- Water bottle fill
RegisterNetEvent('murderface-pets:server:fillBottle', function(item)
    local src = source
    local maxCap = Config.items.waterbottle.maxCapacity
    local refillCost = Config.items.waterbottle.refillCost

    -- Get fresh item data from inventory
    local freshItem
    local invItems = exports.ox_inventory:GetInventoryItems(src)
    if invItems then
        for _, v in pairs(invItems) do
            if v.name == item.name and v.slot == item.slot then
                freshItem = v
                break
            end
        end
    end

    if not freshItem then
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'Could not find water bottle in inventory',
            type = 'error'
        })
        return
    end

    local meta = freshItem.metadata
    if type(meta) ~= 'table' or meta.liter == nil then
        exports.ox_inventory:SetMetadata(src, freshItem.slot, { liter = 0 })
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'Washing water bottle!',
            type = 'inform'
        })
        return
    end

    if meta.liter >= maxCap then
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'Bottle is already at max capacity',
            type = 'error'
        })
        return
    end

    meta.liter = math.min(maxCap, meta.liter + refillCost)
    exports.ox_inventory:SetMetadata(src, freshItem.slot, meta)
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'Filled bottle',
        type = 'success'
    })
end)

-- Player logout (character switch)
RegisterNetEvent('murderface-pets:server:onLogout', function(hashes)
    local src = source
    if type(hashes) == 'table' then
        for _, hash in pairs(hashes) do
            Pet:saveData(src, hash)
            Pet:setAsDespawned(src, hash)
        end
    end
end)

-- ============================
--      Leash Sync
-- ============================

RegisterNetEvent('murderface-pets:server:syncLeash', function(petNetId, leashed)
    TriggerClientEvent('murderface-pets:client:syncLeash', -1, source, petNetId, leashed)
end)

-- ============================
--      Server Callbacks
-- ============================

-- Decrease pet thirst via water bottle
lib.callback.register('murderface-pets:server:decreaseThirst', function(source, hash)
    local src = source
    local bottle = getItemByName(src, Config.items.waterbottle.name)

    if not bottle then
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'You need a water bottle!',
            type = 'error'
        })
        return false
    end

    local meta = bottle.metadata
    if type(meta) ~= 'table' or meta.liter == nil then
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'You should wash the water bottle first!',
            type = 'error'
        })
        return false
    end

    local drinkCost = Config.items.waterbottle.refillCost
    if meta.liter < drinkCost then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.not_enough_water_in_your_bottle'),
            type = 'error'
        })
        return false
    end

    local petData = Pet:findByHash(src, hash)
    if not petData then return false end

    -- Reduce bottle water
    meta.liter = meta.liter - drinkCost
    exports.ox_inventory:SetMetadata(src, bottle.slot, meta)

    -- Reduce pet thirst
    local reduction = Config.balance.thirst.reductionPerDrink
    petData.metadata.thirst = math.max(0, petData.metadata.thirst - reduction)
    Update.xpAward(src, petData, Config.xp.watering)

    -- Sync updated thirst to client
    TriggerClientEvent('murderface-pets:client:syncStats', src, hash, {
        food = petData.metadata.food,
        thirst = petData.metadata.thirst,
    })
    TriggerClientEvent('ox_lib:notify', src, {
        description = string.format('Hydrated! Thirst: %.0f%%', petData.metadata.thirst),
        type = 'success'
    })
    return true
end)

-- K9: Search player inventory for illegal items
lib.callback.register('murderface-pets:server:searchInventory', function(source, targetId)
    local src = source
    for _, itemName in ipairs(Config.k9.illegalItems) do
        local count = exports.ox_inventory:GetItemCount(targetId, itemName)
        if count and count > 0 then
            return true
        end
    end
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'K9 could not find anything!',
        type = 'error'
    })
    return false
end)

-- K9: Search vehicle stash for illegal items
lib.callback.register('murderface-pets:server:searchVehicle', function(source, data)
    local src = source
    local stashId = data.key == 1 and ('gloveV' .. data.plate) or ('trunkV' .. data.plate)
    local stashItems = exports.ox_inventory:GetInventoryItems(stashId)

    if stashItems then
        for _, item in pairs(stashItems) do
            for _, illegal in ipairs(Config.k9.illegalItems) do
                if item.name == illegal then
                    TriggerClientEvent('ox_lib:notify', src, {
                        description = 'K9 found something!',
                        type = 'success'
                    })
                    return true
                end
            end
        end
    end

    TriggerClientEvent('ox_lib:notify', src, {
        description = 'K9 could not find anything!',
        type = 'error'
    })
    return false
end)

-- Choose specialization
lib.callback.register('murderface-pets:server:chooseSpecialization', function(source, hash, specName)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found' end

    local petData = Pet:findByHash(src, hash)
    if not petData then return false, 'Pet not found' end

    local level = petData.metadata.level or 0
    if level < Config.progression.minSpecializationLevel then
        return false, string.format('Requires level %d', Config.progression.minSpecializationLevel)
    end

    if petData.metadata.specialization then
        return false, 'Already specialized'
    end

    if not Config.specializations or not Config.specializations[specName] then
        return false, 'Invalid specialization'
    end

    petData.metadata.specialization = specName
    Pet:saveData(src, hash)
    return true, specName
end)

-- ============================
--     Stray Taming
-- ============================

local strayTimers = {} -- { [strayId] = os.time() } respawn cooldown after taming

--- Find stray config by ID
local function findStrayCfg(strayId)
    if not Config.strays or not Config.strays.spawnPoints then return nil end
    for _, s in ipairs(Config.strays.spawnPoints) do
        if s.id == strayId then return s end
    end
    return nil
end

-- Check if a stray should spawn (respawn timer + spawn chance roll)
lib.callback.register('murderface-pets:server:checkStrayStatus', function(_, strayId)
    if not Config.strays or not Config.strays.enabled then return false end

    -- Check respawn timer
    if strayTimers[strayId] then
        local elapsed = os.time() - strayTimers[strayId]
        if elapsed < Config.strays.respawnTime then
            return false
        end
        strayTimers[strayId] = nil
    end

    local strayCfg = findStrayCfg(strayId)
    if not strayCfg then return false end

    return math.random() <= strayCfg.spawnChance
end)

-- Feed a stray to build trust
lib.callback.register('murderface-pets:server:feedStray', function(source, strayId)
    local src = source
    if not Config.strays or not Config.strays.enabled then return false, 'Disabled' end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found' end
    local citizenid = player.PlayerData.citizenid

    local strayCfg = findStrayCfg(strayId)
    if not strayCfg then return false, 'Invalid stray' end

    -- Check respawn timer
    if strayTimers[strayId] then
        local elapsed = os.time() - strayTimers[strayId]
        if elapsed < Config.strays.respawnTime then
            return false, 'This stray is not here right now'
        end
        strayTimers[strayId] = nil
    end

    -- Check feed cooldown from DB
    local rows = MySQL.query.await(
        'SELECT trust, last_fed FROM murderface_stray_trust WHERE citizenid = ? AND stray_id = ?',
        { citizenid, strayId }
    )

    local currentTrust = 0
    if rows and #rows > 0 then
        currentTrust = rows[1].trust
        if rows[1].last_fed then
            local cdCheck = MySQL.scalar.await(
                'SELECT TIMESTAMPDIFF(SECOND, last_fed, NOW()) FROM murderface_stray_trust WHERE citizenid = ? AND stray_id = ?',
                { citizenid, strayId }
            )
            if cdCheck and cdCheck < Config.strays.feedCooldown then
                local remaining = Config.strays.feedCooldown - cdCheck
                return false, string.format('Come back in %d minutes', math.ceil(remaining / 60))
            end
        end
    end

    -- Consume food item
    if not exports.ox_inventory:RemoveItem(src, Config.strays.feedItem, 1) then
        return false, 'You need pet food to feed strays'
    end

    -- Update trust in DB
    local newTrust = currentTrust + Config.strays.trustPerFeed

    MySQL.query(
        'INSERT INTO murderface_stray_trust (citizenid, stray_id, trust, last_fed) VALUES (?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE trust = ?, last_fed = NOW()',
        { citizenid, strayId, newTrust, newTrust }
    )

    -- Check if taming threshold reached
    if newTrust >= Config.strays.trustThreshold then
        -- Grant pet item
        exports.ox_inventory:AddItem(src, strayCfg.item, 1)

        -- Initialize the pet and apply rare coat if configured
        Wait(200)
        local items = exports.ox_inventory:GetInventoryItems(src)
        if items then
            for _, item in pairs(items) do
                if item.name == strayCfg.item and (not item.metadata or not item.metadata.hash) then
                    InitPet(src, { name = item.name, slot = item.slot, metadata = item.metadata })
                    if strayCfg.rareCoat then
                        Wait(100)
                        local freshItems = exports.ox_inventory:GetInventoryItems(src)
                        if freshItems then
                            for _, fi in pairs(freshItems) do
                                if fi.name == strayCfg.item and fi.slot == item.slot and fi.metadata and fi.metadata.hash then
                                    fi.metadata.variation = strayCfg.rareCoat
                                    exports.ox_inventory:SetMetadata(src, fi.slot, fi.metadata)
                                    break
                                end
                            end
                        end
                    end
                    break
                end
            end
        end

        -- Clean up trust record and start respawn timer
        MySQL.query('DELETE FROM murderface_stray_trust WHERE citizenid = ? AND stray_id = ?',
            { citizenid, strayId })
        strayTimers[strayId] = os.time()

        return true, 'tamed'
    end

    return true, string.format('Trust: %d/%d', newTrust, Config.strays.trustThreshold)
end)

-- ============================
--    Dog House / Breeding
-- ============================

local doghouseCache = {} -- { [citizenid] = vector3 }

-- Load placed dog houses into cache on startup
CreateThread(function()
    Wait(2000)

    -- Promote pending breeding to ready (gestation = next server restart)
    local affectedRows = MySQL.update.await(
        "UPDATE murderface_breeding SET status = 'ready' WHERE status = 'pending'"
    )
    if affectedRows and affectedRows > 0 then
        print(('[murderface-pets] ^2Breeding: promoted %d pending offspring to ready^0'):format(affectedRows))
    end

    -- Load doghouse positions into cache
    local rows = MySQL.query.await('SELECT citizenid, coords, heading FROM murderface_doghouses')
    if rows then
        for _, row in ipairs(rows) do
            local parts = {}
            for part in row.coords:gmatch('[^,]+') do
                parts[#parts + 1] = tonumber(part)
            end
            if #parts == 3 then
                doghouseCache[row.citizenid] = vector3(parts[1], parts[2], parts[3])
            end
        end
        if #rows > 0 then
            print(('[murderface-pets] ^2Loaded %d dog house locations^0'):format(#rows))
        end
    end
end)

-- Dog House item export handler
exports(Config.items.doghouse.name, function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local src = inventory.id

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local citizenid = player.PlayerData.citizenid

    if doghouseCache[citizenid] then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('breeding.already_have_doghouse'),
            type = 'error'
        })
        return false
    end

    TriggerClientEvent('murderface-pets:client:startDoghousePlacement', src)
    return false
end)

-- Rest bonus: client tells server when a pet is near the dog house
RegisterNetEvent('murderface-pets:server:setNearDoghouse', function(hash, isNear)
    local src = source
    if not Pet.players[src] then return end
    local petData = Pet.players[src][hash]
    if petData then
        petData.nearDoghouse = isNear
    end
end)

-- Place dog house
lib.callback.register('murderface-pets:server:placeDoghouse', function(source, coords, heading)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found' end
    local citizenid = player.PlayerData.citizenid

    if doghouseCache[citizenid] then
        return false, 'You already have a dog house placed'
    end

    if not exports.ox_inventory:RemoveItem(src, Config.items.doghouse.name, 1) then
        return false, 'Failed to remove dog house from inventory'
    end

    local coordStr = string.format('%.2f,%.2f,%.2f', coords.x, coords.y, coords.z)
    MySQL.query(
        'INSERT INTO murderface_doghouses (citizenid, coords, heading) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE coords = VALUES(coords), heading = VALUES(heading)',
        { citizenid, coordStr, heading }
    )

    doghouseCache[citizenid] = vector3(coords.x, coords.y, coords.z)
    return true
end)

-- Get player's dog house location
lib.callback.register('murderface-pets:server:getDoghouse', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    local citizenid = player.PlayerData.citizenid

    local rows = MySQL.query.await(
        'SELECT coords, heading FROM murderface_doghouses WHERE citizenid = ?',
        { citizenid }
    )
    if not rows or #rows == 0 then return nil end

    local row = rows[1]
    local parts = {}
    for part in row.coords:gmatch('[^,]+') do
        parts[#parts + 1] = tonumber(part)
    end
    if #parts ~= 3 then return nil end
    return { x = parts[1], y = parts[2], z = parts[3], heading = row.heading }
end)

-- Remove dog house (pick up)
lib.callback.register('murderface-pets:server:removeDoghouse', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local citizenid = player.PlayerData.citizenid

    -- Block if breeding active
    local activeBreeding = MySQL.scalar.await(
        "SELECT COUNT(*) FROM murderface_breeding WHERE citizenid = ? AND status IN ('pending', 'ready')",
        { citizenid }
    )
    if activeBreeding and activeBreeding > 0 then
        return false, 'breeding_active'
    end

    local affected = MySQL.update.await(
        'DELETE FROM murderface_doghouses WHERE citizenid = ?',
        { citizenid }
    )
    if affected and affected > 0 then
        doghouseCache[citizenid] = nil
        exports.ox_inventory:AddItem(src, Config.items.doghouse.name, 1)
        return true
    end
    return false
end)

-- Get eligible breeding pairs
lib.callback.register('murderface-pets:server:getBreedingPairs', function(source)
    local src = source
    local items = exports.ox_inventory:GetInventoryItems(src)
    if not items then return {} end

    -- Collect all qualifying pets grouped by model
    local petsByModel = {}
    for _, item in pairs(items) do
        local petCfg = Config.petsByItem[item.name]
        if petCfg and item.metadata and item.metadata.hash then
            local allowed = false
            for _, sp in ipairs(Config.breeding.speciesAllowed) do
                if petCfg.species == sp then allowed = true break end
            end
            if allowed and (item.metadata.level or 0) >= Config.breeding.minBreedLevel then
                petsByModel[petCfg.model] = petsByModel[petCfg.model] or {}
                petsByModel[petCfg.model][#petsByModel[petCfg.model] + 1] = {
                    hash      = item.metadata.hash,
                    name      = item.metadata.name or 'Pet',
                    gender    = item.metadata.gender,
                    item      = item.name,
                    model     = petCfg.model,
                    label     = petCfg.label,
                    level     = item.metadata.level or 0,
                    lastBreedTime = item.metadata.lastBreedTime,
                }
            end
        end
    end

    -- Build pairs: same model, opposite gender, not on cooldown
    local now = os.time()
    local cooldownSec = Config.breeding.breedingCooldownHours * 3600
    local breedingPairs = {}
    for model, pets in pairs(petsByModel) do
        local males, females = {}, {}
        for _, pet in ipairs(pets) do
            local onCooldown = pet.lastBreedTime and (now - pet.lastBreedTime) < cooldownSec
            if not onCooldown then
                if pet.gender == true then
                    males[#males + 1] = pet
                else
                    females[#females + 1] = pet
                end
            end
        end
        for _, m in ipairs(males) do
            for _, f in ipairs(females) do
                breedingPairs[#breedingPairs + 1] = { male = m, female = f, model = model }
            end
        end
    end

    return breedingPairs
end)

-- Start breeding
lib.callback.register('murderface-pets:server:startBreeding', function(source, maleHash, femaleHash)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found' end
    local citizenid = player.PlayerData.citizenid

    -- Verify dog house
    if not doghouseCache[citizenid] then
        return false, 'You need a placed dog house to breed'
    end

    -- Check no existing pending/ready
    local existing = MySQL.scalar.await(
        "SELECT COUNT(*) FROM murderface_breeding WHERE citizenid = ? AND status IN ('pending', 'ready')",
        { citizenid }
    )
    if existing and existing > 0 then
        return false, 'You already have a breeding in progress or a puppy to claim'
    end

    -- Find both pets in inventory
    local items = exports.ox_inventory:GetInventoryItems(src)
    if not items then return false, 'Inventory error' end

    local malePet, femalePet
    for _, item in pairs(items) do
        if item.metadata and item.metadata.hash == maleHash then malePet = item end
        if item.metadata and item.metadata.hash == femaleHash then femalePet = item end
    end

    if not malePet or not femalePet then
        return false, 'Both pets must be in your inventory'
    end

    local maleCfg = Config.petsByItem[malePet.name]
    local femaleCfg = Config.petsByItem[femalePet.name]
    if not maleCfg or not femaleCfg or maleCfg.model ~= femaleCfg.model then
        return false, 'Both pets must be the same breed'
    end

    if malePet.metadata.gender == femalePet.metadata.gender then
        return false, 'You need one male and one female'
    end

    if (malePet.metadata.level or 0) < Config.breeding.minBreedLevel
       or (femalePet.metadata.level or 0) < Config.breeding.minBreedLevel then
        return false, string.format('Both pets must be at least level %d', Config.breeding.minBreedLevel)
    end

    local now = os.time()
    local cooldownSec = Config.breeding.breedingCooldownHours * 3600
    if malePet.metadata.lastBreedTime and (now - malePet.metadata.lastBreedTime) < cooldownSec then
        return false, 'The male pet is still on breeding cooldown'
    end
    if femalePet.metadata.lastBreedTime and (now - femalePet.metadata.lastBreedTime) < cooldownSec then
        return false, 'The female pet is still on breeding cooldown'
    end

    -- Generate offspring metadata (pre-computed, claimed later)
    local offspringMeta = {
        hash           = generateHash(),
        name           = randomName(),
        gender         = math.random(1, 2) == 1,
        age            = 0,
        food           = 100,
        thirst         = 0,
        owner          = player.PlayerData.charinfo,
        level          = Config.breeding.offspring.startLevel,
        XP             = 0,
        health         = maleCfg.maxHealth,
        variation      = Variations.getRandom(maleCfg.model),
        specialization = nil,
        parents        = { maleHash, femaleHash },
    }

    MySQL.query(
        'INSERT INTO murderface_breeding (citizenid, parent1_hash, parent2_hash, offspring_item, offspring_metadata, status) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenid, maleHash, femaleHash, malePet.name, json.encode(offspringMeta), 'pending' }
    )

    -- Set breeding cooldown on both parents
    malePet.metadata.lastBreedTime = now
    femalePet.metadata.lastBreedTime = now
    exports.ox_inventory:SetMetadata(src, malePet.slot, malePet.metadata)
    exports.ox_inventory:SetMetadata(src, femalePet.slot, femalePet.metadata)

    return true
end)

-- Claim offspring
lib.callback.register('murderface-pets:server:claimOffspring', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Player not found' end
    local citizenid = player.PlayerData.citizenid

    local rows = MySQL.query.await(
        "SELECT * FROM murderface_breeding WHERE citizenid = ? AND status = 'ready' LIMIT 1",
        { citizenid }
    )
    if not rows or #rows == 0 then
        return false, 'No puppy ready to claim'
    end

    local row = rows[1]
    local offspringMeta = json.decode(row.offspring_metadata)

    -- Update owner to claiming player's current charinfo
    offspringMeta.owner = player.PlayerData.charinfo

    -- Add offspring item
    if not exports.ox_inventory:AddItem(src, row.offspring_item, 1) then
        return false, 'Inventory full'
    end
    Wait(200)

    -- Find the newly added uninitialized item and stamp its metadata
    local items = exports.ox_inventory:GetInventoryItems(src)
    if items then
        for _, item in pairs(items) do
            if item.name == row.offspring_item and (not item.metadata or not item.metadata.hash) then
                exports.ox_inventory:SetMetadata(src, item.slot, offspringMeta)
                break
            end
        end
    end

    MySQL.update(
        "UPDATE murderface_breeding SET status = 'claimed' WHERE id = ?",
        { row.id }
    )

    return true, offspringMeta.name
end)

-- Check breeding status
lib.callback.register('murderface-pets:server:getBreedingStatus', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    local citizenid = player.PlayerData.citizenid

    local rows = MySQL.query.await(
        "SELECT status, offspring_item, offspring_metadata FROM murderface_breeding WHERE citizenid = ? AND status IN ('pending', 'ready') LIMIT 1",
        { citizenid }
    )
    if not rows or #rows == 0 then return nil end

    local row = rows[1]
    local meta = json.decode(row.offspring_metadata)
    local petCfg = Config.petsByItem[row.offspring_item]
    return {
        status   = row.status,
        petName  = meta.name,
        petLabel = petCfg and petCfg.label or row.offspring_item,
    }
end)

-- Rename pet
lib.callback.register('murderface-pets:server:renamePet', function(source, hash, newName)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local petData = Pet:findByHash(src, hash)

    if not player or not petData or type(newName) ~= 'string' then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_rename'),
            type = 'error'
        })
        return false
    end

    -- Server-side name validation
    local validation = ValidatePetName(newName)
    if validation ~= true then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.blocked_name'),
            type = 'error'
        })
        return false
    end

    if petData.metadata.name == newName then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_rename_same_name'),
            type = 'error'
        })
        return false
    end

    petData.metadata.name = newName
    Pet:saveData(src, hash)

    -- Consume the nametag item
    exports.ox_inventory:RemoveItem(src, Config.items.nametag.name, 1)

    Pet:despawnPet(src, hash, true)
    return newName
end)

-- Register spawned pet
lib.callback.register('murderface-pets:server:registerPet', function(source, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    -- Clear pending spawn flag
    local hash = data.item and data.item.metadata and data.item.metadata.hash
    if hash and pendingSpawns[src] then
        pendingSpawns[src][hash] = nil
    end

    return Pet:setAsSpawned(src, data)
end)

-- Transfer ownership
lib.callback.register('murderface-pets:server:transferOwnership', function(source, data)
    local src = source
    local newOwnerId = tonumber(data.newOwnerId)

    if not newOwnerId then
        return { state = false, msg = Lang:t('error.failed_to_transfer_ownership_could_not_find_new_owner_id') }
    end

    if newOwnerId == src then
        return { state = false, msg = Lang:t('error.failed_to_transfer_ownership_same_owner') }
    end

    local owner = exports.qbx_core:GetPlayer(src)
    local newOwner = exports.qbx_core:GetPlayer(newOwnerId)
    if not owner or not newOwner then
        return { state = false, msg = Lang:t('error.failed_to_transfer_ownership_could_not_find_new_owner_id') }
    end

    local petData = Pet:findByHash(src, data.hash)
    if not petData or type(petData.metadata.owner) ~= 'table' then
        return { state = false, msg = Lang:t('error.failed_to_transfer_ownership_missing_current_owner') }
    end

    if not exports.ox_inventory:RemoveItem(src, Config.items.collar.name, 1) then
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.failed_to_remove_item_from_inventory'),
            type = 'error'
        })
        return { state = false, msg = Lang:t('error.failed_to_remove_item_from_inventory') }
    end

    petData.metadata.owner = newOwner.PlayerData.charinfo
    Pet:saveData(src, data.hash)
    Pet:despawnPet(src, data.hash, true)
    return { state = true, msg = Lang:t('success.successful_ownership_transfer') }
end)

-- ============================
--        Pet Shop
-- ============================

lib.callback.register('murderface-pets:server:buyPet', function(source, petItemName)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local petCfg = Config.petsByItem[petItemName]
    if not petCfg then return false end

    local price = petCfg.price
    local money = player.PlayerData.money

    if (not money.cash or money.cash < price) and (not money.bank or money.bank < price) then
        return false, 'Not enough money'
    end

    local moneyType = (money.cash and money.cash >= price) and 'cash' or 'bank'
    player.Functions.RemoveMoney(moneyType, price, 'pet-purchase')
    exports.ox_inventory:AddItem(src, petItemName, 1)
    return true
end)

lib.callback.register('murderface-pets:server:buySupply', function(source, itemName, price, qty)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    qty = tonumber(qty) or 1
    qty = math.max(1, math.min(10, qty))

    -- Validate against supplies config
    local valid = false
    for _, supply in ipairs(Config.suppliesShop.items) do
        if supply.name == itemName and supply.price == price then
            valid = true
            break
        end
    end
    if not valid then return false end

    local total = price * qty
    local money = player.PlayerData.money
    if (not money.cash or money.cash < total) and (not money.bank or money.bank < total) then
        return false
    end

    local moneyType = (money.cash and money.cash >= total) and 'cash' or 'bank'
    player.Functions.RemoveMoney(moneyType, total, 'pet-supply-purchase')
    exports.ox_inventory:AddItem(src, itemName, qty)
    return true
end)

-- ============================
--         Commands
-- ============================

lib.addCommand('addpet', {
    help = 'Add a pet to your inventory (Admin)',
    params = {
        { name = 'petname', type = 'string', help = 'Pet item name (e.g. murderface_husky)' },
    },
    restricted = 'group.admin',
}, function(source, args)
    exports.ox_inventory:AddItem(source, args.petname, 1)
end)

lib.addCommand('petrestore', {
    help = 'Restore pet data from database backup (Admin)',
    params = {
        { name = 'citizenid', type = 'string', help = 'Player citizenid' },
        { name = 'hash',      type = 'string', help = 'Pet item hash' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local rows = MySQL.query.await(
        'SELECT * FROM murderface_pets WHERE citizenid = ? AND item_hash = ?',
        { args.citizenid, args.hash }
    )
    if not rows or #rows == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            description = 'No backup found for that citizenid/hash combination.',
            type = 'error'
        })
        return
    end

    local row = rows[1]
    local metadata = json.decode(row.metadata)
    TriggerClientEvent('ox_lib:notify', source, {
        description = string.format('Found: %s (%s) — Lv%d, HP %s. Use ox_inventory admin to restore item.',
            metadata.name or '?', row.item_name, metadata.level or 0, tostring(metadata.health or '?')),
        type = 'success'
    })
end)

-- ============================
--   Startup Diagnostics
-- ============================

CreateThread(function()
    Wait(5000) -- wait for ox_inventory to fully initialize
    print('[murderface-pets] ^3Running startup diagnostics...^0')

    -- Check if ox_inventory loaded our items with proper callbacks
    local testItems = { 'murderface_husky', 'murderface_food' }
    for _, itemName in ipairs(testItems) do
        local itemDef = exports.ox_inventory:Items(itemName)
        if itemDef then
            print(('[murderface-pets] ^2ox_inventory has item "%s"^0: label=%s, consume=%s, cb=%s'):format(
                itemName,
                tostring(itemDef.label),
                tostring(itemDef.consume),
                tostring(itemDef.cb ~= nil and 'SET' or 'NIL')
            ))
        else
            print(('[murderface-pets] ^1ox_inventory MISSING item "%s"^0 — items.lua not loaded or item not defined!'):format(itemName))
        end
    end

    -- Verify Config.petsByItem lookup table
    local petCount = 0
    for _ in pairs(Config.petsByItem) do petCount = petCount + 1 end
    print(('[murderface-pets] Config.petsByItem has %d entries'):format(petCount))
    print('[murderface-pets] ^3Diagnostics complete.^0')
end)

-- ============================
--       Saving Thread
-- ============================

CreateThread(function()
    local statTickCounter = 0
    local statInterval = math.max(1, math.floor((Config.dataUpdateInterval * 1000) / SAVE_INTERVAL))

    while true do
        Wait(SAVE_INTERVAL)
        statTickCounter = statTickCounter + 1
        local processStats = statTickCounter >= statInterval
        if processStats then statTickCounter = 0 end

        for src, activePets in pairs(Pet.players) do
            for hash in pairs(activePets) do
                Pet:saveData(src, hash, false, processStats)
            end
        end
    end
end)
