-- murderface-pets: Guard mode system
-- Pet guards a fixed position and attacks intruders entering the radius.
-- Follows the enforcement-thread pattern from leash.lua.

local guardState = {}       -- { [petHash] = { pos = vector3, active = bool } }
local notifiedPeds = {}     -- { [petHash] = { [pedHandle] = true } } — prevent notification spam

-- ============================
--       Public Queries
-- ============================

--- Check if a pet is currently guarding
---@param hash string Pet hash
---@return boolean
function IsGuarding(hash)
    return guardState[hash] ~= nil and guardState[hash].active == true
end

--- Get the guard position for a pet
---@param hash string Pet hash
---@return vector3|nil
function GetGuardPosition(hash)
    local state = guardState[hash]
    return state and state.pos or nil
end

-- ============================
--     Enforcement Thread
-- ============================

--- Determine the effective guard radius (applies Guardian specialization multiplier)
---@param activePed table ActivePed data
---@return number radius
local function getEffectiveRadius(activePed)
    local radius = Config.guard.radius
    local spec = activePed.item and activePed.item.metadata and activePed.item.metadata.specialization
    if spec == 'guardian' and Config.specializations and Config.specializations.guardian then
        local mult = Config.specializations.guardian.guardRadiusMult
        if mult then
            radius = radius * mult
        end
    end
    return radius
end

--- Main guard enforcement thread
---@param petEntity number Pet ped handle
---@param hash string Pet hash
---@param guardPos vector3 Position to guard
---@param activePed table ActivePed data
local function startGuardThread(petEntity, hash, guardPos, activePed)
    CreateThread(function()
        local cfg = Config.guard
        local radius = getEffectiveRadius(activePed)
        local playerPed = PlayerPedId()

        -- Set combat attributes
        SetPedCombatAbility(petEntity, cfg.combatAbility)
        SetPedCombatRange(petEntity, cfg.combatRange)
        SetPedCombatMovement(petEntity, cfg.combatMovement)
        SetPedCombatAttributes(petEntity, 46, true) -- BF_CanFightArmedPedsWhenNotArmed

        -- Initial guard task
        TaskGuardCurrentPosition(petEntity, radius, radius, true)

        notifiedPeds[hash] = {}
        local currentInterval = cfg.checkInterval  -- O5: adaptive scan interval
        local maxInterval = cfg.checkInterval * 4   -- cap at 4x base interval

        while guardState[hash] and guardState[hash].active
              and DoesEntityExist(petEntity)
              and not IsEntityDead(petEntity) do

            local pedPool = GetGamePool('CPed')
            playerPed = PlayerPedId()
            local foundIntruder = false

            for _, ped in ipairs(pedPool) do
                -- Skip self and owner
                if ped ~= petEntity and ped ~= playerPed
                   and not IsEntityDead(ped)
                   and not IsPedInAnyVehicle(ped, false) then

                    -- Skip players if attackPlayers is disabled
                    if not cfg.attackPlayers and IsPedAPlayer(ped) then
                        goto continue
                    end

                    local pedPos = GetEntityCoords(ped)
                    local dist = #(guardPos - pedPos)

                    if dist <= radius then
                        foundIntruder = true
                        currentInterval = cfg.checkInterval -- reset to base on combat

                        -- Attack intruder
                        TaskCombatPed(petEntity, ped, 0, 16)

                        -- Notify owner (once per ped)
                        if cfg.notifyOwner and not notifiedPeds[hash][ped] then
                            notifiedPeds[hash][ped] = true
                            lib.notify({
                                title = activePed.item.metadata.name or 'Pet',
                                description = Lang:t('menu.action_menu.guard_intruder'),
                                type = 'warning',
                                duration = 5000,
                            })
                        end

                        -- Award guarding XP (server-side, with cooldown)
                        TriggerServerEvent('murderface-pets:server:updatePetStats',
                            hash, { key = 'activity', action = 'guarding' })

                        -- Wait for this combat encounter to resolve before scanning again
                        while guardState[hash] and guardState[hash].active
                              and DoesEntityExist(petEntity) and not IsEntityDead(petEntity)
                              and DoesEntityExist(ped) and not IsEntityDead(ped)
                              and #(GetEntityCoords(petEntity) - GetEntityCoords(ped)) < radius + 5.0 do
                            Wait(1000)
                        end

                        -- Clear notification tracking for this ped
                        if notifiedPeds[hash] then
                            notifiedPeds[hash][ped] = nil
                        end

                        -- Return to guard position if still active
                        if guardState[hash] and guardState[hash].active
                           and DoesEntityExist(petEntity) and not IsEntityDead(petEntity) then
                            TaskGuardCurrentPosition(petEntity, radius, radius, true)
                        end
                        break
                    end

                    ::continue::
                end
            end

            -- O5: No intruders found — ramp up interval to reduce idle CPU cost
            if not foundIntruder then
                currentInterval = math.min(currentInterval * 2, maxInterval)
            end

            Wait(currentInterval)
        end

        -- Cleanup
        guardState[hash] = nil
        notifiedPeds[hash] = nil
    end)
end

-- ============================
--       Public Functions
-- ============================

--- Activate guard mode for a pet
---@param activePed table ActivePed data
function StartGuard(activePed)
    local hash = activePed.item.metadata.hash
    local petEntity = activePed.entity

    -- Eject from vehicle if needed
    doSomethingIfPedIsInsideVehicle(petEntity)

    local guardPos = GetEntityCoords(petEntity)
    guardState[hash] = { pos = guardPos, active = true }

    startGuardThread(petEntity, hash, guardPos, activePed)
end

--- Deactivate guard mode and return to following
---@param hash string Pet hash
function StopGuard(hash)
    if not guardState[hash] then return end

    guardState[hash].active = false
    guardState[hash] = nil
    notifiedPeds[hash] = nil

    local activePed = ActivePed:findByHash(hash)
    if activePed and DoesEntityExist(activePed.entity) and not IsEntityDead(activePed.entity) then
        ClearPedTasks(activePed.entity)
        TaskFollowTargetedPlayer(activePed.entity, PlayerPedId(), 3.0, false)
    end
end

--- Stop all guards (logout/disconnect)
function StopAllGuards()
    for hash in pairs(guardState) do
        StopGuard(hash)
    end
end
