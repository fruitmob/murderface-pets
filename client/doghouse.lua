-- murderface-pets: Dog house placement, breeding menu, proximity spawning, rest bonus
-- Players buy a dog house item, place it as a prop, then breed matching pets at it.
-- Pets near the dog house get a rest bonus (reduced food/thirst drain, bonus HP regen).

local doghouseData = nil       -- { x, y, z, heading } from server
local doghouseEntity = nil     -- spawned prop entity handle
local placementActive = false
local breedingStatusCache = nil
local statusRefreshTimer = 0

-- ============================
--     Placement System
-- ============================

RegisterNetEvent('murderface-pets:client:startDoghousePlacement', function()
    if placementActive then return end
    placementActive = true

    local model = joaat(Config.breeding.propModel)
    lib.requestModel(model)

    local plyPed = PlayerPedId()
    local startPos = GetOffsetFromEntityInWorldCoords(plyPed, 0.0, 3.0, 0.0)
    local ghost = CreateObjectNoOffset(model, startPos.x, startPos.y, startPos.z, false, true, false)

    while not DoesEntityExist(ghost) do Wait(10) end

    PlaceObjectOnGroundProperly(ghost)
    FreezeEntityPosition(ghost, true)
    SetEntityAlpha(ghost, 200, true)
    SetEntityCollision(ghost, false, false)
    SetModelAsNoLongerNeeded(model)

    lib.showTextUI('[E] Place  |  [NUM4/NUM6] Rotate  |  [Backspace] Cancel', {
        position = 'top-center',
    })

    CreateThread(function()
        while placementActive and DoesEntityExist(ghost) do
            Wait(0)

            -- Rotation: NUM4 / NUM6
            if IsDisabledControlPressed(0, 108) then
                SetEntityHeading(ghost, GetEntityHeading(ghost) + 1.0)
            end
            if IsDisabledControlPressed(0, 109) then
                SetEntityHeading(ghost, GetEntityHeading(ghost) - 1.0)
            end

            -- Move ghost to camera raycast hit
            local hitCoords = RayCastGamePlayCamera(Config.breeding.placementMaxDistance)
            if hitCoords then
                SetEntityCoords(ghost, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false, false)
                PlaceObjectOnGroundProperly(ghost)
            end

            -- Confirm: E
            if IsControlJustPressed(0, 38) then
                local coords = GetEntityCoords(ghost)
                local heading = GetEntityHeading(ghost)
                DeleteEntity(ghost)
                lib.hideTextUI()
                placementActive = false

                if lib.progressBar({
                    duration = Config.items.doghouse.duration * 1000,
                    label = Lang:t('breeding.placing_doghouse'),
                    disable = { move = true, car = true, combat = true, mouse = false },
                }) then
                    local success, msg = lib.callback.await(
                        'murderface-pets:server:placeDoghouse', false, coords, heading)
                    if success then
                        lib.notify({
                            description = Lang:t('breeding.doghouse_placed'),
                            type = 'success', duration = 7000,
                        })
                        doghouseData = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                        spawnDoghouseProp()
                    else
                        lib.notify({
                            description = msg or Lang:t('breeding.placement_failed'),
                            type = 'error', duration = 7000,
                        })
                    end
                else
                    placementActive = false
                end
                return
            end

            -- Cancel: Backspace
            if IsControlJustPressed(0, 177) then
                DeleteEntity(ghost)
                lib.hideTextUI()
                placementActive = false
                lib.notify({
                    description = Lang:t('breeding.placement_cancelled'),
                    type = 'info', duration = 3000,
                })
                return
            end
        end
    end)
end)

-- ============================
--    Proximity Spawn/Despawn
-- ============================

--- Spawn the dog house prop at the stored location
function spawnDoghouseProp()
    if doghouseEntity and DoesEntityExist(doghouseEntity) then return end
    if not doghouseData then return end

    local model = joaat(Config.breeding.propModel)
    lib.requestModel(model)
    doghouseEntity = CreateObjectNoOffset(model,
        doghouseData.x, doghouseData.y, doghouseData.z,
        false, true, false)

    while not DoesEntityExist(doghouseEntity) do Wait(10) end

    PlaceObjectOnGroundProperly(doghouseEntity)
    SetEntityHeading(doghouseEntity, doghouseData.heading)
    FreezeEntityPosition(doghouseEntity, true)
    SetEntityCollision(doghouseEntity, true, true)
    SetModelAsNoLongerNeeded(model)

    -- ox_target interactions
    exports.ox_target:addLocalEntity(doghouseEntity, {
        {
            name = 'mfpets_doghouse_breed',
            icon = 'fas fa-heart',
            label = Lang:t('breeding.breed_pets'),
            onSelect = function()
                openBreedingMenu()
            end,
            distance = 2.5,
        },
        {
            name = 'mfpets_doghouse_claim',
            icon = 'fas fa-gift',
            label = Lang:t('breeding.claim_puppy'),
            canInteract = function()
                return breedingStatusCache and breedingStatusCache.status == 'ready'
            end,
            onSelect = function()
                claimOffspring()
            end,
            distance = 2.5,
        },
        {
            name = 'mfpets_doghouse_status',
            icon = 'fas fa-clock',
            label = Lang:t('breeding.check_status'),
            canInteract = function()
                return breedingStatusCache and breedingStatusCache.status == 'pending'
            end,
            onSelect = function()
                lib.notify({
                    title = 'Breeding Status',
                    description = string.format(
                        Lang:t('breeding.status_pending'),
                        breedingStatusCache.petLabel
                    ),
                    type = 'info', duration = 7000,
                })
            end,
            distance = 2.5,
        },
        {
            name = 'mfpets_doghouse_pickup',
            icon = 'fas fa-arrow-up',
            label = Lang:t('breeding.pickup_doghouse'),
            canInteract = function()
                return not breedingStatusCache
                    or (breedingStatusCache.status ~= 'pending' and breedingStatusCache.status ~= 'ready')
            end,
            onSelect = function()
                pickupDoghouse()
            end,
            distance = 2.5,
        },
    })
end

--- Despawn the dog house prop
function despawnDoghouseProp()
    if doghouseEntity and DoesEntityExist(doghouseEntity) then
        exports.ox_target:removeLocalEntity(doghouseEntity)
        DeleteEntity(doghouseEntity)
    end
    doghouseEntity = nil
end

-- ============================
--    Breeding Menu
-- ============================

function openBreedingMenu()
    local pairs = lib.callback.await('murderface-pets:server:getBreedingPairs', false)
    if not pairs or #pairs == 0 then
        lib.notify({
            description = Lang:t('breeding.no_eligible_pairs'),
            type = 'error', duration = 7000,
        })
        return
    end

    local options = {}
    for _, pair in ipairs(pairs) do
        local petCfg = Config.petsByModel[pair.model]
        options[#options + 1] = {
            title = string.format('%s + %s', pair.male.name, pair.female.name),
            description = string.format('%s  |  Lv.%d & Lv.%d',
                petCfg and petCfg.label or pair.model,
                pair.male.level, pair.female.level),
            icon = petCfg and petCfg.icon or 'paw',
            iconColor = '#e64980',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = Lang:t('breeding.confirm_header'),
                    content = string.format(
                        Lang:t('breeding.confirm_body'),
                        pair.male.name, pair.female.name,
                        petCfg and petCfg.label or pair.model
                    ),
                    centered = true,
                    cancel = true,
                })
                if confirm ~= 'confirm' then return end

                if lib.progressBar({
                    duration = 5000,
                    label = Lang:t('breeding.breeding_in_progress'),
                    disable = { move = true, car = true, combat = true, mouse = false },
                }) then
                    local success, msg = lib.callback.await(
                        'murderface-pets:server:startBreeding', false,
                        pair.male.hash, pair.female.hash)
                    if success then
                        lib.notify({
                            title = Lang:t('breeding.success_title'),
                            description = Lang:t('breeding.success_body'),
                            type = 'success', duration = 10000,
                        })
                        refreshBreedingStatus()
                    else
                        lib.notify({
                            description = msg or Lang:t('breeding.failed'),
                            type = 'error', duration = 7000,
                        })
                    end
                end
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_breeding',
        title = Lang:t('breeding.menu_title'),
        options = options,
    })
    lib.showContext('mfpets_breeding')
end

-- ============================
--    Claim Offspring
-- ============================

function claimOffspring()
    local confirm = lib.alertDialog({
        header = Lang:t('breeding.claim_header'),
        content = string.format(
            Lang:t('breeding.claim_body'),
            breedingStatusCache and breedingStatusCache.petName or 'your new pet'
        ),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end

    local success, petName = lib.callback.await('murderface-pets:server:claimOffspring', false)
    if success then
        lib.notify({
            title = Lang:t('breeding.puppy_claimed_title'),
            description = string.format(Lang:t('breeding.puppy_claimed_body'), petName),
            type = 'success', duration = 10000,
        })
        breedingStatusCache = nil
    else
        lib.notify({
            description = petName or Lang:t('breeding.claim_failed'),
            type = 'error', duration = 7000,
        })
    end
end

-- ============================
--    Pick Up Dog House
-- ============================

function pickupDoghouse()
    if breedingStatusCache and (breedingStatusCache.status == 'pending' or breedingStatusCache.status == 'ready') then
        lib.notify({
            description = Lang:t('breeding.cannot_pickup_breeding_active'),
            type = 'error', duration = 7000,
        })
        return
    end

    if lib.progressBar({
        duration = 3000,
        label = Lang:t('breeding.picking_up'),
        disable = { move = true, car = true, combat = true, mouse = false },
    }) then
        local success = lib.callback.await('murderface-pets:server:removeDoghouse', false)
        if success then
            despawnDoghouseProp()
            doghouseData = nil
            lib.notify({
                description = Lang:t('breeding.doghouse_picked_up'),
                type = 'success', duration = 5000,
            })
        end
    end
end

-- ============================
--    Breeding Status Cache
-- ============================

function refreshBreedingStatus()
    breedingStatusCache = lib.callback.await('murderface-pets:server:getBreedingStatus', false)
end

-- ============================
--   Rest Bonus Proximity
-- ============================

--- Check if any active pet is near the dog house and notify server of state changes
local function updateRestBonusState()
    if not doghouseData then return end
    local dhPos = vector3(doghouseData.x, doghouseData.y, doghouseData.z)
    local radius = Config.breeding.restBonusRadius

    for hash, petData in pairs(ActivePed.pets) do
        if DoesEntityExist(petData.entity) and not IsEntityDead(petData.entity) then
            local petPos = GetEntityCoords(petData.entity)
            local isNear = #(petPos - dhPos) <= radius
            if petData._wasNearDoghouse ~= isNear then
                petData._wasNearDoghouse = isNear
                TriggerServerEvent('murderface-pets:server:setNearDoghouse', hash, isNear)
            end
        end
    end
end

-- ============================
--    Main Proximity Thread
-- ============================

CreateThread(function()
    if not Config.breeding or not Config.breeding.enabled then return end

    Wait(10000)

    -- Fetch dog house location from server
    doghouseData = lib.callback.await('murderface-pets:server:getDoghouse', false)

    -- Fetch breeding status
    refreshBreedingStatus()

    while true do
        local playerPos = GetEntityCoords(PlayerPedId())

        if doghouseData then
            local dhPos = vector3(doghouseData.x, doghouseData.y, doghouseData.z)
            local dist = #(playerPos - dhPos)

            if dist < 100.0 and not doghouseEntity then
                spawnDoghouseProp()
            elseif dist > 150.0 and doghouseEntity then
                despawnDoghouseProp()
            end

            -- Rest bonus proximity check when near
            if dist < 100.0 then
                updateRestBonusState()
            end
        end

        -- Refresh breeding status every ~60 seconds
        statusRefreshTimer = statusRefreshTimer + 1
        if statusRefreshTimer >= 6 then
            statusRefreshTimer = 0
            refreshBreedingStatus()
        end

        Wait(10000)
    end
end)

-- ============================
--    Cleanup on Logout
-- ============================

RegisterNetEvent('qbx_core:client:onLogout', function()
    despawnDoghouseProp()
    doghouseData = nil
    breedingStatusCache = nil
    statusRefreshTimer = 0
end)
