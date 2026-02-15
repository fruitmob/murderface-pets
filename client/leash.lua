-- murderface-pets: Leash system
-- Rope-based visual leash between player hand and pet neck.
-- Rope is cosmetic only — distance enforcement is script-side.

local leashRopes = {}       -- { [petHash] = ropeHandle }
local otherLeashes = {}     -- { [petNetId] = ropeHandle } (ropes created for other players)
local leashEnforcing = {}   -- { [petHash] = true } (active enforcement threads)

-- ============================
--     Leash State Query
-- ============================

--- Check if a pet (by hash) is currently leashed
---@param hash string Pet hash
---@return boolean
function IsLeashed(hash)
    return leashRopes[hash] ~= nil
end

-- ============================
--     Rope Creation
-- ============================

--- Create a leash rope between player and pet
---@param playerPed number Player ped handle
---@param petEntity number Pet ped handle
---@param hash string Pet hash (for tracking)
local function createRope(playerPed, petEntity, hash)
    if leashRopes[hash] then return end

    local cfg = Config.leash

    RopeLoadTextures()
    local timeout = 0
    while not RopeAreTexturesLoaded() do
        Wait(0)
        timeout = timeout + 1
        if timeout > 500 then return end
    end

    local playerPos = GetEntityCoords(playerPed)

    local rope = AddRope(
        playerPos.x, playerPos.y, playerPos.z,
        0.0, 0.0, 0.0,
        cfg.length,          -- maxLength
        cfg.ropeType,        -- 5 = RopeReins
        cfg.length,          -- initLength
        0.5,                 -- minLength
        1.0,                 -- lengthChangeRate
        false,               -- onlyPPU
        false,               -- collision
        false,               -- lockFromFront
        1.0,                 -- timeMultiplier
        false                -- breakable
    )

    local playerBone = GetPedBoneIndex(playerPed, cfg.playerBone)
    local petBone = GetPedBoneIndex(petEntity, cfg.petBone)

    ---@diagnostic disable-next-line: param-type-mismatch
    AttachEntitiesToRope(
        rope,
        playerPed, petEntity,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        cfg.length,
        false, false,
        playerBone, petBone
    )

    ActivatePhysics(rope)
    leashRopes[hash] = rope
end

--- Destroy a leash rope by pet hash
---@param hash string Pet hash
local function destroyRope(hash)
    local rope = leashRopes[hash]
    if rope then
        if DoesRopeExist(rope) then
            DeleteRope(rope)
        end
        leashRopes[hash] = nil
    end
    leashEnforcing[hash] = nil

    -- Unload textures only if no ropes remain
    local hasAny = false
    for _ in pairs(leashRopes) do hasAny = true; break end
    for _ in pairs(otherLeashes) do hasAny = true; break end
    if not hasAny then
        RopeUnloadTextures()
    end
end

-- ============================
--     Distance Enforcement
-- ============================

--- Start a thread that keeps the pet within leash range
---@param petEntity number Pet ped handle
---@param hash string Pet hash
local function startEnforcement(petEntity, hash)
    if leashEnforcing[hash] then return end
    leashEnforcing[hash] = true

    CreateThread(function()
        local cfg = Config.leash
        local maxDist = cfg.length + 0.5

        while leashEnforcing[hash] and DoesEntityExist(petEntity) and not IsEntityDead(petEntity) do
            local playerPos = GetEntityCoords(PlayerPedId())
            local petPos = GetEntityCoords(petEntity)
            local dist = #(playerPos - petPos)

            if dist > maxDist then
                TaskGoToEntity(petEntity, PlayerPedId(), -1, 1.0, 3.0, 0, 0)
            end

            Wait(500)
        end
        leashEnforcing[hash] = nil
    end)
end

-- ============================
--     Toggle (Public API)
-- ============================

--- Toggle leash on/off for the currently controlled pet
---@param activePed table ActivePed data
function ToggleLeash(activePed)
    if not Config.leash.enabled then return end

    local hash = activePed.item.metadata.hash
    local petEntity = activePed.entity

    if IsLeashed(hash) then
        -- Remove leash
        destroyRope(hash)

        -- Restore normal follow distance
        TaskFollowTargetedPlayer(petEntity, PlayerPedId(), 3.0, false)

        lib.notify({ description = 'Leash removed', type = 'info', duration = 3000 })

        -- Sync to other clients
        local netId = NetworkGetNetworkIdFromEntity(petEntity)
        TriggerServerEvent('murderface-pets:server:syncLeash', netId, false)
    else
        -- Attach leash
        local playerPed = PlayerPedId()
        createRope(playerPed, petEntity, hash)

        -- Tighter follow distance
        ClearPedTasks(petEntity)
        TaskFollowToOffsetOfEntity(petEntity, playerPed, 0.5, 0.5, 0.0, 3.0, 10.0, 1.5, true)

        -- Start distance enforcement
        if Config.leash.enforceDistance then
            startEnforcement(petEntity, hash)
        end

        lib.notify({ description = 'Leash attached', type = 'success', duration = 3000 })

        -- Sync to other clients
        local netId = NetworkGetNetworkIdFromEntity(petEntity)
        TriggerServerEvent('murderface-pets:server:syncLeash', netId, true)
    end
end

-- ============================
--     Auto-Detach Hooks
-- ============================

--- Remove leash for a specific pet hash (called from despawn, death, vehicle, etc.)
---@param hash string Pet hash
function DetachLeash(hash)
    if not leashRopes[hash] then return end
    destroyRope(hash)

    -- Notify other clients
    local petData = ActivePed:findByHash(hash)
    if petData and DoesEntityExist(petData.entity) then
        local netId = NetworkGetNetworkIdFromEntity(petData.entity)
        TriggerServerEvent('murderface-pets:server:syncLeash', netId, false)
    end
end

--- Remove all leashes (logout/disconnect)
function DetachAllLeashes()
    for hash in pairs(leashRopes) do
        destroyRope(hash)
    end
    for netId, rope in pairs(otherLeashes) do
        if DoesRopeExist(rope) then
            DeleteRope(rope)
        end
        otherLeashes[netId] = nil
    end
    RopeUnloadTextures()
end

-- ============================
--     Network Sync
-- ============================

--- Create a leash rope for another player's pet (visual only, no enforcement)
---@param ownerPed number The other player's ped handle
---@param petEntity number The pet ped handle
---@param petNetId number Network ID of the pet
local function createLeashForOther(ownerPed, petEntity, petNetId)
    if otherLeashes[petNetId] then return end
    if not DoesEntityExist(ownerPed) or not DoesEntityExist(petEntity) then return end

    local cfg = Config.leash

    RopeLoadTextures()
    local timeout = 0
    while not RopeAreTexturesLoaded() do
        Wait(0)
        timeout = timeout + 1
        if timeout > 500 then return end
    end

    local pos = GetEntityCoords(ownerPed)
    local rope = AddRope(
        pos.x, pos.y, pos.z,
        0.0, 0.0, 0.0,
        cfg.length,
        cfg.ropeType,
        cfg.length,
        0.5,
        1.0,
        false,
        false,
        false,
        1.0,
        false
    )

    local playerBone = GetPedBoneIndex(ownerPed, cfg.playerBone)
    local petBone = GetPedBoneIndex(petEntity, cfg.petBone)

    ---@diagnostic disable-next-line: param-type-mismatch
    AttachEntitiesToRope(
        rope, ownerPed, petEntity,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        cfg.length, false, false,
        playerBone, petBone
    )

    ActivatePhysics(rope)
    otherLeashes[petNetId] = rope
end

--- Destroy a leash rope for another player's pet
---@param petNetId number Network ID of the pet
local function destroyLeashForOther(petNetId)
    local rope = otherLeashes[petNetId]
    if rope then
        if DoesRopeExist(rope) then
            DeleteRope(rope)
        end
        otherLeashes[petNetId] = nil
    end
end

RegisterNetEvent('murderface-pets:client:syncLeash', function(ownerSrc, petNetId, leashed)
    -- Skip if this is our own leash (we already created it locally)
    if ownerSrc == cache.serverId then return end

    local petEntity = NetworkGetEntityFromNetworkId(petNetId)
    if petEntity == 0 then return end

    local ownerPlayer = GetPlayerFromServerId(ownerSrc)
    if ownerPlayer == -1 then return end
    local ownerPed = GetPlayerPed(ownerPlayer)

    if leashed then
        createLeashForOther(ownerPed, petEntity, petNetId)
    else
        destroyLeashForOther(petNetId)
    end
end)
