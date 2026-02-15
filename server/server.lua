-- murderface-pets: Main server logic
-- Pet lifecycle, inventory integration, shops, persistence, and database backup.

-- ============================
--      Local Helpers
-- ============================

local SAVE_INTERVAL = 5000
local MAX_AGE = 60 * 60 * 24 * 10 -- 10 days of active time

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

    -- Check spawn limit
    local count = 0
    if self.players[src] then
        for _ in pairs(self.players[src]) do count = count + 1 end
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
function Pet:saveData(src, hash, silent)
    local petData = self:findByHash(src, hash)
    if not petData then return end

    -- Skip dead pets
    if petData.metadata.health <= 0 then return end

    -- Process tick updates
    if petData.metadata.health > 100 then
        if petData.metadata.age < MAX_AGE then
            petData.metadata.age = petData.metadata.age + math.floor(SAVE_INTERVAL / 1000)
        end
        Update.food(petData)
        Update.thirst(petData)
    else
        petData.metadata.health = 0
        if not silent then
            TriggerClientEvent('murderface-pets:client:forceKill', src, hash, 'hunger')
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
end)

-- ============================
--       Despawn Events
-- ============================

RegisterNetEvent('murderface-pets:server:setAsDespawned', function(hash)
    if not hash then return end
    Pet:setAsDespawned(source, hash)
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
--- ox_inventory's useExport wrapper prepends a nil arg, so first param is discarded.
---@param _ nil Placeholder (useExport passes nil)
---@param event string 'usingItem' | 'usedItem'
---@param item table Item definition from ox_inventory
---@param inventory table Full inventory object (has .id, .items)
---@param slot number Slot number
local function handlePetItem(_, event, item, inventory, slot)
    if event ~= 'usingItem' then return end

    local src = inventory.id
    local petCfg = Config.petsByItem[item.name]
    if not petCfg then return false end

    local invItem = inventory.items[slot]
    local metadata = invItem and invItem.metadata

    -- First use: initialize if no hash
    if type(metadata) ~= 'table' or not metadata.hash then
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

    Pet:spawnPet(src, petCfg.model, { name = item.name, slot = slot, metadata = metadata })
    return false
end

for _, pet in ipairs(Config.pets) do
    exports(pet.item, handlePetItem)
end

-- ============================
--    Supply Item Exports
-- ============================

exports(Config.items.food.name, function(_, event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:feedPet', inventory.id)
        return false
    end
end)

exports(Config.items.collar.name, function(_, event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:transferOwnership', inventory.id)
        return false
    end
end)

exports(Config.items.nametag.name, function(_, event, item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:renamePet', inventory.id, item)
        return false
    end
end)

exports(Config.items.firstaid.name, function(_, event)
    if event == 'usingItem' then
        return false -- consumed via ox_target heal/revive interaction
    end
end)

exports(Config.items.groomingkit.name, function(_, event, _item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('murderface-pets:client:groomPet', inventory.id)
        return false
    end
end)

exports(Config.items.waterbottle.name, function(_, event, item, inventory, slot)
    if event == 'usingItem' then
        local src = inventory.id
        local refillCost = Config.items.waterbottle.refillCost
        local count = exports.ox_inventory:GetItemCount(src, 'water_bottle')
        if not count or count < refillCost then
            TriggerClientEvent('ox_lib:notify', src, {
                description = string.format(Lang:t('error.not_enough_water_bottles'), refillCost),
                type = 'error'
            })
            return false
        end
        exports.ox_inventory:RemoveItem(src, 'water_bottle', refillCost)
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
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'Feeding was successful, wait a moment for it to take effect!',
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

    TriggerClientEvent('ox_lib:notify', src, {
        description = Lang:t('success.successful_drinking'),
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
--       Saving Thread
-- ============================

CreateThread(function()
    while true do
        Wait(SAVE_INTERVAL)
        for src, activePets in pairs(Pet.players) do
            for hash in pairs(activePets) do
                Pet:saveData(src, hash)
            end
        end
    end
end)
