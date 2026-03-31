-- murderface-pets: Main client logic
-- Hash-based ActivePed class, spawning, health tracking, AFK behavior, item events.

-- ============================
--   Forward-declared State Tables
--   (must be above ActivePed so :remove() can reference them)
-- ============================
local followCooldowns = {}      -- { [hash] = gameTimer }
local lastFollowSpeed = {}      -- { [hash] = speed }
local petSlotIndex = {}         -- { [hash] = 1 or 2 } offset slot
local idleTimers = {}           -- { [hash] = seconds stopped }
local idleState = {}            -- { [hash] = 'following'|'idle_sit'|'idle_wander'|'idle_anim' }
local lastVocalize = {}         -- { [hash] = gameTimer }
local lastWaterReact = {}       -- { [hash] = gameTimer }
local petWaterState = {}        -- { [hash] = bool }
local reviveFlags = {}          -- { [hash] = bool }
local wasPlayerSprinting = {}   -- { [hash] = bool }

-- ============================
--         Pet Class
-- ============================

ActivePed = {
    pets = {},          -- { [hash] = petData }
    currentHash = nil,  -- hash of currently controlled pet
}

--- Register a new spawned pet
function ActivePed:add(model, hostile, item, ped)
    local hash = item.metadata.hash
    local petCfg = Config.petsByItem[item.name]

    self.pets[hash] = {
        model      = model,
        modelString = petCfg and petCfg.model or model,
        entity     = ped,
        hostile    = hostile,
        item       = item,
        lastCoord  = GetEntityCoords(ped),
        variation  = item.metadata.variation,
        health     = item.metadata.health,
        maxHealth  = petCfg and petCfg.maxHealth or 200,
        canHunt    = petCfg and petCfg.canHunt or false,
        animClass  = petCfg and petCfg.animClass or nil,
        petConfig  = petCfg,
    }

    self.currentHash = hash
end

--- Return the currently controlled pet data
function ActivePed:read()
    if not self.currentHash then return nil end
    return self.pets[self.currentHash]
end

--- Remove a pet by hash and clean up entity
function ActivePed:remove(hash)
    local petData = self.pets[hash]
    if not petData then return end

    StopGuard(hash)
    StopAggro(hash)
    SetWaiting(hash, false)
    SetBusy(hash, false)
    petSlotIndex[hash] = nil
    -- Clean up all per-pet state tables (prevent memory leaks)
    followCooldowns[hash] = nil
    lastFollowSpeed[hash] = nil
    lastFollowSpeed[hash .. '_offset'] = nil
    idleTimers[hash] = nil
    idleState[hash] = nil
    lastVocalize[hash] = nil
    lastWaterReact[hash] = nil
    petWaterState[hash] = nil
    reviveFlags[hash] = nil
    wasPlayerSprinting[hash] = nil

    if DoesEntityExist(petData.entity) then
        local netId = NetworkGetNetworkIdFromEntity(petData.entity)
        if netId and netId ~= 0 then
            TriggerServerEvent('murderface-pets:server:deleteEntity', netId)
        else
            DeleteEntity(petData.entity)
        end
    end

    self.pets[hash] = nil

    -- If we removed the current pet, switch to another or nil
    if self.currentHash == hash then
        self.currentHash = nil
        for h in pairs(self.pets) do
            self.currentHash = h
            break
        end
    end
end

--- Remove all pets (logout/disconnect)
function ActivePed:removeAll()
    local hashes = {}
    for hash, petData in pairs(self.pets) do
        DeletePed(petData.entity)
        hashes[#hashes + 1] = hash
    end
    TriggerServerEvent('murderface-pets:server:onLogout', hashes)
    self.pets = {}
    self.currentHash = nil
end

--- Switch control to a different pet by hash
function ActivePed:switchControl(hash)
    if self.pets[hash] then
        self.currentHash = hash
    end
end

--- Find a pet by hash
function ActivePed:findByHash(hash)
    return self.pets[hash]
end

--- Get list of all active pets for menu display
function ActivePed:petsList()
    local list = {}
    for hash, data in pairs(self.pets) do
        list[#list + 1] = {
            hash      = hash,
            name      = data.item.metadata.name,
            model     = data.modelString or data.model,
            level     = data.item.metadata.level or 0,
            health    = data.health or data.item.metadata.health or 0,
            maxHealth = data.maxHealth or 0,
            pedHandle = data.entity,
            animClass = data.animClass,
            petConfig = data.petConfig,
        }
    end
    return list
end

-- ============================
--     Waiting State
-- ============================

local waitingPets = {} -- { [hash] = true }

function IsWaiting(hash)
    return waitingPets[hash] == true
end

function SetWaiting(hash, val)
    waitingPets[hash] = val or nil
end

function ClearAllWaiting()
    waitingPets = {}
end

-- ============================
--     Busy State (task lock)
-- ============================

local busyPets = {} -- { [hash] = true }

function IsBusy(hash)
    return busyPets[hash] == true
end

function SetBusy(hash, val)
    busyPets[hash] = val or nil
end

local function ClearAllBusy()
    busyPets = {}
end

-- ============================
--         Spawn Pet
-- ============================

RegisterNetEvent('murderface-pets:client:spawnPet', function(modelName, hostileTowardPlayer, item)
    if Config.debug then
        print(('[murderface-pets] ^3client:spawnPet received^0: model=%s hostile=%s hash=%s'):format(
            tostring(modelName), tostring(hostileTowardPlayer),
            tostring(item and item.metadata and item.metadata.hash)))
    end
    local model = type(modelName) == 'string' and GetHashKey(modelName) or modelName
    local plyPed = PlayerPedId()
    SetCurrentPedWeapon(plyPed, 0xA2719263, true)
    ClearPedTasks(plyPed)

    whistleAnimation(plyPed, 1500)

    if not lib.progressBar({
        duration = Config.callDuration * 1000,
        label = 'Calling companion',
        disable = { move = false, car = false, combat = false, mouse = false },
    }) then
        -- Notify server so pendingSpawn flag is cleared
        if item.metadata and item.metadata.hash then
            TriggerServerEvent('murderface-pets:server:spawnCancelled', item.metadata.hash)
        end
        return
    end

    do
        ClearPedTasks(plyPed)

        local spawnCoord = getSpawnLocation(plyPed)

        -- Create entity server-side so OneSync won't cull it
        local netId = lib.callback.await('murderface-pets:server:createPetEntity', false, {
            model = modelName, pos = spawnCoord
        })

        if not netId then
            lib.notify({ description = 'Failed to spawn pet', type = 'error', duration = 5000 })
            if item.metadata and item.metadata.hash then
                TriggerServerEvent('murderface-pets:server:spawnCancelled', item.metadata.hash)
            end
            return
        end

        -- Resolve server entity to client handle
        local timeout = 0
        while not NetworkDoesNetworkIdExist(netId) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        local ped = NetToPed(netId)
        timeout = 0
        while (not ped or ped == 0 or not DoesEntityExist(ped)) and timeout < 100 do
            Wait(10)
            ped = NetToPed(netId)
            timeout = timeout + 1
        end

        if not ped or ped == 0 or not DoesEntityExist(ped) then
            lib.notify({ description = 'Failed to resolve pet entity', type = 'error', duration = 5000 })
            if item.metadata and item.metadata.hash then
                TriggerServerEvent('murderface-pets:server:spawnCancelled', item.metadata.hash)
            end
            return
        end

        -- Request control of the server-created entity
        NetworkRequestControlOfEntity(ped)
        timeout = 0
        while not NetworkHasControlOfEntity(ped) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if Config.debug then
            print(('[murderface-pets] ^2Resolved server entity^0: netId=%s ped=%s exists=%s health=%s control=%s'):format(
                tostring(netId), tostring(ped), tostring(DoesEntityExist(ped)),
                tostring(GetEntityHealth(ped)), tostring(NetworkHasControlOfEntity(ped))))
        end

        -- Apply client-side ped properties
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, 0)
        SetPedRelationshipGroupHash(ped, GetHashKey('MFPETS_COMPANION'))

        -- Damage resistance: no headshot instakills, heavily reduced incoming damage
        SetPedSuffersCriticalHits(ped, false)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetPedDiesInWater(ped, false)
        SetPedConfigFlag(ped, 65, false) -- CPED_CONFIG_FLAG_DiesInstantlyInWater

        -- Register on server (non-blocking)
        lib.callback('murderface-pets:server:registerPet', false, function() end, {
            item = item, model = modelName, entity = ped
        })

        if hostileTowardPlayer then
            lib.notify({ description = Lang:t('error.not_owner_of_pet'), type = 'error', duration = 7000 })
        end

        ClearPedTasks(ped)
        TaskFollowTargetedPlayer(ped, plyPed, 3.0, true)

        -- Add blip
        if Config.blip.enabled then
            createBlip({
                entity    = ped,
                sprite    = Config.blip.sprite,
                colour    = Config.blip.colour,
                text      = item.metadata.name,
                shortRange = Config.blip.shortRange,
            })
        end

        -- Init client data
        ActivePed:add(modelName, hostileTowardPlayer, item, ped)
        local petData = ActivePed:findByHash(item.metadata.hash)

        -- Apply variation
        if petData.variation then
            Variations.apply(ped, petData.modelString, petData.variation)
        end

        -- Set health
        SetEntityMaxHealth(ped, petData.maxHealth)
        SetEntityHealth(ped, math.floor(petData.item.metadata.health))
        local currentHealth = GetEntityHealth(ped)

        -- ox_target interactions
        local petCfg = petData.petConfig
        local targetOptions = {
            {
                name = 'mfpets_heal',
                icon = 'fas fa-first-aid',
                label = 'Heal',
                canInteract = function(entity)
                    return not IsEntityDead(entity) and ActivePed:read() ~= nil
                end,
                onSelect = function()
                    requestHealingProcess(ped, item, 'Heal')
                end,
                distance = 1.5,
            },
            {
                name = 'mfpets_revive',
                icon = 'fas fa-first-aid',
                label = 'Revive Pet',
                canInteract = function(entity)
                    return IsEntityDead(entity) and ActivePed:read() ~= nil
                end,
                onSelect = function()
                    if DoesEntityExist(ped) then
                        requestHealingProcess(ped, item, 'revive')
                    end
                end,
                distance = 1.5,
            },
            {
                name = 'mfpets_drink',
                icon = 'fas fa-flask',
                label = 'Drink from water bottle',
                canInteract = function(entity)
                    return not IsEntityDead(entity) and ActivePed:read() ~= nil
                end,
                onSelect = function()
                    if DoesEntityExist(ped) then
                        startDrinkingAnimation()
                    end
                end,
                distance = 1.5,
            },
        }

        -- Stats viewer
        table.insert(targetOptions, {
            name = 'mfpets_stats',
            icon = 'fas fa-heart-pulse',
            label = 'View Stats',
            canInteract = function(entity)
                return ActivePed:read() ~= nil
            end,
            onSelect = function()
                local pd = ActivePed:findByHash(item.metadata.hash)
                if not pd then return end
                local md = pd.item.metadata
                local cfg = pd.petConfig
                local currentHP = DoesEntityExist(ped) and (GetEntityHealth(ped) - 100) or math.floor(md.health or 0)
                local maxHP = (cfg and cfg.maxHealth or pd.maxHealth or 0) - 100

                local level = md.level or 0
                local title = Config.getLevelTitle(level)
                local currentXP = md.XP or 0
                local nextLevelXP = Config.xpForLevel(level + 1)

                local statsMeta = {
                    { label = 'Level', value = string.format('%d (%s)', level, title) },
                    { label = 'XP', value = string.format('%d / %d', currentXP, nextLevelXP) },
                    { label = 'Sex', value = md.gender and 'Male' or 'Female' },
                    { label = 'Health', value = ('%d / %d'):format(math.max(0, currentHP), maxHP) },
                    { label = 'Food', value = ('%.0f%%'):format(md.food or 0) },
                    { label = 'Thirst', value = ('%.0f%%'):format(md.thirst or 0) },
                }

                if md.specialization and Config.specializations then
                    local specCfg = Config.specializations[md.specialization]
                    statsMeta[#statsMeta + 1] = {
                        label = 'Specialization',
                        value = specCfg and specCfg.label or md.specialization,
                    }
                end

                lib.registerContext({
                    id = 'mfpets_stats_view',
                    title = (md.name or 'Pet') .. ' — Stats',
                    options = {
                        {
                            title = cfg and cfg.label or 'Companion',
                            icon = cfg and cfg.icon or 'paw',
                            iconColor = '#12b886',
                            description = string.format('%s — %s',
                                cfg and cfg.species:gsub('^%l', string.upper) or '',
                                title),
                            metadata = statsMeta,
                        },
                    },
                })
                lib.showContext('mfpets_stats_view')
            end,
            distance = 2.5,
        })

        -- Add petting option only for pets that support it
        if petCfg and petCfg.canPet then
            table.insert(targetOptions, 1, {
                name = 'mfpets_pet',
                icon = 'fas fa-paw',
                label = 'Pet',
                canInteract = function(entity)
                    return not IsEntityDead(entity) and ActivePed:read() ~= nil
                end,
                onSelect = function(data)
                    local entity = data.entity
                    local playerPed = PlayerPedId()
                    makeEntityFaceEntity(playerPed, entity)
                    makeEntityFaceEntity(entity, playerPed)

                    local coords = GetEntityCoords(playerPed)
                    local forward = GetEntityForwardVector(playerPed)
                    SetEntityCoords(entity, coords + forward * 1.0, 0, 0, 0, 0)
                    TaskPause(entity, 5000)

                    -- Play pet and player petting animations
                    Anims.playSub(entity, petCfg.animClass, 'petting', 'pet_anim')
                    Anims.playSub(playerPed, petCfg.animClass, 'petting', 'human_anim')

                    -- Award petting XP
                    TriggerServerEvent('murderface-pets:server:updatePetStats',
                        item.metadata.hash, { key = 'activity', action = 'petting' })

                    if Config.stressRelief.enabled then
                        TriggerServerEvent(Config.stressRelief.event,
                            math.random(Config.stressRelief.amount.min, Config.stressRelief.amount.max))
                    end
                end,
                distance = 1.5,
            })
        end

        exports.ox_target:addLocalEntity(ped, targetOptions)

        if Config.debug then
            print(('[murderface-pets] ^3hostile check^0: hostile=%s health=%s entityExists=%s'):format(
                tostring(petData.hostile), tostring(currentHealth), tostring(DoesEntityExist(ped))))
        end

        if petData.hostile then
            TriggerServerEvent('murderface-pets:server:despawnNotOwned', petData.item.metadata.hash)
            return
        end

        if currentHealth > 100 then
            createActivePetThread(ped, item)
        else
            if Config.debug then
                print(('[murderface-pets] ^1Pet health <= 100, no active thread started^0: health=%s'):format(
                    tostring(currentHealth)))
            end
        end
    end
end)

-- ============================
--     Healing Process
-- ============================

function requestHealingProcess(ped, item, processType)
    local count = exports.ox_inventory:Search('count', Config.items.firstaid.name)
    if not count or count < 1 then
        lib.notify({ description = Lang:t('error.not_enough_first_aid'), type = 'error', duration = 7000 })
        return
    end

    local plyPed = PlayerPedId()
    local petData = ActivePed:findByHash(item.metadata.hash)
    if not petData then return end

    local timeout = Config.items.firstaid.duration
    if processType == 'Heal' then
        makeEntityFaceEntity(ped, plyPed)
        TaskPause(ped, 5000)
    end
    makeEntityFaceEntity(plyPed, ped)

    -- Play medic animation on player
    Anims.play(plyPed, 'player', 'revive')

    if lib.progressBar({
        duration = timeout * 1000,
        label = processType == 'Heal' and 'Healing' or 'Reviving',
        disable = { move = true, car = true, combat = true, mouse = false },
    }) then
        TriggerServerEvent('murderface-pets:server:healPet',
            item.metadata.hash, petData.modelString, processType)
        TaskFollowTargetedPlayer(ped, plyPed, 3.0, false)
    end
end

-- ============================
--     Update Health
-- ============================

RegisterNetEvent('murderface-pets:client:updateHealth', function(hash, amount)
    local petData = ActivePed:findByHash(hash)
    if petData and DoesEntityExist(petData.entity) then
        SetEntityHealth(petData.entity, math.floor(amount))
    end
end)

-- ============================
--     Revive Pet In-Place
-- ============================
-- Resurrects the pet entity on the ground instead of despawning.
-- Breaks the death loop by setting a revive flag the loop checks.

RegisterNetEvent('murderface-pets:client:revivePet', function(hash, newHealth)
    local petData = ActivePed:findByHash(hash)
    if not petData then return end

    local ped = petData.entity
    if not DoesEntityExist(ped) then return end

    -- Signal the death loop to stop
    reviveFlags[hash] = true

    -- Resurrect the ped using native resurrection
    local pos = GetEntityCoords(ped)
    ResurrectPed(ped)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHealth(ped, math.floor(newHealth))
    ClearPedTasks(ped)

    -- Restore companion state
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, 0)
    SetPedRelationshipGroupHash(ped, GetHashKey('MFPETS_COMPANION'))
    SetPedSuffersCriticalHits(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)

    -- Update client data
    petData.health = newHealth
    petData.item.metadata.health = newHealth

    -- Resume following owner
    Wait(500)
    local plyPed = PlayerPedId()
    TaskFollowTargetedPlayer(ped, plyPed, 1.5, true)

    -- Restart the pet thread (the old one exited when pet died)
    createActivePetThread(ped, petData.item)

    lib.notify({ description = (petData.item.metadata.name or 'Pet') .. ' has been revived!', type = 'success', duration = 5000 })
end)

-- ============================
--     AFK Wandering
-- ============================

-- ============================
--   Natural Companion System
-- ============================
-- Pets act like pets: they idle naturally, defend you automatically,
-- react to the environment, vocalize, and match your pace.
-- No menus or toggles needed for basic companion behavior.

--- Get the X and Y offset for a pet so multiple pets don't share the same follow target.
--- Pet 1 walks on the left-behind, Pet 2 on the right-behind.
--- The Y offsets are staggered so GTA's navmesh treats them as different destinations.
---@param hash string Pet hash
---@return number xOffset, number yBehindOffset
local function getPetOffset(hash)
    if not petSlotIndex[hash] then
        local used = {}
        for _, slot in pairs(petSlotIndex) do used[slot] = true end
        petSlotIndex[hash] = used[1] and 2 or 1
    end
    if petSlotIndex[hash] == 1 then
        return -1.5, -1.5  -- left side, directly behind
    else
        return 1.5, -2.5   -- right side, slightly further back (staggered)
    end
end
local lastNearbyPedBark = 0     -- global cooldown for barking at strangers
local lastPetInteract = 0       -- cooldown for pet-to-pet interactions
local lastStrangerScan = 0      -- throttle GetGamePool('CPed') scans

--- Determine the right follow speed based on player state AND pet distance.
---@param plyPed number Player ped
---@param level number Pet level
---@param dist? number Distance between pet and player (optional)
---@return number speed
local function getContextualSpeed(plyPed, level, dist)
    local baseSpeed = Config.getFollowSpeed(level)
    dist = dist or 0

    -- Far away: always sprint
    if dist > 10.0 then
        return math.max(baseSpeed, 5.0)
    elseif dist > 5.0 then
        return math.max(baseSpeed, 4.0)
    end

    -- Close: match player pace
    if IsPedSprinting(plyPed) then
        return math.max(baseSpeed, 5.0)
    elseif IsPedRunning(plyPed) then
        return math.max(baseSpeed, 3.5)
    elseif IsPedWalking(plyPed) then
        return 1.5
    else
        return baseSpeed
    end
end

--- Get the move rate multiplier for SetPedMoveRateOverride
--- This physically makes the pet move faster, separate from the task speed
---@param plyPed number Player ped
---@param dist number Distance to player
---@return number rate (1.0 = normal)
local function getMoveRate(plyPed, dist)
    local rates = Config.progression.moveRate
    if not rates then return 1.0 end

    -- Far behind: crank it up to catch up
    if dist > 10.0 then
        return rates.catchUp or 1.8
    end

    -- Match player movement state
    if IsPedSprinting(plyPed) then
        return rates.sprint or 1.5
    elseif IsPedRunning(plyPed) then
        return rates.jogging or 1.35
    elseif IsPedWalking(plyPed) then
        return rates.walking or 1.2
    else
        return rates.idle or 1.0
    end
end

--- Natural idle behavior — runs for ALL pets when player stops moving
---@param ped number Pet entity
---@param plyPed number Player entity
---@param hash string Pet hash
---@param animClass string|nil Animation class
---@param petConfig table|nil Pet config
local function ambientBehavior(ped, plyPed, hash, animClass, petConfig)
    local cfg = Config.balance.ambient
    if not cfg or not cfg.enabled then return end

    -- Safety: bail if entity is gone
    if not DoesEntityExist(ped) then return end

    -- Skip pets in special states
    if IsGuarding(hash) then return end
    if IsBusy(hash) then return end
    if IsCarrying(hash) then return end
    if IsPedInAnyVehicle(ped, false) then return end
    if IsPedInCombat(ped) then return end
    if IsEntityDead(ped) then return end

    local playerStopped = IsPedStopped(plyPed) and not IsPedInAnyVehicle(plyPed, false)
    local now = GetGameTimer()

    -- ---- Sprint excitement: pet barks happily when owner sprints ----
    if cfg.sprintExcitement and not IsWaiting(hash) then
        local sprinting = IsPedSprinting(plyPed)
        if sprinting and not wasPlayerSprinting[hash] then
            if animClass and math.random() < 0.4 then
                SetAnimalMood(ped, 1) -- playful
                PlayAnimalVocalization(ped, 3, 'bark')
            end
        end
        wasPlayerSprinting[hash] = sprinting
    end

    -- ---- Random ambient vocalizations while moving ----
    if not playerStopped and not IsWaiting(hash) then
        local lastVoc = lastVocalize[hash] or 0
        if now - lastVoc > 15000 and math.random() < cfg.vocalizeChance then
            lastVocalize[hash] = now
            local vocType = math.random() > 0.7 and 'whine' or 'bark'
            PlayAnimalVocalization(ped, 3, vocType)
        end
    end

    -- ---- Bark at strangers who approach ----
    -- Throttle GetGamePool scans to every 5 seconds (expensive call)
    if cfg.reactToNearbyPeds and now - lastNearbyPedBark > cfg.nearbyPedCooldown and now - lastStrangerScan > 5000 then
        lastStrangerScan = now
        local petPos = GetEntityCoords(ped)
        local pedPool = GetGamePool('CPed')
        for _, nearPed in ipairs(pedPool) do
            if nearPed ~= ped and nearPed ~= plyPed
               and not IsPedAPlayer(nearPed)
               and not IsEntityDead(nearPed) then
                local dist = #(petPos - GetEntityCoords(nearPed))
                if dist < cfg.nearbyPedRadius then
                    SetAnimalMood(ped, 0) -- alert
                    PlayAnimalVocalization(ped, 3, 'bark')
                    lastNearbyPedBark = now
                    makeEntityFaceEntity(ped, nearPed)
                    break
                end
            end
        end
    end

    -- ---- Idle behavior when player is standing still ----
    if playerStopped then
        idleTimers[hash] = (idleTimers[hash] or 0) + 1

        local idleSecs = idleTimers[hash]
        local state = idleState[hash] or 'following'

        -- Phase 1: After threshold seconds, pet sits down
        if idleSecs >= cfg.idleThreshold and state == 'following' then
            if animClass and Anims.hasAction(animClass, 'sit') then
                ClearPedTasks(ped)
                Anims.play(ped, animClass, 'sit')
                idleState[hash] = 'idle_sit'
            end

        -- Phase 2: After wanderInterval, pet gets up and sniffs around
        -- If owner has another pet, go interact with them instead of random wandering
        elseif idleSecs >= Config.balance.afk.wanderInterval and state == 'idle_sit' then
            ClearPedTasks(ped)
            local didSibling = false

            -- Check for a sibling pet (same owner, different hash)
            for sibHash, sibData in pairs(ActivePed.pets) do
                if sibHash ~= hash and DoesEntityExist(sibData.entity) and not IsEntityDead(sibData.entity) then
                    local sibDist = #(GetEntityCoords(ped) - GetEntityCoords(sibData.entity))
                    if sibDist < 10.0 then
                        -- Walk over to sibling (non-blocking — CreateThread so pet loop continues)
                        local capPed, capSib = ped, sibData.entity
                        CreateThread(function()
                            if not DoesEntityExist(capPed) or not DoesEntityExist(capSib) then return end
                            makeEntityFaceEntity(capPed, capSib)
                            TaskGoToEntity(capPed, capSib, -1, 0.8, 2.0, 0, 0)
                            SetAnimalMood(capPed, 1)
                            Wait(1500)
                            if DoesEntityExist(capPed) and DoesEntityExist(capSib) then
                                PlayAnimalVocalization(capPed, 3, 'bark')
                                Wait(600)
                                PlayAnimalVocalization(capSib, 3, 'bark')
                            end
                        end)
                        didSibling = true
                        break
                    end
                end
            end

            if not didSibling then
                -- No sibling nearby, wander randomly
                local coord = GetEntityCoords(plyPed)
                TaskWanderInArea(ped, coord.x, coord.y, coord.z, 4.0, 2, 8.0)
            end
            idleState[hash] = 'idle_wander'
            if math.random() < 0.5 then
                PlayAnimalVocalization(ped, 3, 'whine')
            end

        -- Phase 3: After animInterval, play a random idle anim (sleep, bark, etc)
        elseif idleSecs >= Config.balance.afk.animInterval and state == 'idle_wander' then
            ClearPedTasks(ped)
            -- Pick a random idle action
            local idleAnims = { 'sit', 'sleep', 'bark' }
            local pick = idleAnims[math.random(#idleAnims)]
            if animClass and Anims.hasAction(animClass, pick) then
                Anims.play(ped, animClass, pick)
            end
            idleState[hash] = 'idle_anim'

        -- Phase 4: After resetAfter, cycle back
        elseif idleSecs >= Config.balance.afk.resetAfter then
            idleTimers[hash] = 0
            idleState[hash] = 'following'
        end
    else
        -- Player moved — reset idle state and resume following
        if idleTimers[hash] and idleTimers[hash] >= cfg.idleThreshold then
            -- Pet was idling, snap back to following
            idleState[hash] = 'following'
        end
        idleTimers[hash] = 0
    end

    -- ---- Pet-to-pet interactions ----
    -- Scan for other pets (MFPETS_COMPANION relationship group) and play social anims
    if cfg.reactToNearbyPeds and now - lastPetInteract > 20000 then -- 20s cooldown
        local petPos = GetEntityCoords(ped)
        local companionHash = GetHashKey('MFPETS_COMPANION')
        local pedPool = GetGamePool('CPed')
        for _, nearPed in ipairs(pedPool) do
            if nearPed ~= ped and nearPed ~= plyPed
               and DoesEntityExist(nearPed) and not IsEntityDead(nearPed)
               and GetPedRelationshipGroupHash(nearPed) == companionHash then

                local dist = #(petPos - GetEntityCoords(nearPed))
                if dist < 6.0 and math.random() < 0.3 then
                    lastPetInteract = now

                    -- Non-blocking social interaction
                    local capPed, capNear, capAnim = ped, nearPed, animClass
                    CreateThread(function()
                        if not DoesEntityExist(capPed) or not DoesEntityExist(capNear) then return end
                        local roll = math.random(3)
                        if roll == 1 then
                            makeEntityFaceEntity(capPed, capNear)
                            TaskGoToEntity(capPed, capNear, -1, 1.0, 2.0, 0, 0)
                            SetAnimalMood(capPed, 1)
                            Wait(2000)
                            if DoesEntityExist(capPed) then PlayAnimalVocalization(capPed, 3, 'bark') end
                        elseif roll == 2 then
                            makeEntityFaceEntity(capPed, capNear)
                            PlayAnimalVocalization(capPed, 3, 'bark')
                            Wait(800)
                            if DoesEntityExist(capNear) then PlayAnimalVocalization(capNear, 3, 'bark') end
                        else
                            if capAnim and Anims.hasAction(capAnim, 'bark') then
                                Anims.play(capPed, capAnim, 'bark')
                            end
                        end
                    end)
                    break
                end
            end
        end
    end

    -- ---- Water reactions ----
    -- Skip entirely if pet is in a vehicle (prevents entity lookup crashes)
    if not IsPedInAnyVehicle(ped, false) and DoesEntityExist(ped) then
        local submerged = GetEntitySubmergedLevel(ped)
        local wasInWater = petWaterState[hash] or false
        local inWater = submerged > 0.15
        local waterCooldown = lastWaterReact[hash] or 0

        if inWater and not wasInWater and now - waterCooldown > 15000 then
            lastWaterReact[hash] = now
            SetAnimalMood(ped, 1)
            PlayAnimalVocalization(ped, 3, 'bark')
            local size = petConfig and petConfig.size or 'large'
            if size == 'small' then
                PlayAnimalVocalization(ped, 3, 'whine')
            end
        elseif not inWater and wasInWater and now - waterCooldown > 15000 then
            lastWaterReact[hash] = now
            if animClass and Anims.hasAction(animClass, 'bark') then
                Anims.play(ped, animClass, 'bark')
            end
            PlayAnimalVocalization(ped, 3, 'bark')
        end
        petWaterState[hash] = inWater
    end
end

--- Smart follow: speed-matches the player with a persistent follow task.
--- Uses the frkn-k9 pattern: offset directly behind player, infinite timeout,
--- only re-issue when speed tier changes or pet drifts very far.
---@param ped number Pet entity
---@param plyPed number Player entity
---@param hash string Pet hash
local function smartFollow(ped, plyPed, hash)
    if not DoesEntityExist(ped) or plyPed == 0 then return end

    -- Skip pets in special states
    if IsWaiting(hash) then return end
    if IsGuarding(hash) then return end
    if IsInAggroCombat(hash) then return end
    if IsBusy(hash) then return end
    if IsCarrying(hash) then return end
    if IsPedInCombat(ped) then return end
    if IsPedInAnyVehicle(ped, false) then return end
    if IsPedInAnyVehicle(plyPed, false) then return end
    if IsEntityDead(ped) then return end

    local petPos = GetEntityCoords(ped)
    local plyPos = GetEntityCoords(plyPed)
    local dist = #(petPos - plyPos)
    local activePed = ActivePed:findByHash(hash)
    local level = activePed and activePed.item.metadata.level or 0

    -- Teleport failsafe: pet is extremely far — warp close and immediately run
    if dist > 50.0 then
        local offsetX, _ = getPetOffset(hash)
        local behindPos = GetOffsetFromEntityInWorldCoords(plyPed, offsetX, -3.0, 0.0)
        local found, groundZ = GetGroundZFor_3dCoord(behindPos.x, behindPos.y, behindPos.z + 2.0, false)
        if found then behindPos = vector3(behindPos.x, behindPos.y, groundZ) end
        SetEntityCoords(ped, behindPos.x, behindPos.y, behindPos.z, false, false, false, false)
        TaskFollowToOffsetOfEntity(ped, plyPed, offsetX, -1.5, 0.0, 5.0, -1, 1.5, true)
        followCooldowns[hash] = GetGameTimer()
        lastFollowSpeed[hash] = 5.0
        return
    end

    -- Apply move rate multiplier (makes the pet physically faster)
    -- Must be called every tick — it resets each frame
    local moveRate = getMoveRate(plyPed, dist)
    SetPedMoveRateOverride(ped, moveRate)

    -- Determine desired speed
    local desiredSpeed = getContextualSpeed(plyPed, level, dist)
    local currentSpeed = lastFollowSpeed[hash] or -1

    -- Per-pet offset so multiple pets don't share the same follow target
    local offsetX, baseOffsetY = getPetOffset(hash)

    -- Determine follow offset: behind normally, AHEAD when sprinting
    local sprinting = IsPedSprinting(plyPed)
    local offsetY = baseOffsetY -- each pet has its own Y offset (staggered)
    if sprinting and Config.progression.sprintAhead and dist < 8.0 then
        offsetY = 2.5 + (petSlotIndex[hash] == 2 and 1.0 or 0.0) -- stagger ahead too
    end

    -- Only re-issue follow when speed tier changes significantly or offset flipped
    local speedChanged = math.abs(desiredSpeed - currentSpeed) > 1.2
    local driftedFar = dist > 25.0
    local lastOffset = lastFollowSpeed[hash .. '_offset'] or -1.5
    local offsetFlipped = (offsetY > 0) ~= (lastOffset > 0)

    if speedChanged or driftedFar or offsetFlipped or currentSpeed < 0 then
        local now = GetGameTimer()
        local lastIssued = followCooldowns[hash] or 0
        if now - lastIssued < 5000 then return end
        followCooldowns[hash] = now
        lastFollowSpeed[hash] = desiredSpeed
        lastFollowSpeed[hash .. '_offset'] = offsetY

        TaskFollowToOffsetOfEntity(ped, plyPed, offsetX, offsetY, 0.0, desiredSpeed, -1, 1.5, true)
    end
end

-- ============================
--   Auto-Defend (gameEvent)
-- ============================
-- Pet automatically attacks anyone who damages the owner.
-- No toggle, no level gate — any pet defends. Higher level = better combat stats.

AddEventHandler('gameEventTriggered', function(eventName, args)
    if eventName ~= 'CEventNetworkEntityDamage' then return end

    local cfg = Config.balance.ambient
    if not cfg or not cfg.autoDefend then return end

    local victim = args[1]
    local attacker = args[2]
    local playerPed = PlayerPedId()

    -- Only react when the OWNER takes damage
    if victim ~= playerPed then return end
    if not attacker or attacker == playerPed or attacker == 0 then return end
    if not DoesEntityExist(attacker) or IsEntityDead(attacker) then return end

    -- Send all active pets to attack the threat
    for hash, petData in pairs(ActivePed.pets) do
        if DoesEntityExist(petData.entity)
           and not IsEntityDead(petData.entity)
           and not IsGuarding(hash)
           and not IsBusy(hash)
           and not IsCarrying(hash)
           and not IsPedInAnyVehicle(petData.entity, false) then

            -- Scale combat ability by level (level 0 = weak, level 50 = lethal)
            local level = petData.item.metadata.level or 0
            local ability = math.min(100, 20 + level * 1.6) -- 20 at level 0, 100 at level 50
            SetPedCombatAbility(petData.entity, math.floor(ability))

            -- Delegate to existing AttackTargetedPed (handles relationship groups, re-engagement)
            local capturedPed = petData.entity
            local capturedAttacker = attacker
            local capturedHash = hash
            SetBusy(capturedHash, true)
            idleTimers[capturedHash] = 0      -- reset idle so pet doesn't re-sit after combat
            idleState[capturedHash] = 'following'
            CreateThread(function()
                AttackTargetedPed(capturedPed, capturedAttacker)
                SetBusy(capturedHash, false)

                -- Award defending XP
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    capturedHash, { key = 'activity', action = 'defending' })
            end)
        end
    end
end)

-- ============================
--   Gunshot Cower (small pets)
-- ============================

local lastGunshotCower = 0

AddEventHandler('gameEventTriggered', function(eventName, args)
    if eventName ~= 'CEventNetworkEntityDamage' then return end

    local cfg = Config.balance.ambient
    if not cfg or not cfg.cowerOnGunshots then return end

    local now = GetGameTimer()
    if now - lastGunshotCower < 10000 then return end -- 10s cooldown

    local victim = args[1]
    if not DoesEntityExist(victim) then return end

    local playerPos = GetEntityCoords(PlayerPedId())
    local eventPos = GetEntityCoords(victim)
    if #(playerPos - eventPos) > cfg.gunshotRadius then return end

    -- Small pets cower, big pets bark
    for hash, petData in pairs(ActivePed.pets) do
        if DoesEntityExist(petData.entity) and not IsEntityDead(petData.entity)
           and not IsPedInCombat(petData.entity)
           and not IsGuarding(hash) then
            local size = petData.petConfig and petData.petConfig.size or 'large'
            if size == 'small' then
                -- Small pet cowers — crouch/sit animation
                if petData.animClass and Anims.hasAction(petData.animClass, 'sit') then
                    Anims.play(petData.entity, petData.animClass, 'sit')
                    PlayAnimalVocalization(petData.entity, 3, 'whine')
                end
            else
                -- Big pet gets alert — bark toward the sound
                SetAnimalMood(petData.entity, 0)
                PlayAnimalVocalization(petData.entity, 3, 'bark')
            end
            lastGunshotCower = now
        end
    end
end)

-- ============================
--     Active Pet Thread
-- ============================

function createActivePetThread(ped, item)
    local count = Config.dataUpdateInterval

    CreateThread(function()
        local tmpcount = 0
        local savedData = ActivePed:findByHash(item.metadata.hash)
        if not savedData then return end

        local finished = false

        -- Auto-start aggro for dogs/wild species (always-on defense)
        local hash = item.metadata.hash
        local species = savedData.petConfig and savedData.petConfig.species
        if species == 'dog' or species == 'wild' then
            if not IsAggroEnabled(hash) then
                StartAggro(hash)
            end
        end

        while DoesEntityExist(ped) and not finished do
            local plyPed = PlayerPedId()

            -- Ensure we still have network control (OneSync can steal it)
            if not NetworkHasControlOfEntity(ped) then
                NetworkRequestControlOfEntity(ped)
            end

            -- Natural behaviors (idle, vocalize, react to environment)
            ambientBehavior(ped, plyPed, hash, savedData.animClass, savedData.petConfig)

            -- Smart following (speed-matches player movement)
            smartFollow(ped, plyPed, hash)

            -- Update server every N seconds
            if tmpcount >= count then
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    savedData.item.metadata.hash, { key = 'XP' })
                tmpcount = 0
            end
            tmpcount = tmpcount + 1

            -- Safety: if entity disappeared or lost network, skip updates
            if not DoesEntityExist(ped) then
                finished = true
                break
            end

            -- Update health (only if entity has valid network ID)
            local currentHealth = GetEntityHealth(savedData.entity)
            local netId = NetworkGetNetworkIdFromEntity(ped)
            if netId and netId ~= 0
               and not IsPedDeadOrDying(savedData.entity)
               and savedData.maxHealth ~= currentHealth
               and savedData.health ~= currentHealth then
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    savedData.item.metadata.hash, {
                        key = 'health',
                        netId = netId,
                    })
                savedData.health = currentHealth
            end

            -- Pet has died — keep dead until revived/despawned
            if IsPedDeadOrDying(savedData.entity, true) then
                DetachLeash(savedData.item.metadata.hash)
                StopGuard(savedData.item.metadata.hash)
                StopAggro(savedData.item.metadata.hash)
                SetWaiting(savedData.item.metadata.hash, false)
                local c_health = GetEntityHealth(savedData.entity)
                if c_health <= 100 then
                    local deathNetId = NetworkGetNetworkIdFromEntity(ped)
                    if deathNetId and deathNetId ~= 0 then
                        TriggerServerEvent('murderface-pets:server:updatePetStats',
                            savedData.item.metadata.hash, {
                                key = 'health',
                                netId = deathNetId,
                            })
                    end
                    -- Prevent GTA auto-revive loop — but check for revive flag
                    -- NOTE: Don't clear reviveFlags here — a revive could already be pending
                    while DoesEntityExist(ped) do
                        if reviveFlags[hash] then
                            -- Server triggered a revive — break out, let the revive handler take over
                            reviveFlags[hash] = nil
                            finished = true
                            break
                        end
                        if not IsPedDeadOrDying(ped, true) and not reviveFlags[hash] then
                            SetEntityHealth(ped, 0)
                        end
                        Wait(1000)
                    end
                    finished = true
                end
            end
            Wait(1000)
        end
    end)
end

-- ============================
--     Force Kill
-- ============================

RegisterNetEvent('murderface-pets:client:forceKill', function(hash, reason)
    local petData = ActivePed:findByHash(hash)
    if not petData then return end
    if not DoesEntityExist(petData.entity) then return end
    if GetEntityHealth(petData.entity) < 100 then return end

    petData.health = 0
    SetEntityHealth(petData.entity, 0)
    lib.notify({
        description = string.format(Lang:t('error.your_pet_died_by'), reason),
        type = 'error',
        duration = 7000
    })
end)

-- ============================
--     Despawn
-- ============================

RegisterNetEvent('murderface-pets:client:despawnPet', function(hash, instant)
    if IsCarrying(hash) then DropPet(hash) end
    DetachLeash(hash)
    StopGuard(hash)
    StopAggro(hash)
    SetWaiting(hash, false)
    SetBusy(hash, false)
    if instant then
        ActivePed:remove(hash)
        TriggerServerEvent('murderface-pets:server:setAsDespawned', hash)
        return
    end

    local plyPed = PlayerPedId()
    SetCurrentPedWeapon(plyPed, 0xA2719263, true)
    ClearPedTasks(plyPed)
    whistleAnimation(plyPed, 1500)

    if lib.progressBar({
        duration = Config.despawnDuration * 1000,
        label = 'Despawning',
        disable = { move = false, car = false, combat = false, mouse = false },
    }) then
        ClearPedTasks(plyPed)
        ActivePed:remove(hash)
        TriggerServerEvent('murderface-pets:server:setAsDespawned', hash)
    end
end)

-- ============================
--     Logout
-- ============================

RegisterNetEvent('qbx_core:client:onLogout', function()
    DropCarriedPet()
    DetachAllLeashes()
    StopAllGuards()
    StopAllAggro()
    ClearAllWaiting()
    ClearAllBusy()
    ActivePed:removeAll()
end)

-- Clean up all entities on resource restart (prevents ghost pets)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DropCarriedPet()
    DetachAllLeashes()
    StopAllGuards()
    StopAllAggro()
    for hash, petData in pairs(ActivePed.pets) do
        if DoesEntityExist(petData.entity) then
            DeleteEntity(petData.entity)
        end
    end
end)

-- ============================
--     Feeding
-- ============================

RegisterNetEvent('murderface-pets:client:feedPet', function()
    local currentPet = ActivePed:read()
    if not currentPet then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
        return
    end

    if GetEntityHealth(currentPet.entity) <= 100 or currentPet.item.metadata.health <= 100 then
        lib.notify({ description = Lang:t('error.your_pet_is_dead'), type = 'error', duration = 7000 })
        return
    end

    if lib.progressBar({
        duration = Config.items.food.duration * 1000,
        label = 'Feeding',
        disable = { move = false, car = false, combat = false, mouse = false },
    }) then
        TriggerServerEvent('murderface-pets:server:feedPet', currentPet.item.metadata.hash)
    end
end)

-- ============================
--     Drinking
-- ============================

function startDrinkingAnimation()
    local currentPet = ActivePed:read()
    if not currentPet then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
        return
    end

    if GetEntityHealth(currentPet.entity) <= 100 or currentPet.item.metadata.health <= 100 then
        lib.notify({ description = Lang:t('error.your_pet_is_dead'), type = 'error', duration = 7000 })
        return
    end

    if lib.progressBar({
        duration = Config.items.waterbottle.duration * 1000,
        label = 'Drinking',
        disable = { move = false, car = false, combat = false, mouse = false },
    }) then
        lib.callback.await('murderface-pets:server:decreaseThirst', false, currentPet.item.metadata.hash)
    end
end

-- ============================
--     Bottle Fill
-- ============================

RegisterNetEvent('murderface-pets:client:fillBottle', function(item)
    if lib.progressBar({
        duration = Config.items.waterbottle.duration * 1000,
        label = 'Filling bottle',
        disable = { move = false, car = false, combat = false, mouse = false },
    }) then
        TriggerServerEvent('murderface-pets:server:fillBottle', item)
    end
end)

-- ============================
--     Rename
-- ============================

RegisterNetEvent('murderface-pets:client:renamePet', function()
    local activePed = ActivePed:read()
    if not activePed then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
        return
    end

    local input = lib.inputDialog('Rename: ' .. activePed.item.metadata.name, {
        { type = 'input', label = 'Pet Name', required = true, min = 1, max = 12 },
    })
    if not input then return end

    local name = input[1]
    if not name then return end

    -- Client-side validation
    local validation = ValidatePetName(name, 12)
    if validation ~= true then
        if validation.reason == 'blocked_word' then
            lib.notify({ description = Lang:t('error.badword_inside_pet_name'), type = 'error', duration = 7000 })
        elseif validation.reason == 'multiple_words' then
            lib.notify({ description = Lang:t('error.more_than_one_word_as_name'), type = 'error', duration = 7000 })
        else
            lib.notify({ description = Lang:t('error.failed_to_validate_name'), type = 'error', duration = 7000 })
        end
        return
    end

    if lib.progressBar({
        duration = Config.items.nametag.duration * 1000,
        label = 'Renaming',
        disable = { move = false, car = false, combat = true, mouse = false },
    }) then
        local result = lib.callback.await('murderface-pets:server:renamePet', false,
            activePed.item.metadata.hash, name)
        if type(result) == 'string' then
            lib.notify({
                description = Lang:t('success.pet_rename_was_successful') .. result,
                type = 'success',
                duration = 7000
            })
        end
    end
end)

-- ============================
--     Transfer Ownership
-- ============================

RegisterNetEvent('murderface-pets:client:transferOwnership', function()
    local activePed = ActivePed:read()
    if not activePed then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
        return
    end

    if not activePed.item.metadata.hash then
        lib.notify({ description = Lang:t('error.failed_to_find_pet'), type = 'error', duration = 7000 })
        return
    end

    local input = lib.inputDialog('New owner id:', {
        { type = 'number', label = 'New Owner ID', required = true },
    })
    if not input then return end

    local cid = input[1]
    if not cid then return end

    if lib.progressBar({
        duration = Config.items.collar.duration * 1000,
        label = 'Transferring ownership',
        disable = { move = false, car = false, combat = true, mouse = false },
    }) then
        local pet = ActivePed:read()
        if not pet then
            lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
            return
        end

        local result = lib.callback.await('murderface-pets:server:transferOwnership', false, {
            newOwnerId = cid,
            hash = pet.item.metadata.hash,
        })

        if result.state == false then
            lib.notify({ description = result.msg, type = 'error', duration = 7000 })
        else
            lib.notify({ description = result.msg, type = 'success', duration = 7000 })
        end
    end
end)

-- ============================
--     Grooming
-- ============================

RegisterNetEvent('murderface-pets:client:groomPet', function()
    local activePed = ActivePed:read()
    if not activePed then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
        return
    end
    TriggerServerEvent('murderface-pets:server:startGrooming', activePed.item)
end)

-- ============================
--     Customization
-- ============================

RegisterNetEvent('murderface-pets:client:customizePet', function(item, petInfo)
    if type(item) ~= 'table' then
        lib.notify({ description = Lang:t('error.failed_to_start_process'), type = 'error', duration = 7000 })
        return
    end

    if petInfo.processType == 'init' then
        openMenu_customization({
            item = item,
            pet_information = {
                pet_variation_list = petInfo.coats,
                disable = { rename = petInfo.disableRename },
                type = petInfo.processType,
            },
        })
        return
    end

    local hasItem = exports.ox_inventory:Search('count', Config.items.groomingkit.name) > 0
    if not hasItem then
        lib.notify({ description = 'You need a grooming kit', type = 'error', duration = 7000 })
        return
    end

    openMenu_customization({
        item = item,
        pet_information = {
            pet_variation_list = petInfo.coats,
            disable = { rename = petInfo.disableRename },
            type = petInfo.processType,
        },
    })
end)

-- ============================
--     Stats Sync (food/thirst)
-- ============================

RegisterNetEvent('murderface-pets:client:syncStats', function(hash, stats)
    local petData = ActivePed:findByHash(hash)
    if not petData then return end
    if stats.food ~= nil then petData.item.metadata.food = stats.food end
    if stats.thirst ~= nil then petData.item.metadata.thirst = stats.thirst end
    if stats.XP ~= nil then petData.item.metadata.XP = stats.XP end
    if stats.level ~= nil then petData.item.metadata.level = stats.level end
end)

-- ============================
--     XP / Level Sync
-- ============================

RegisterNetEvent('murderface-pets:client:syncXP', function(hash, xp, level)
    local petData = ActivePed:findByHash(hash)
    if not petData then return end
    petData.item.metadata.XP = xp
    petData.item.metadata.level = level
end)

-- ============================
--     Milestone Celebration
-- ============================

RegisterNetEvent('murderface-pets:client:milestone', function(hash, level, petName)
    local petData = ActivePed:findByHash(hash)

    -- Special notification
    local title = Config.getLevelTitle(level)
    Config.notify({
        title = 'Milestone Reached!',
        description = string.format('%s reached level %d — %s!', petName, level, title),
        type = 'success',
        duration = 10000,
    })

    -- Pet barks/vocalizes to celebrate
    if petData and DoesEntityExist(petData.entity) then
        SetAnimalMood(petData.entity, 1)
        PlayAnimalVocalization(petData.entity, 3, 'bark')
        if petData.animClass then
            Anims.play(petData.entity, petData.animClass, 'bark')
        end
    end
end)

-- ============================
--   Auto Vehicle Enter/Exit
-- ============================

CreateThread(function()
    local wasInVehicle = false
    while true do
        local plyPed = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(plyPed, false)

        if inVehicle and not wasInVehicle then
            -- Drop carried pet before boarding
            DropCarriedPet()
            -- Owner just got in a vehicle — board all pets that fit
            -- Skip invisible/scripted vehicles (e.g. skateboard's hidden BMX)
            local vehicle = GetVehiclePedIsUsing(plyPed)
            if vehicle and vehicle ~= 0 and IsEntityVisible(vehicle) then
                for _, petData in pairs(ActivePed.pets) do
                    local hash = petData.item and petData.item.metadata and petData.item.metadata.hash
                    if DoesEntityExist(petData.entity) and not IsEntityDead(petData.entity)
                        and not IsPedInAnyVehicle(petData.entity, false)
                        and not (hash and IsGuarding(hash))
                        and not (hash and IsInAggroCombat(hash)) then
                        if hash then DetachLeash(hash) end
                        putPetInVehicle(vehicle, petData.entity)
                    end
                end
            end
        elseif not inVehicle and wasInVehicle then
            -- Owner just exited — pull all pets out to the side and resume follow
            local exitSlot = 0
            for _, petData in pairs(ActivePed.pets) do
                if DoesEntityExist(petData.entity) and not IsEntityDead(petData.entity) and IsPedInAnyVehicle(petData.entity, false) then
                    -- Stagger exit positions so multiple pets don't stack
                    exitSlot = exitSlot + 1
                    local lateralOff = exitSlot == 1 and -2.5 or -2.5 -- both left, but stagger forward/back
                    local forwardOff = exitSlot == 1 and 0.0 or 2.0
                    local exitPos = GetOffsetFromEntityInWorldCoords(plyPed, lateralOff, forwardOff, 0.0)
                    -- Find actual ground Z to avoid floating/clipping
                    local found, groundZ = GetGroundZFor_3dCoord(exitPos.x, exitPos.y, exitPos.z + 2.0, false)
                    if found then
                        exitPos = vector3(exitPos.x, exitPos.y, groundZ)
                    end
                    SetEntityCoords(petData.entity, exitPos.x, exitPos.y, exitPos.z, false, false, false, false)
                    Wait(100)
                    TaskFollowTargetedPlayer(petData.entity, plyPed, 1.5, true)
                end
            end
        end

        wasInVehicle = inVehicle
        Wait(500)
    end
end)

-- ============================
--     Pet Name Overhead
-- ============================

if Config.nameTag.enabled then
    CreateThread(function()
        while true do
            local plyCoords = GetEntityCoords(PlayerPedId())
            local drawn = false

            for _, petData in pairs(ActivePed.pets) do
                if DoesEntityExist(petData.entity) and not IsEntityDead(petData.entity) then
                    local petCoords = GetEntityCoords(petData.entity)
                    local dist = #(plyCoords - petCoords)

                    if dist <= Config.nameTag.distance then
                        local name = petData.item.metadata.name or 'Pet'
                        local headZ = petCoords.z + 1.0
                        DrawText3D(vector3(petCoords.x, petCoords.y, headZ),
                            name, Config.nameTag.scale)

                        if Config.nameTag.showLevel then
                            local level = petData.item.metadata.level or 0
                            local title = Config.getLevelTitle(level)
                            DrawText3D(vector3(petCoords.x, petCoords.y, headZ - 0.15),
                                ('Lv.%d %s'):format(level, title),
                                Config.nameTag.scale * 0.8, 180, 220, 255, 180)
                        end
                        drawn = true
                    end
                end
            end

            Wait(drawn and 0 or 500)
        end
    end)
end

-- ============================
--     Pet Emotes (/petemote)
-- ============================

RegisterCommand('petemote', function(_, args)
    local emoteName = args[1]
    if not emoteName then
        local emoteList = {}
        for name in pairs(Config.petEmotes) do
            emoteList[#emoteList + 1] = name
        end
        lib.notify({
            description = 'Usage: /petemote ' .. table.concat(emoteList, '|'),
            type = 'info', duration = 7000,
        })
        return
    end

    local emote = Config.petEmotes[emoteName:lower()]
    if not emote then
        lib.notify({ description = 'Unknown emote: ' .. emoteName, type = 'error', duration = 5000 })
        return
    end

    local activePed = ActivePed:read()
    if not activePed then
        lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 5000 })
        return
    end

    local ped = activePed.entity
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    if emote.mood then
        SetAnimalMood(ped, emote.mood)
    end
    if emote.vocalization then
        PlayAnimalVocalization(ped, 3, emote.vocalization)
    end
    if emote.anim and activePed.animClass then
        Anims.play(ped, activePed.animClass, emote.anim)
    end
    -- Trick-based emotes (dance = beg trick, paw = paw trick)
    if emote.trick and activePed.animClass then
        Anims.playSub(ped, activePed.animClass, 'tricks', emote.trick)
    end
    -- Special emotes (fetch)
    if emote.special == 'fetch' then
        CreateThread(function()
            local fetchHash = activePed.item.metadata.hash
            SetBusy(fetchHash, true)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local forward = GetEntityForwardVector(playerPed)
            local throwTarget = playerPos + forward * 15.0

            -- Player throw animation
            lib.requestAnimDict('anim@arena@celeb@flat@paired@no_props@')
            TaskPlayAnim(playerPed, 'anim@arena@celeb@flat@paired@no_props@', 'throw_a_player_a', 8.0, -8.0, 1500, 0, 0, false, false, false)

            -- Spawn tennis ball prop
            lib.requestModel(`prop_tennis_ball`)
            local ball = CreateObject(`prop_tennis_ball`, playerPos.x, playerPos.y, playerPos.z + 1.5, true, true, false)
            Wait(400)
            if DoesEntityExist(ball) then
                ApplyForceToEntity(ball, 1, forward.x * 12.0, forward.y * 12.0, 6.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end

            -- Pet chases ball
            Wait(500)
            if DoesEntityExist(ball) and DoesEntityExist(ped) then
                local ballPos = GetEntityCoords(ball)
                TaskGoToCoordAnyMeans(ped, ballPos.x, ballPos.y, ballPos.z, 5.0, 0, 0, 0, 0)
            end

            -- Wait for pet to reach ball area
            local timeout = 0
            while DoesEntityExist(ball) and DoesEntityExist(ped) and timeout < 30 do
                local petPos = GetEntityCoords(ped)
                local ballPos = GetEntityCoords(ball)
                if #(petPos - ballPos) < 2.0 then break end
                Wait(500)
                timeout = timeout + 1
            end

            -- Pet picks up ball (play pickup anim), delete ball, return
            if DoesEntityExist(ball) then
                DeleteEntity(ball)
            end
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                if activePed.animClass then
                    Anims.play(ped, activePed.animClass, 'pickup')
                end
                Wait(2000)
                TaskFollowTargetedPlayer(ped, PlayerPedId(), 3.0, true)

                -- Award petting XP for playing fetch
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    activePed.item.metadata.hash, { key = 'activity', action = 'petting' })
            end
            SetBusy(fetchHash, false)
        end)
    end
end, false)
