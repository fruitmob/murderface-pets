-- murderface-pets: Server-side helper functions
-- XP system, cooldowns, pet initialization, stat update logic.

math.randomseed(os.time())

Update = {}

-- ============================
--     Hash Generation
-- ============================

local hashChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

--- Generate a unique identifier for pet tracking
---@return string hash 15-character alphanumeric string
function generateHash()
    local parts = {}
    for i = 1, 15 do
        local idx = math.random(1, #hashChars)
        parts[i] = hashChars:sub(idx, idx)
    end
    return table.concat(parts)
end

-- ============================
--        Name Generator
-- ============================

local petNames = {
    'Ace', 'Apollo', 'Archie', 'Atlas', 'Bandit', 'Bear', 'Biscuit',
    'Blaze', 'Blue', 'Bolt', 'Bones', 'Boots', 'Bruno', 'Buster',
    'Cash', 'Chewy', 'Clover', 'Comet', 'Copper', 'Diesel',
    'Duke', 'Echo', 'Felix', 'Finn', 'Ghost', 'Gizmo', 'Gunner',
    'Harley', 'Hawk', 'Hunter', 'Jasper', 'Jinx', 'Koda', 'Leo',
    'Loki', 'Lucky', 'Luna', 'Maple', 'Maverick', 'Moose', 'Nala',
    'Nico', 'Nova', 'Oakley', 'Ollie', 'Onyx', 'Orion', 'Ozzy',
    'Pepper', 'Rascal', 'Rebel', 'Rex', 'Rocco', 'Rogue', 'Rusty',
    'Sage', 'Scout', 'Shadow', 'Simba', 'Smokey', 'Sparky', 'Storm',
    'Tank', 'Thor', 'Titan', 'Tucker', 'Turbo', 'Ziggy', 'Zeus',
}

--- Pick a random name for a new pet
---@return string
function randomName()
    return petNames[math.random(#petNames)]
end

-- ============================
--     XP / Level System
-- ============================

--- Calculate total XP needed to reach a given level
--- Quadratic curve: 75 + level^2 * 15
---@param level number Target level
---@return number xp
local function xpForLevel(level)
    if level <= 0 then return 0 end
    return 75 + (level * level * 15)
end

--- Determine current level from accumulated XP
---@param xp number Total XP
---@return number level
local function levelFromXp(xp)
    local maxLevel = Config.balance.maxLevel
    for lvl = maxLevel, 1, -1 do
        if xp >= xpForLevel(lvl) then
            return lvl
        end
    end
    return 0
end

--- XP awarded per server tick (scales with level)
---@param level number Current pet level
---@return number xpGain
local function xpPerTick(level)
    return math.max(1, math.floor(Config.xp.passive - (level * 0.15)))
end

-- ============================
--     Cooldown System
-- ============================

local cooldowns = {}

--- Check if a player is on item-use cooldown. Starts one if not.
---@param src number Player source
---@return number remaining Seconds remaining (0 = ready)
function CheckCooldown(src)
    local now = os.time()
    local last = cooldowns[src]
    if last and (now - last) < Config.itemCooldown then
        return Config.itemCooldown - (now - last)
    end
    cooldowns[src] = now
    return 0
end

--- Remove a player's cooldown entry
---@param src number Player source
function ClearCooldown(src)
    cooldowns[src] = nil
end

-- ============================
--     Pet Initialization
-- ============================

--- Set up metadata on a newly purchased pet item
---@param src number Player source
---@param item table { name, slot, metadata }
function InitPet(src, item)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local petCfg = Config.petsByItem[item.name]
    if not petCfg then return end

    local metadata = {
        hash           = generateHash(),
        name           = randomName(),
        gender         = math.random(1, 2) == 1,
        age            = 0,
        food           = 100,
        thirst         = 0,
        owner          = player.PlayerData.charinfo,
        level          = 0,
        XP             = 0,
        health         = petCfg.maxHealth,
        variation      = Variations.getRandom(petCfg.model),
        specialization = nil,
    }

    exports.ox_inventory:SetMetadata(src, item.slot, metadata)
    item.metadata = metadata

    if Config.customizeAfterPurchase then
        TriggerClientEvent('murderface-pets:client:customizePet', src, item, {
            coats         = Variations.getNames(petCfg.model),
            petConfig     = petCfg,
            disableRename = false,
            processType   = 'init',
        })
    end
end

-- ============================
--     Customization Event
-- ============================

RegisterNetEvent('murderface-pets:server:applyCustomization', function(item, processType)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local petCfg = Config.petsByItem[item.name]
    if not petCfg then return end

    local items = exports.ox_inventory:Search(src, 'slots', item.name)
    if not items then return end

    local serverItem
    for _, v in pairs(items) do
        if v.metadata and v.metadata.hash == item.metadata.hash then
            serverItem = v
            break
        end
    end
    if not serverItem then return end

    -- B4: Server-side name validation before applying any customization
    if item.metadata.name then
        local nameCheck = ValidatePetName(item.metadata.name)
        if nameCheck ~= true then
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'Invalid pet name.',
                type = 'error'
            })
            return
        end
    end

    if processType == Config.items.groomingkit.name then
        -- Grooming: preserve server-side stats, only allow appearance change
        local petData = Pet:findByHash(src, item.metadata.hash)
        if not petData then return end

        if player.PlayerData.charinfo.phone ~= petData.metadata.owner.phone then
            TriggerClientEvent('ox_lib:notify', src, {
                description = Lang:t('error.not_owner_of_pet'),
                type = 'error'
            })
            return
        end

        item.metadata.age            = petData.metadata.age
        item.metadata.food           = petData.metadata.food
        item.metadata.thirst         = petData.metadata.thirst
        item.metadata.owner          = player.PlayerData.charinfo
        item.metadata.level          = petData.metadata.level
        item.metadata.XP             = petData.metadata.XP
        item.metadata.health         = petData.metadata.health
        item.metadata.specialization = petData.metadata.specialization
    else
        -- Fresh initialization
        item.metadata.age            = 0
        item.metadata.food           = 100
        item.metadata.thirst         = 0
        item.metadata.owner          = player.PlayerData.charinfo
        item.metadata.level          = 0
        item.metadata.XP             = 0
        item.metadata.health         = petCfg.maxHealth
        item.metadata.specialization = nil
    end

    exports.ox_inventory:SetMetadata(src, serverItem.slot, item.metadata)

    if processType == Config.items.groomingkit.name then
        exports.ox_inventory:RemoveItem(src, Config.items.groomingkit.name, 1)
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('success.successful_grooming'),
            type = 'success'
        })
        Pet:despawnPet(src, item.metadata.hash, true)
    end
end)

-- ============================
--      Update Functions
-- ============================

--- Award XP and handle level-ups
---@param src number Player source
---@param petData table Active pet entry from Pet.players
function Update.xp(src, petData)
    local currentLevel = levelFromXp(petData.metadata.XP)
    if currentLevel >= Config.balance.maxLevel then return end

    if petData.metadata.XP == 0 then
        petData.metadata.XP = 75
    end

    local gain = xpPerTick(currentLevel)

    -- Companion specialization: bonus passive XP
    if petData.metadata.specialization == 'companion' then
        local specCfg = Config.specializations and Config.specializations.companion
        if specCfg and specCfg.xpBonusMult then
            gain = math.floor(gain * specCfg.xpBonusMult)
        end
    end

    petData.metadata.XP = petData.metadata.XP + gain

    local newLevel = levelFromXp(petData.metadata.XP)
    if newLevel > currentLevel then
        petData.metadata.level = newLevel
        local msg = string.format(Lang:t('info.level_up'), petData.metadata.name, newLevel)
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'inform' })
        -- O3: Only sync XP to client on level-up (not every passive tick)
        TriggerClientEvent('murderface-pets:client:syncXP', src,
            petData.metadata.hash, petData.metadata.XP, newLevel)
    end
end

--- Sync pet health from game entity to metadata
---@param src number Player source
---@param data table { netId = number }
---@param petData table Active pet entry
function Update.health(src, data, petData)
    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if entity == 0 then return end

    local currentHealth = GetEntityHealth(entity)
    if petData.metadata.health == currentHealth then return end

    if currentHealth <= 100 then
        local msg = string.format(Lang:t('error.pet_died'), petData.metadata.name)
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'error' })
        currentHealth = 0
    end

    petData.metadata.health = currentHealth
    Pet:saveData(src, petData.metadata.hash)
end

--- Decrease food per tick; drain health when starving
---@param petData table Active pet entry
function Update.food(petData)
    local bal = Config.balance.food
    if petData.metadata.food <= 0 then
        petData.metadata.food = 0
        if petData.metadata.health > 100 then
            petData.metadata.health = petData.metadata.health - bal.healthDrainWhenStarving
        end
        return
    end
    local drain = bal.decreasePerTick
    if petData.nearDoghouse and Config.breeding and Config.breeding.restBonus then
        drain = drain * Config.breeding.restBonus.foodDrainMult
    end
    petData.metadata.food = math.max(0, petData.metadata.food - drain)
end

--- Increase thirst per tick; drain health when dehydrated
---@param petData table Active pet entry
function Update.thirst(petData)
    local bal = Config.balance.thirst
    if petData.metadata.thirst >= 100 then
        petData.metadata.thirst = 100
        if petData.metadata.health > 100 then
            petData.metadata.health = petData.metadata.health - bal.healthDrainWhenDehydrated
        end
        return
    end
    local increase = bal.increasePerTick
    if petData.nearDoghouse and Config.breeding and Config.breeding.restBonus then
        increase = increase * Config.breeding.restBonus.thirstIncreaseMult
    end
    petData.metadata.thirst = math.min(100, petData.metadata.thirst + increase)
end

-- ============================
--   Activity XP Cooldowns
-- ============================

local activityCooldowns = {} -- keyed by "src:action"

--- Check if a player is on cooldown for a specific XP action.
--- Returns true if still on cooldown; otherwise stamps the time and returns false.
---@param src number Player source
---@param action string Action name
---@return boolean onCooldown
function IsOnActivityCooldown(src, action)
    local key = src .. ':' .. action
    local cd = Config.activityCooldowns[action]
    if not cd then return false end -- no cooldown for this action

    local now = os.time()
    local last = activityCooldowns[key]
    if last and (now - last) < cd then
        return true
    end
    activityCooldowns[key] = now
    return false
end

--- Clean up activity cooldowns for a disconnecting player
---@param src number Player source
function ClearActivityCooldowns(src)
    local prefix = src .. ':'
    for key in pairs(activityCooldowns) do
        if key:sub(1, #prefix) == prefix then
            activityCooldowns[key] = nil
        end
    end
end

-- ============================
--     XP Award (Activity)
-- ============================

--- Award XP from an active action (hunt, trick, petting, etc.)
--- Handles level-up checks and milestone celebrations.
---@param src number Player source
---@param petData table Active pet entry from Pet.players
---@param amount number XP to award
function Update.xpAward(src, petData, amount)
    local currentLevel = levelFromXp(petData.metadata.XP)
    if currentLevel >= Config.balance.maxLevel then return end

    petData.metadata.XP = petData.metadata.XP + amount
    local newLevel = levelFromXp(petData.metadata.XP)

    if newLevel > currentLevel then
        petData.metadata.level = newLevel
        local msg = string.format(Lang:t('info.level_up'), petData.metadata.name, newLevel)
        TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'inform' })

        -- Check milestone
        for _, milestone in ipairs(Config.progression.milestones) do
            if newLevel == milestone then
                TriggerClientEvent('murderface-pets:client:milestone', src,
                    petData.metadata.hash, newLevel, petData.metadata.name)
                break
            end
        end
    end

    TriggerClientEvent('murderface-pets:client:syncXP', src,
        petData.metadata.hash, petData.metadata.XP, newLevel)
end

-- ============================
--     Health Regen
-- ============================

--- Passive health regeneration for high-level pets
---@param petData table Active pet entry from Pet.players
function Update.healthRegen(petData)
    local regenLevel = Config.progression.healthRegenLevel
    local level = petData.metadata.level or 0
    if level < regenLevel then return end

    -- Only regen if alive and not at max HP
    if petData.metadata.health <= 100 then return end

    local petCfg = Config.petsByItem[petData.itemName]
    if not petCfg then return end

    local maxHP = petCfg.maxHealth
    if petData.metadata.health >= maxHP then return end

    local regenAmount = Config.progression.healthRegenAmount

    -- Companion specialization: bonus health regen
    if petData.metadata.specialization == 'companion' then
        local specCfg = Config.specializations and Config.specializations.companion
        if specCfg and specCfg.healthRegenMult then
            regenAmount = regenAmount * specCfg.healthRegenMult
        end
    end

    -- Rest bonus: extra regen near dog house
    if petData.nearDoghouse and Config.breeding and Config.breeding.restBonus then
        regenAmount = regenAmount + Config.breeding.restBonus.healthRegenBonus
    end

    petData.metadata.health = math.min(maxHP, petData.metadata.health + regenAmount)
end
