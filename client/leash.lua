-- murderface-pets: Prop-based leash system
-- Uses physical leash prop models (from dusa_addonpets streaming) attached between
-- player hand bone and pet neck bone. Much more reliable than FiveM native ropes
-- which stretch, clip through ground, and desync across clients.
--
-- Requires dusa_addonpets (or equivalent) streaming resource for leash_model props.
-- Requires Config.leash block in config.lua.
-- Requires server sync event in server.lua.
-- Requires "Toggle Leash" entry in menu.lua.

local leashProps = {}        -- { [petHash] = { prop = objectHandle, petEntity = ped } }
local leashEnforcing = {}    -- { [petHash] = true } (active enforcement threads)
local otherLeashes = {}      -- { [petNetId] = objectHandle } (props for other players' pets)

-- Bone IDs
local PLAYER_HAND_BONE = 57005   -- SKEL_R_Hand (right hand)
local PET_NECK_BONE    = 39317   -- SKEL_Neck_1

-- ============================
--     Leash State Query
-- ============================

--- Check if a pet (by hash) is currently leashed
---@param hash string Pet hash
---@return boolean
function IsLeashed(hash)
    return leashProps[hash] ~= nil
end

-- ============================
--     Prop Creation
-- ============================

--- Create a leash prop attached between player hand and pet neck
---@param playerPed number Player ped handle
---@param petEntity number Pet ped handle
---@param hash string Pet hash
---@param propModel string Prop model name (default: 'leash_model')
---@return boolean success
local function createLeashProp(playerPed, petEntity, hash, propModel)
    if leashProps[hash] then return false end
    if not DoesEntityExist(playerPed) or not DoesEntityExist(petEntity) then return false end

    local cfg = Config.leash
    propModel = propModel or cfg.defaultModel or 'leash_model'

    -- Load the prop model
    local modelHash = type(propModel) == 'string' and GetHashKey(propModel) or propModel
    lib.requestModel(modelHash, 10000)

    if not HasModelLoaded(modelHash) then
        print('[murderface-pets] ^1Failed to load leash model: ' .. tostring(propModel) .. '^0')
        return false
    end

    -- Spawn the leash prop ABOVE the player to avoid any collision damage
    -- Use network=false (local prop) to avoid server-side entity issues
    local playerPos = GetEntityCoords(playerPed)
    local prop = CreateObject(modelHash, playerPos.x, playerPos.y, playerPos.z + 2.0, false, true, false)

    if not prop or prop == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return false
    end

    -- IMMEDIATELY disable collision before anything else can happen
    SetEntityCollision(prop, false, false)
    SetEntityNoCollisionEntity(prop, playerPed, false)
    SetEntityNoCollisionEntity(prop, petEntity, false)
    SetEntityAlpha(prop, 255, false)

    -- Wait one frame for the object to initialize
    Wait(0)

    if not DoesEntityExist(prop) then
        SetModelAsNoLongerNeeded(modelHash)
        return false
    end

    -- Get bone indices
    local playerBone = GetPedBoneIndex(playerPed, PLAYER_HAND_BONE)

    -- Attach leash prop to player's right hand
    AttachEntityToEntity(
        prop,           -- entity to attach (leash prop)
        playerPed,      -- entity to attach TO (player)
        playerBone,     -- bone on player
        0.0, 0.0, 0.0, -- position offset
        0.0, 0.0, 0.0, -- rotation offset
        false,          -- p9 (was true — false prevents physics interactions)
        true,           -- useSoftPinning
        false,          -- collision disabled
        false,          -- isPed = false (it's a prop, not a ped)
        0,              -- rotationOrder
        true            -- syncRot
    )

    -- Store reference
    leashProps[hash] = {
        prop = prop,
        petEntity = petEntity,
        propModel = propModel,
    }

    SetModelAsNoLongerNeeded(modelHash)
    return true
end

--- Destroy a leash prop by pet hash
---@param hash string Pet hash
local function destroyLeashProp(hash)
    local data = leashProps[hash]
    if data then
        if DoesEntityExist(data.prop) then
            DetachEntity(data.prop, true, true)
            DeleteEntity(data.prop)
        end
        leashProps[hash] = nil
    end
    leashEnforcing[hash] = nil
end

-- ============================
--     Distance Enforcement
-- ============================

--- Keep the pet within leash range via script-side enforcement
--- The prop is purely visual — this thread handles the actual tethering behavior
---@param petEntity number Pet ped handle
---@param hash string Pet hash
local function startEnforcement(petEntity, hash)
    if leashEnforcing[hash] then return end
    leashEnforcing[hash] = true

    CreateThread(function()
        local cfg = Config.leash
        local maxDist = cfg.length + 1.0  -- small buffer before pulling back
        local hardMax = cfg.length + 3.0  -- teleport threshold

        while leashEnforcing[hash]
              and DoesEntityExist(petEntity)
              and not IsEntityDead(petEntity) do

            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local petPos = GetEntityCoords(petEntity)
            local dist = #(playerPos - petPos)

            if dist > hardMax then
                -- Pet drifted way too far — teleport close
                local spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, 1.0, -1.0, 0.0)
                SetEntityCoords(petEntity, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
            elseif dist > maxDist then
                -- Pet too far — pull it closer
                TaskGoToEntity(petEntity, playerPed, -1, 1.0, 3.0, 0, 0)
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
---@param propModel? string Optional leash prop model override
function ToggleLeash(activePed, propModel)
    if not Config.leash or not Config.leash.enabled then return end

    local hash = activePed.item.metadata.hash
    local petEntity = activePed.entity

    -- Safety: bail if entity is dead or invalid
    if not DoesEntityExist(petEntity) or IsEntityDead(petEntity) then
        lib.notify({ description = 'Cannot leash — pet is unavailable', type = 'error', duration = 3000 })
        return
    end

    if IsLeashed(hash) then
        -- Remove leash
        destroyLeashProp(hash)

        -- Restore normal follow distance
        TaskFollowTargetedPlayer(petEntity, PlayerPedId(), 1.5, true)

        lib.notify({ description = 'Leash removed', type = 'info', duration = 3000 })

        -- Sync to other clients (only if we have a valid net ID)
        local netId = NetworkGetNetworkIdFromEntity(petEntity)
        if netId and netId ~= 0 then
            TriggerServerEvent('murderface-pets:server:syncLeash', netId, false, nil)
        end
    else
        -- Attach leash
        CreateThread(function()
            local playerPed = PlayerPedId()
            local ok = createLeashProp(playerPed, petEntity, hash, propModel)

            if not ok then
                lib.notify({ description = 'Failed to create leash', type = 'error', duration = 3000 })
                return
            end

            -- Tighter follow distance while leashed (don't ClearPedTasks — causes stutter)
            local speed = Config.getFollowSpeed(activePed.item.metadata.level or 0)
            TaskFollowToOffsetOfEntity(petEntity, playerPed, 0.0, -1.0, 0.0, speed, -1, 1.0, true)

            -- Start distance enforcement
            if Config.leash.enforceDistance then
                startEnforcement(petEntity, hash)
            end

            lib.notify({ description = 'Leash attached', type = 'success', duration = 3000 })

            -- Sync to other clients (only if valid net ID)
            local netId = NetworkGetNetworkIdFromEntity(petEntity)
            if netId and netId ~= 0 then
                TriggerServerEvent('murderface-pets:server:syncLeash', netId, true, propModel or Config.leash.defaultModel)
            end
        end)
    end
end

-- ============================
--     Auto-Detach Hooks
-- ============================

--- Remove leash for a specific pet hash (called from despawn, death, vehicle, etc.)
---@param hash string Pet hash
function DetachLeash(hash)
    if not leashProps[hash] then return end
    destroyLeashProp(hash)

    -- Notify other clients
    local petData = ActivePed:findByHash(hash)
    if petData and DoesEntityExist(petData.entity) then
        local netId = NetworkGetNetworkIdFromEntity(petData.entity)
        if netId and netId ~= 0 then
            TriggerServerEvent('murderface-pets:server:syncLeash', netId, false, nil)
        end
    end
end

--- Remove all leashes (logout/disconnect)
function DetachAllLeashes()
    for hash in pairs(leashProps) do
        destroyLeashProp(hash)
    end
    for netId, prop in pairs(otherLeashes) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        otherLeashes[netId] = nil
    end
end

-- ============================
--     Network Sync
-- ============================

--- Create a leash prop for another player's pet (visual only, no enforcement)
---@param ownerPed number The other player's ped handle
---@param petEntity number The pet ped handle
---@param petNetId number Network ID of the pet
---@param propModel string Prop model name
local function createLeashForOther(ownerPed, petEntity, petNetId, propModel)
    if otherLeashes[petNetId] then return end
    if not DoesEntityExist(ownerPed) or not DoesEntityExist(petEntity) then return end

    propModel = propModel or 'leash_model'
    local modelHash = GetHashKey(propModel)
    lib.requestModel(modelHash, 10000)

    if not HasModelLoaded(modelHash) then return end

    local pos = GetEntityCoords(ownerPed)
    local prop = CreateObject(modelHash, pos.x, pos.y, pos.z + 2.0, false, true, false)

    if not prop or prop == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    -- Disable collision IMMEDIATELY before Wait
    SetEntityCollision(prop, false, false)
    Wait(0)

    local playerBone = GetPedBoneIndex(ownerPed, PLAYER_HAND_BONE)

    AttachEntityToEntity(
        prop, ownerPed, playerBone,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        false, true, false, false, 0, true -- isPed=false (it's a prop)
    )

    otherLeashes[petNetId] = prop
    SetModelAsNoLongerNeeded(modelHash)
end

--- Destroy a leash prop for another player's pet
---@param petNetId number Network ID of the pet
local function destroyLeashForOther(petNetId)
    local prop = otherLeashes[petNetId]
    if prop then
        if DoesEntityExist(prop) then
            DetachEntity(prop, true, true)
            DeleteEntity(prop)
        end
        otherLeashes[petNetId] = nil
    end
end

RegisterNetEvent('murderface-pets:client:syncLeash', function(ownerSrc, petNetId, leashed, propModel)
    -- Skip our own leash (we already created it locally)
    if ownerSrc == cache.serverId then return end

    local petEntity = NetworkGetEntityFromNetworkId(petNetId)
    if petEntity == 0 then return end

    local ownerPlayer = GetPlayerFromServerId(ownerSrc)
    if ownerPlayer == -1 then return end
    local ownerPed = GetPlayerPed(ownerPlayer)

    if leashed then
        createLeashForOther(ownerPed, petEntity, petNetId, propModel)
    else
        destroyLeashForOther(petNetId)
    end
end)
