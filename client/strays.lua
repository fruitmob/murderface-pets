-- murderface-pets: Stray/wild animal taming system
-- Config-driven spawn points, proximity-based spawning, trust-building via feeding.

local spawnedStrays = {} -- { [strayId] = { entity = ped } }

-- ============================
--     Spawn / Despawn
-- ============================

--- Spawn a stray animal at a config-defined point
---@param strayCfg table Stray spawn point config entry
local function spawnStray(strayCfg)
    if spawnedStrays[strayCfg.id] then return end

    local model = type(strayCfg.model) == 'string' and GetHashKey(strayCfg.model) or strayCfg.model
    lib.requestModel(model)
    local ped = CreatePed(5, model,
        strayCfg.coords.x, strayCfg.coords.y, strayCfg.coords.z - 1.0,
        strayCfg.coords.w, false, true)

    while not DoesEntityExist(ped) do Wait(10) end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, false)
    SetPedFleeAttributes(ped, 0, 0)
    TaskWanderInArea(ped,
        strayCfg.coords.x, strayCfg.coords.y, strayCfg.coords.z,
        5.0, 2, 8.0)

    -- Apply rare coat if defined (visual hint that this stray is special)
    if strayCfg.rareCoat then
        Variations.apply(ped, strayCfg.model, strayCfg.rareCoat)
    end

    -- ox_target feed interaction
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mfpets_feed_stray_' .. strayCfg.id,
            icon = 'fas fa-bone',
            label = 'Feed ' .. strayCfg.label,
            canInteract = function()
                local count = exports.ox_inventory:Search('count', Config.strays.feedItem)
                return count and count > 0
            end,
            onSelect = function()
                if lib.progressBar({
                    duration = 3000,
                    label = Lang:t('stray.feeding'),
                    disable = { move = true, car = true, combat = true, mouse = false },
                }) then
                    local success, msg = lib.callback.await(
                        'murderface-pets:server:feedStray', false, strayCfg.id)
                    if success then
                        if msg == 'tamed' then
                            lib.notify({
                                title = 'New Companion!',
                                description = string.format(Lang:t('stray.tamed'), strayCfg.label),
                                type = 'success',
                                duration = 10000,
                            })
                            despawnStray(strayCfg.id)
                        else
                            lib.notify({ description = msg, type = 'success', duration = 5000 })
                        end
                    else
                        lib.notify({ description = msg or Lang:t('stray.cooldown'), type = 'error', duration = 5000 })
                    end
                end
            end,
            distance = Config.strays.feedRadius,
        },
    })

    spawnedStrays[strayCfg.id] = { entity = ped }
    SetModelAsNoLongerNeeded(model)
end

--- Remove a spawned stray entity
---@param strayId string Stray config ID
function despawnStray(strayId)
    local stray = spawnedStrays[strayId]
    if not stray then return end

    if DoesEntityExist(stray.entity) then
        exports.ox_target:removeLocalEntity(stray.entity)
        DeleteEntity(stray.entity)
    end

    spawnedStrays[strayId] = nil
end

-- ============================
--     Proximity Manager
-- ============================

CreateThread(function()
    if not Config.strays or not Config.strays.enabled then return end
    if not Config.strays.spawnPoints or #Config.strays.spawnPoints == 0 then return end

    -- Wait for game to fully load
    Wait(10000)

    while true do
        local playerPos = GetEntityCoords(PlayerPedId())

        for _, strayCfg in ipairs(Config.strays.spawnPoints) do
            local spawnPos = vector3(strayCfg.coords.x, strayCfg.coords.y, strayCfg.coords.z)
            local dist = #(playerPos - spawnPos)

            if dist < 100.0 and not spawnedStrays[strayCfg.id] then
                -- Ask server if this stray should spawn (respawn timer + chance roll)
                local shouldSpawn = lib.callback.await(
                    'murderface-pets:server:checkStrayStatus', false, strayCfg.id)
                if shouldSpawn then
                    spawnStray(strayCfg)
                end
            elseif dist > 150.0 and spawnedStrays[strayCfg.id] then
                -- Despawn when player moves away
                despawnStray(strayCfg.id)
            end
        end

        Wait(10000)
    end
end)

-- ============================
--     Cleanup on Logout
-- ============================

RegisterNetEvent('qbx_core:client:onLogout', function()
    for id in pairs(spawnedStrays) do
        despawnStray(id)
    end
end)
