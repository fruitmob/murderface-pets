-- murderface-pets: Guard mode system
-- Pet guards a fixed position and attacks intruders entering the radius.

local guardState = {}       -- { [petHash] = { pos = vector3, active = bool } }
local notifiedPeds = {}     -- { [petHash] = { [pedHandle] = true } } — prevent notification spam

-- Reuse relationship groups created in functions.lua (AddRelationshipGroup is idempotent)
local _, hunterGroupHash = AddRelationshipGroup('MFPETS_HUNTER')
local _, petGroupHash = AddRelationshipGroup('MFPETS_COMPANION')

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

                        -- Set up hostile relationship (same pattern as AttackTargetedPed)
                        SetBlockingOfNonTemporaryEvents(petEntity, false)
                        local targetGroup = GetPedRelationshipGroupHash(ped)
                        SetPedRelationshipGroupHash(petEntity, hunterGroupHash)
                        SetRelationshipBetweenGroups(5, hunterGroupHash, targetGroup) -- 5 = Hate
                        SetCanAttackFriendly(petEntity, true, false)

                        -- Attack intruder
                        TaskCombatPed(petEntity, ped, 0, 16)

                        -- Notify owner (once per ped per guard session)
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

                        -- Wait for combat to resolve, re-engaging if pet drops combat
                        while guardState[hash] and guardState[hash].active
                              and DoesEntityExist(petEntity) and not IsEntityDead(petEntity)
                              and DoesEntityExist(ped) and not IsEntityDead(ped)
                              and #(GetEntityCoords(petEntity) - GetEntityCoords(ped)) < radius + 5.0 do
                            if not IsPedInCombat(petEntity) then
                                TaskCombatPed(petEntity, ped, 0, 16)
                            end
                            Wait(1000)
                        end

                        -- Only clear notification tracking if ped is dead/gone
                        if notifiedPeds[hash] and (not DoesEntityExist(ped) or IsEntityDead(ped)) then
                            notifiedPeds[hash][ped] = nil
                        end

                        -- Restore passive companion state
                        if DoesEntityExist(petEntity) and not IsEntityDead(petEntity) then
                            SetBlockingOfNonTemporaryEvents(petEntity, true)
                            SetCanAttackFriendly(petEntity, false, false)
                            SetPedRelationshipGroupHash(petEntity, petGroupHash)
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
        -- Restore passive companion state (may have been in hunter group mid-combat)
        SetBlockingOfNonTemporaryEvents(activePed.entity, true)
        SetCanAttackFriendly(activePed.entity, false, false)
        SetPedRelationshipGroupHash(activePed.entity, petGroupHash)
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

-- ============================
--   Aggro / Defense Mode
-- ============================

local aggroState = {}
local aggroThreadRunning = false

function IsAggroEnabled(hash)
    return aggroState[hash] ~= nil and aggroState[hash].active == true
end

function IsInAggroCombat(hash)
    return aggroState[hash] ~= nil and aggroState[hash].inCombat == true
end

local function activeAggroCount()
    local count = 0
    for _, state in pairs(aggroState) do
        if state.active then count = count + 1 end
    end
    return count
end

local AGGRO_COMBAT_TIMEOUT = 30000 -- 30s max before resetting stuck inCombat

local function startAggroThread()
    if aggroThreadRunning then return end
    aggroThreadRunning = true

    CreateThread(function()
        local cfg = Config.aggro

        while activeAggroCount() > 0 do
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)

            if not IsPedDeadOrDying(playerPed, false) and not IsPedInAnyVehicle(playerPed, false) then
                local pedPool = GetGamePool('CPed')

                for hash, state in pairs(aggroState) do
                    if not state.active then goto nextAggro end

                    local petData = ActivePed:findByHash(hash)
                    if not petData
                       or not DoesEntityExist(petData.entity)
                       or IsEntityDead(petData.entity)
                       or IsPedInAnyVehicle(petData.entity, false)
                       or IsGuarding(hash) then
                        goto nextAggro
                    end

                    -- Stuck combat recovery: if inCombat for too long or target gone, reset
                    if state.inCombat then
                        local target = state.combatTarget
                        local elapsed = GetGameTimer() - (state.combatStart or 0)
                        if elapsed > AGGRO_COMBAT_TIMEOUT
                           or not target
                           or not DoesEntityExist(target)
                           or IsEntityDead(target) then
                            state.inCombat = false
                            state.combatTarget = nil
                            state.combatStart = nil
                        else
                            goto nextAggro -- still in valid combat, skip scan
                        end
                    end

                    do -- scan for threats
                        local bestTarget = nil
                        local bestDist = math.huge

                        for _, ped in ipairs(pedPool) do
                            if ped ~= petData.entity
                               and ped ~= playerPed
                               and not IsEntityDead(ped)
                               and not IsPedInAnyVehicle(ped, false) then

                                if not cfg.attackPlayers and IsPedAPlayer(ped) then
                                    goto aggroContinue
                                end

                                local dist = #(playerPos - GetEntityCoords(ped))
                                if dist <= cfg.detectionRange then
                                    local isDefensive = HasEntityBeenDamagedByEntity(playerPed, ped, true)
                                    local isOffensive = HasEntityBeenDamagedByEntity(ped, playerPed, true)

                                    if (isDefensive or isOffensive) and dist < bestDist then
                                        bestDist = dist
                                        bestTarget = ped
                                    end
                                end

                                ::aggroContinue::
                            end
                        end

                        if bestTarget then
                            state.inCombat = true
                            state.combatTarget = bestTarget
                            state.combatStart = GetGameTimer()

                            if cfg.notifyOwner then
                                local petName = petData.item.metadata.name or 'Pet'
                                lib.notify({
                                    title = petName,
                                    description = Lang:t('menu.action_menu.aggro_engaging'),
                                    type = 'warning',
                                    duration = 5000,
                                })
                            end

                            TriggerServerEvent('murderface-pets:server:updatePetStats',
                                hash, { key = 'activity', action = 'defending' })

                            local capturedHash = hash
                            local capturedTarget = bestTarget
                            CreateThread(function()
                                AttackTargetedPed(petData.entity, capturedTarget)
                                if aggroState[capturedHash] then
                                    aggroState[capturedHash].inCombat = false
                                    aggroState[capturedHash].combatTarget = nil
                                    aggroState[capturedHash].combatStart = nil
                                end
                            end)
                        end
                    end

                    ::nextAggro::
                end

                ClearEntityLastDamageEntity(playerPed)
            end

            Wait(cfg.checkInterval)
        end

        aggroThreadRunning = false
    end)
end

function StartAggro(hash)
    aggroState[hash] = { active = true, inCombat = false }
    -- Recovery: if aggroThreadRunning is stuck from a previous error, reset it
    if aggroThreadRunning and activeAggroCount() <= 1 then
        aggroThreadRunning = false
    end
    startAggroThread()
end

function StopAggro(hash)
    if not aggroState[hash] then return end
    aggroState[hash].active = false
    aggroState[hash] = nil
end

function StopAllAggro()
    for hash in pairs(aggroState) do
        StopAggro(hash)
    end
end
