-- murderface-pets: Main client logic
-- Hash-based ActivePed class, spawning, health tracking, AFK behavior, item events.

-- ============================
--         Pet Class
-- ============================

ActivePed = {
    pets = {},          -- { [hash] = petData }
    currentHash = nil,  -- hash of currently controlled pet
}

--- Register a new spawned pet
function ActivePed:add(model, hostile, item, ped, netId)
    local hash = item.metadata.hash
    local petCfg = Config.petsByItem[item.name]

    self.pets[hash] = {
        model      = model,
        modelString = petCfg and petCfg.model or model,
        entity     = ped,
        netId      = netId,
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

    local netId = NetworkGetNetworkIdFromEntity(petData.entity)
    if netId then
        TriggerServerEvent('murderface-pets:server:deleteEntity', netId)
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
--         Spawn Pet
-- ============================

RegisterNetEvent('murderface-pets:client:spawnPet', function(modelName, hostileTowardPlayer, item)
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
        local ped = CreateAPed(model, spawnCoord)
        local netId = NetworkGetNetworkIdFromEntity(ped)

        -- Register on server
        lib.callback.await('murderface-pets:server:registerPet', false, {
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
        ActivePed:add(modelName, hostileTowardPlayer, item, ped, netId)
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

        if petData.hostile then
            TriggerServerEvent('murderface-pets:server:despawnNotOwned', petData.item.metadata.hash)
            return
        end

        if currentHealth > 100 then
            createActivePetThread(ped, item)
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
--     AFK Wandering
-- ============================

local function afkWandering(timeOut, plyPed, ped, animClass)
    local coord = GetEntityCoords(plyPed)
    if IsPedStopped(plyPed) and not IsPedInAnyVehicle(plyPed, false) then
        if timeOut[1] < Config.balance.afk.resetAfter then
            timeOut[1] = timeOut[1] + 1
            if timeOut[1] == Config.balance.afk.wanderInterval then
                if not timeOut.lastAction or timeOut.lastAction == 'animation' then
                    ClearPedTasks(ped)
                    TaskWanderInArea(ped, coord, 4.0, 2, 8.0)
                    timeOut.lastAction = 'wandering'
                end
            end
            if timeOut[1] == Config.balance.afk.animInterval then
                ClearPedTasks(ped)
                Anims.play(ped, animClass, 'sit')
                timeOut.lastAction = 'animation'
            end
        else
            timeOut[1] = 0
        end
    else
        timeOut[1] = 0
    end
end

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
        local timeOut = { 0, lastAction = nil }

        while DoesEntityExist(ped) and not finished do
            local plyPed = PlayerPedId() -- refresh each tick; handle changes on death/respawn
            afkWandering(timeOut, plyPed, ped, savedData.animClass)

            -- Update server every N seconds
            if tmpcount >= count then
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    savedData.item.metadata.hash, { key = 'XP' })
                tmpcount = 0
            end
            tmpcount = tmpcount + 1

            -- Update health
            local currentHealth = GetEntityHealth(savedData.entity)
            if not IsPedDeadOrDying(savedData.entity) and
               savedData.maxHealth ~= currentHealth and
               savedData.health ~= currentHealth then
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    savedData.item.metadata.hash, {
                        key = 'health',
                        netId = NetworkGetNetworkIdFromEntity(ped),
                    })
                savedData.health = currentHealth
            end

            -- Pet has died — keep dead until revived/despawned
            if IsPedDeadOrDying(savedData.entity, true) then
                StopGuard(savedData.item.metadata.hash)
                local c_health = GetEntityHealth(savedData.entity)
                if c_health <= 100 then
                    TriggerServerEvent('murderface-pets:server:updatePetStats',
                        savedData.item.metadata.hash, {
                            key = 'health',
                            netId = NetworkGetNetworkIdFromEntity(ped),
                        })
                    -- Prevent GTA auto-revive loop
                    while DoesEntityExist(ped) do
                        if not IsPedDeadOrDying(ped, true) then
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
    StopGuard(hash)
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
    StopAllGuards()
    ActivePed:removeAll()
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
    lib.notify({
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
            -- Owner just got in a vehicle — board all pets that fit
            local vehicle = GetVehiclePedIsUsing(plyPed)
            if vehicle and vehicle ~= 0 then
                for _, petData in pairs(ActivePed.pets) do
                    local hash = petData.item and petData.item.metadata and petData.item.metadata.hash
                    if DoesEntityExist(petData.entity) and not IsPedInAnyVehicle(petData.entity, false)
                        and not (hash and IsGuarding(hash)) then
                        putPetInVehicle(vehicle, petData.entity)
                    end
                end
            end
        elseif not inVehicle and wasInVehicle then
            -- Owner just exited — pull all pets out and resume follow
            for _, petData in pairs(ActivePed.pets) do
                if DoesEntityExist(petData.entity) and IsPedInAnyVehicle(petData.entity, false) then
                    local coord = getSpawnLocation(plyPed)
                    SetEntityCoords(petData.entity, coord.x, coord.y, coord.z, false, false, false, false)
                    Wait(100)
                    ClearPedTasks(petData.entity)
                    TaskFollowTargetedPlayer(petData.entity, plyPed, 3.0, true)
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
end, false)
