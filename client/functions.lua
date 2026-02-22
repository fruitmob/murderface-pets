-- murderface-pets: Client-side helper functions
-- Entity management, animation helpers, combat logic, K9 search, vehicle handling.
-- Folded in: Draw2DText, RayCastGamePlayCamera from c_util.lua
-- Removed: waitForModel (lib.requestModel), waitForAnimation (lib.requestAnimDict)

-- ============================
--    Raycast / Draw Helpers
-- ============================

function DrawText3D(coords, text, scale, r, g, b, a)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextFont(4)
    SetTextScale(0.0, scale or 0.35)
    SetTextColour(r or 255, g or 255, b or 255, a or 215)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function Draw2DText(content, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextEntry('STRING')
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    AddTextComponentString(content)
    DrawText(x, y)
end

local function rotationToDirection(rotation)
    local rad = math.pi / 180
    local rx = rad * rotation.x
    local rz = rad * rotation.z
    return vector3(
        -math.sin(rz) * math.abs(math.cos(rx)),
        math.cos(rz) * math.abs(math.cos(rx)),
        math.sin(rx)
    )
end

function RayCastGamePlayCamera(distance)
    local rot = GetGameplayCamRot()
    local pos = GetGameplayCamCoord()
    local dir = rotationToDirection(rot)
    local dest = pos + dir * distance
    local _, _, hitCoords, _, hitEntity = GetShapeTestResult(
        StartShapeTestRay(pos.x, pos.y, pos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    )
    return hitCoords, hitEntity
end

-- ============================
--    Entity Facing
-- ============================

function makeEntityFaceEntity(entity1, entity2)
    local p1 = GetEntityCoords(entity1, true)
    local p2 = GetEntityCoords(entity2, true)
    local heading = GetHeadingFromVector_2d(p2.x - p1.x, p2.y - p1.y)
    SetEntityHeading(entity1, heading)
end

-- ============================
--    Follow Player
-- ============================

function TaskFollowTargetedPlayer(follower, targetPlayer, distanceToStopAt, skip)
    ClearPedTasks(follower)
    if skip == false then
        TaskGoToCoordAnyMeans(follower, GetEntityCoords(targetPlayer), 10.0, 0, 0, 0, 0)
        Wait(5000)
    end
    -- Use level-based speed if the follower is an active pet
    local moveSpeed = 5.0
    local activePed = ActivePed:read()
    if activePed and activePed.entity == follower then
        moveSpeed = Config.getFollowSpeed(activePed.item.metadata.level or 0)
    end
    TaskFollowToOffsetOfEntity(follower, targetPlayer, 2.5, 2.5, 2.5, moveSpeed, 10.0, distanceToStopAt, 1)
    return true
end

-- ============================
--    Animations
-- ============================

function whistleAnimation(ped, timeout)
    CreateThread(function()
        lib.requestAnimDict('rcmnigel1c')
        TaskPlayAnim(ped, 'rcmnigel1c', 'hailing_whistle_waive_a', 2.7, 2.7, -1, 49, 0, 0, 0, 0)
        Wait(timeout)
        ClearPedTasks(ped)
    end)
end

-- ============================
--    Blips
-- ============================

function createBlip(data)
    local blip
    if data.entity then
        blip = AddBlipForEntity(data.entity)
    elseif data.coords then
        blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    end
    if not blip then return nil end
    SetBlipSprite(blip, data.sprite)
    SetBlipColour(blip, data.colour)
    SetBlipAsShortRange(blip, data.shortRange or false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.text)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ============================
--    Ped Management
-- ============================

-- Custom relationship group: ambient peds won't attack/flee our pets
local petGroupHash
do
    local _, hash = AddRelationshipGroup('MFPETS_COMPANION')
    petGroupHash = hash

    local civGroups = { 'CIVMALE', 'CIVFEMALE', 'COP', 'SECURITY_GUARD', 'PRIVATE_SECURITY', 'FIREMAN', 'MEDIC' }
    for _, group in ipairs(civGroups) do
        local gh = GetHashKey(group)
        SetRelationshipBetweenGroups(1, petGroupHash, gh) -- pet respects civs
        SetRelationshipBetweenGroups(1, gh, petGroupHash) -- civs respect pet
    end
    SetRelationshipBetweenGroups(0, petGroupHash, GetHashKey('PLAYER')) -- companion with player
    SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), petGroupHash)
end

function DeletePed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end

function CreateAPed(hash, pos)
    lib.requestModel(hash)
    local ped = CreatePed(5, hash, pos.x, pos.y, pos.z, 0.0, true, false)
    while not DoesEntityExist(ped) do
        Wait(10)
    end

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, 0)
    SetPedRelationshipGroupHash(ped, petGroupHash)
    SetModelAsNoLongerNeeded(hash)

    if Config.debug then
        print(('[murderface-pets] ^3CreateAPed DONE^0: ped=%s exists=%s health=%s pos=%.1f,%.1f,%.1f'):format(
            tostring(ped), tostring(DoesEntityExist(ped)), tostring(GetEntityHealth(ped)), pos.x, pos.y, pos.z))
    end
    return ped
end

-- ============================
--    Spawn Location
-- ============================

function getSpawnLocation(plyped)
    if IsPedInAnyVehicle(plyped, true) then
        return GetOffsetFromEntityInWorldCoords(plyped, -2.0, 1.0, 0.5)
    else
        return GetOffsetFromEntityInWorldCoords(plyped, 1.0, -1.0, 0.5)
    end
end

-- ============================
--    Vehicle Eject
-- ============================

function doSomethingIfPedIsInsideVehicle(ped)
    if IsPedInAnyVehicle(ped, true) then
        local coord = getSpawnLocation(PlayerPedId())
        SetEntityCoords(ped, coord, 1, 0, 0, 1)
    end
    Wait(75)
end

-- ============================
--    Put Pet In Vehicle
-- ============================

---@param vehicle number Vehicle entity handle
---@param ped number Pet ped handle
---@return boolean success
function putPetInVehicle(vehicle, ped)
    if not vehicle or vehicle == 0 then return false end
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, seat) then
            SetPedIntoVehicle(ped, vehicle, seat)
            local activePed = ActivePed:read()
            if activePed and activePed.animClass then
                Anims.play(ped, activePed.animClass, 'sit', { flag = 1 })
            end
            return true
        end
    end
    return false
end

function getIntoCar()
    local plyped = PlayerPedId()
    local activePet = ActivePed:read()
    if not activePet then return end

    local petPed = activePet.entity

    -- If pet is already in a vehicle, eject it
    if IsPedInAnyVehicle(petPed, false) then
        local coord = getSpawnLocation(plyped)
        SetEntityCoords(petPed, coord.x, coord.y, coord.z, false, false, false, false)
        Wait(100)
        ClearPedTasks(petPed)
        TaskFollowTargetedPlayer(petPed, plyped, 3.0, true)
        return
    end

    -- Otherwise, board pet into owner's vehicle
    if not IsPedSittingInAnyVehicle(plyped) then
        lib.notify({ description = Lang:t('menu.action_menu.error.need_to_be_inside_car'), type = 'error', duration = 7000 })
        return
    end

    local dist = #(GetEntityCoords(plyped) - GetEntityCoords(petPed))
    if dist > 8 then
        lib.notify({ description = Lang:t('menu.action_menu.error.to_far'), type = 'error', duration = 7000 })
        return
    end

    local vehicle = GetVehiclePedIsUsing(plyped)
    if not putPetInVehicle(vehicle, petPed) then
        lib.notify({ description = Lang:t('menu.action_menu.error.no_empty_seat'), type = 'error', duration = 7000 })
    end
end

-- ============================
--    Closest Player / Vehicle
-- ============================

function getClosestPlayer(coords)
    local players = GetActivePlayers()
    local closestPlayer = -1
    local closestDist = math.huge
    for _, id in pairs(players) do
        if id ~= PlayerId() then
            local ped = GetPlayerPed(id)
            local dist = #(coords - GetEntityCoords(ped))
            if dist < closestDist then
                closestDist = dist
                closestPlayer = id
            end
        end
    end
    return closestPlayer, closestDist
end

function getClosestVehicle()
    local coords = GetEntityCoords(PlayerPedId())
    local vehicles = GetGamePool('CVehicle')
    local closest, closestDist = nil, math.huge
    for _, veh in pairs(vehicles) do
        local dist = #(coords - GetEntityCoords(veh))
        if dist < closestDist then
            closest = veh
            closestDist = dist
        end
    end
    return closest
end

-- ============================
--    Go There (Raycast)
-- ============================

function goThere(ped)
    local activePed = ActivePed:read()
    local hash = activePed and activePed.item and activePed.item.metadata and activePed.item.metadata.hash
    while true do
        local color = { r = 2, g = 241, b = 181, a = 200 }
        local position = GetEntityCoords(PlayerPedId())
        local coords = RayCastGamePlayCamera(1000.0)
        Draw2DText('Press ~g~E~w~ To go there', 4, { 255, 255, 255 }, 0.4, 0.43, 0.913)
        if IsControlJustReleased(0, 38) then
            if hash then SetBusy(hash, true) end
            TaskGoToCoordAnyMeans(ped, coords, 10.0, 0, 0, 0, 0)
            -- Monitor arrival then resume following
            CreateThread(function()
                local target = coords
                while DoesEntityExist(ped) and not IsEntityDead(ped) do
                    local petPos = GetEntityCoords(ped)
                    if #(petPos - target) < 3.0 then break end
                    Wait(1000)
                end
                Wait(2000)
                if hash then SetBusy(hash, false) end
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    TaskFollowTargetedPlayer(ped, PlayerPedId(), 3.0, true)
                end
            end)
            return
        end
        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
        Wait(0)
    end
end

-- ============================
--    Attack Logic
-- ============================

-- Reusable hunter relationship group — created once, reused each hunt
local hunterGroupHash
do
    local _, h = AddRelationshipGroup('MFPETS_HUNTER')
    hunterGroupHash = h
end

function AttackTargetedPed(attackerPed, targetPed)
    if not attackerPed or not targetPed then return false end

    -- Let the combat AI react to target movement/fleeing
    SetBlockingOfNonTemporaryEvents(attackerPed, false)

    -- Move pet into hunter group hostile toward the target's group
    local targetGroup = GetPedRelationshipGroupHash(targetPed)
    SetPedRelationshipGroupHash(attackerPed, hunterGroupHash)
    SetRelationshipBetweenGroups(5, hunterGroupHash, targetGroup)   -- 5 = Hate
    SetCanAttackFriendly(attackerPed, true, false)

    -- Full combat configuration BEFORE issuing tasks
    SetPedCombatAttributes(attackerPed, 46, 1)  -- fight armed peds while unarmed
    SetPedCombatAbility(attackerPed, 100)        -- max skill
    SetPedCombatRange(attackerPed, 2)            -- far engagement distance
    SetPedCombatMovement(attackerPed, 3)         -- suicidal aggression
    SetPedFleeAttributes(attackerPed, 0, 0)      -- never flee

    -- Single combat task (animals can't aim, so TaskGoToEntityWhileAimingAtEntity was wasted)
    TaskCombatPed(attackerPed, targetPed, 0, 16)

    -- Re-engage loop: if pet somehow drops combat, re-issue the task
    while DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, 0) do
        if not DoesEntityExist(attackerPed) or IsEntityDead(attackerPed) then break end
        if not IsPedInCombat(attackerPed) then
            TaskCombatPed(attackerPed, targetPed, 0, 16)
        end
        Wait(1000)
    end

    -- Restore passive companion state
    SetBlockingOfNonTemporaryEvents(attackerPed, true)
    SetCanAttackFriendly(attackerPed, false, false)
    SetPedRelationshipGroupHash(attackerPed, petGroupHash)
    TaskFollowTargetedPlayer(attackerPed, PlayerPedId(), 3.0, false)
end

function attackLogic(alreadyHunting)
    while true do
        Wait(0)
        local color = { r = 2, g = 241, b = 181, a = 200 }
        local plyped = PlayerPedId()
        local position = GetEntityCoords(plyped)
        local coords, entity = RayCastGamePlayCamera(1000.0)
        Draw2DText('PRESS ~g~E~w~ TO ATTACK TARGET', 4, { 255, 255, 255 }, 0.4, 0.43, 0.913)

        if IsControlJustReleased(0, 38) then
            local activePed = ActivePed:read()
            if not activePed then return false end
            ClearPedTasks(activePed.entity)

            if not IsEntityAPed(entity) then
                return false
            end

            local pet = activePed.entity
            local hash = activePed.item.metadata.hash
            SetBusy(hash, true)
            AttackTargetedPed(pet, entity)
            alreadyHunting.state = true

            while not IsPedDeadOrDying(entity) do
                Wait(5)
                local pedCoord = GetEntityCoords(entity)
                local petCoord = GetEntityCoords(pet)
                local dist = #(pedCoord - petCoord)
                DrawMarker(2, pedCoord.x, pedCoord.y, pedCoord.z + 2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 1.0, 1.0, 1.0, 255, 128, 0, 50, false, true, 2, nil, nil, false)

                if IsPedDeadOrDying(entity) then
                    -- Award hunt kill XP
                    TriggerServerEvent('murderface-pets:server:updatePetStats',
                        hash, { key = 'activity', action = 'huntKill' })
                    alreadyHunting.state = false
                    SetBusy(hash, false)
                    return true
                end
                if dist >= Config.chaseDistance then
                    alreadyHunting.state = false
                    SetBusy(hash, false)
                    return true
                end
            end
            -- Prey died in the outer loop
            TriggerServerEvent('murderface-pets:server:updatePetStats',
                hash, { key = 'activity', action = 'huntKill' })
            alreadyHunting.state = false
            SetBusy(hash, false)
            return true
        end

        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
    end
end

-- ============================
--    Hunt and Grab
-- ============================

function HuntandGrab(plyped, activePed)
    local hash = activePed.item.metadata.hash
    while true do
        Wait(0)
        local color = { r = 2, g = 241, b = 181, a = 200 }
        local position = GetEntityCoords(plyped)
        local coords, entity = RayCastGamePlayCamera(1000.0)
        Draw2DText('Press ~g~E~w~ To go there', 4, { 255, 255, 255 }, 0.4, 0.43, 0.913)

        if IsControlJustReleased(0, 38) then
            local pet = activePed.entity
            if IsPedAPlayer(entity) or not IsEntityAPed(entity) or entity == pet then
                lib.notify({ description = Lang:t('error.could_not_do_that'), type = 'error', duration = 7000 })
                return
            end

            SetBusy(hash, true)
            TaskFollowToOffsetOfEntity(pet, entity, 0.0, 0.0, 0.0, 5.0, 10.0, 1.0, 1)
            while true do
                local pedCoord = GetEntityCoords(entity)
                local petCoord = GetEntityCoords(pet)
                local dist = #(pedCoord - petCoord)
                if dist >= 50.0 then
                    break
                else
                    AttackTargetedPed(pet, entity)
                    while not IsPedDeadOrDying(entity) do
                        Wait(250)
                    end
                    -- Award hunt kill XP
                    TriggerServerEvent('murderface-pets:server:updatePetStats',
                        hash, { key = 'activity', action = 'huntKill' })
                    SetEntityCoords(entity, GetOffsetFromEntityInWorldCoords(pet, 0.0, 0.25, 0.0))
                    AttachEntityToEntity(entity, pet, 11816, 0.05, 0.05, 0.5, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    break
                end
            end

            TaskFollowToOffsetOfEntity(pet, plyped, 2.0, 2.0, 2.0, 1.0, 10.0, 3.0, 1)
            while true do
                local pedCoord = GetEntityCoords(plyped)
                local petCoord = GetEntityCoords(pet)
                local dist = #(pedCoord - petCoord)
                if (entity and dist < 3.0) or dist > 50.0 then
                    DetachEntity(entity, true, false)
                    ClearPedSecondaryTask(pet)
                    SetBusy(hash, false)
                    TaskFollowTargetedPlayer(pet, PlayerPedId(), 3.0, true)
                    return
                end
                Wait(1000)
            end
            SetBusy(hash, false)
            return
        end

        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g, color.b, color.a, false, true, 2, nil, nil, false)
    end
end

-- ============================
--    Tracker Specialization
-- ============================

--- Tracker specialization: scan and highlight nearby peds/animals
---@param activePed table ActivePed data
function TrackerScan(activePed)
    local specCfg = Config.specializations and Config.specializations.tracker
    if not specCfg then return end

    local petEntity = activePed.entity
    local petPos = GetEntityCoords(petEntity)
    local radius = specCfg.trackRadius
    local duration = specCfg.markerDuration

    -- Pet barks to indicate scanning
    SetAnimalMood(petEntity, 1)
    PlayAnimalVocalization(petEntity, 3, 'bark')

    -- Find nearby peds within radius
    local pedPool = GetGamePool('CPed')
    local playerPed = PlayerPedId()
    local targets = {}

    for _, ped in ipairs(pedPool) do
        if ped ~= petEntity and ped ~= playerPed and not IsEntityDead(ped) then
            local dist = #(petPos - GetEntityCoords(ped))
            if dist <= radius then
                targets[#targets + 1] = ped
            end
        end
    end

    if #targets == 0 then
        lib.notify({ description = 'No targets detected nearby', type = 'info', duration = 3000 })
        return
    end

    lib.notify({
        description = string.format('Detected %d target%s nearby!', #targets, #targets == 1 and '' or 's'),
        type = 'success',
        duration = 5000,
    })

    -- Draw markers above detected peds for the configured duration
    CreateThread(function()
        local endTime = GetGameTimer() + duration
        while GetGameTimer() < endTime do
            for i = #targets, 1, -1 do
                local ped = targets[i]
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    local pos = GetEntityCoords(ped)
                    DrawMarker(2, pos.x, pos.y, pos.z + 2.0,
                        0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.5, 0.5, 0.5,
                        50, 200, 255, 150,
                        false, true, 2, nil, nil, false)
                else
                    table.remove(targets, i)
                end
            end
            if #targets == 0 then break end
            Wait(0)
        end
    end)

    -- Award tracking XP (server-side, with cooldown)
    TriggerServerEvent('murderface-pets:server:updatePetStats',
        activePed.item.metadata.hash, { key = 'activity', action = 'tracking' })
end

-- ============================
--    K9: Job Check
-- ============================

--- Check whether the player's current job is in the Config.k9.jobs list
---@return boolean
function isK9Job()
    local job = QBX.PlayerData.job
    if not job then return false end
    for _, jobName in pairs(Config.k9.jobs) do
        if job.name == jobName then
            return true
        end
    end
    return false
end

-- ============================
--    K9: Search Person
-- ============================

function SearchLogic(_, activePed)
    local job = QBX.PlayerData.job
    if not job then return end

    if not isK9Job() then
        lib.notify({ description = 'You are not allowed to do this action', type = 'error', duration = 7000 })
        return
    end
    if not job.onduty then
        lib.notify({ description = 'You must be on duty to do this action', type = 'error', duration = 7000 })
        return
    end

    ClearPedTasks(activePed.entity)
    local pedCoord = GetEntityCoords(PlayerPedId())
    local closestPlayer, closestDist = getClosestPlayer(pedCoord)
    if closestPlayer == -1 or closestDist > 10.0 then
        lib.notify({ description = 'No one nearby to search', type = 'error', duration = 5000 })
        return
    end

    local pedplayer = GetPlayerPed(closestPlayer)
    TaskGoToCoordAnyMeans(activePed.entity, GetEntityCoords(pedplayer), 10.0, 0, 0, 0, 0)

    local finished = false
    CreateThread(function()
        while not finished do
            Wait(5)
            local targetPed = GetPlayerPed(closestPlayer)
            if targetPed == 0 or not DoesEntityExist(targetPed) then break end
            pedCoord = GetEntityCoords(targetPed)
            DrawMarker(2, pedCoord.x, pedCoord.y, pedCoord.z + 2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 1.0, 1.0, 1.0, 255, 128, 0, 50, false, true, 2, nil, nil, false)
        end
    end)

    local targetId = GetPlayerServerId(closestPlayer)
    local result = lib.callback.await('murderface-pets:server:searchInventory', false, targetId)
    Wait(5000)

    Anims.play(activePed.entity, activePed.animClass, 'misc', { clip = 'indicate_low' })
    Wait(5000)

    if result then
        lib.notify({ description = 'K9 found something', type = 'success', duration = 7000 })
        SetAnimalMood(activePed.entity, 1)
        PlayAnimalVocalization(activePed.entity, 3, 'bark')
        Anims.play(activePed.entity, activePed.animClass, 'misc', { clip = 'indicate_high' })
        -- Award K9 search XP
        TriggerServerEvent('murderface-pets:server:updatePetStats',
            activePed.item.metadata.hash, { key = 'activity', action = 'k9Search' })
    end
    finished = true

    -- Resume following owner after search completes
    if DoesEntityExist(activePed.entity) and not IsEntityDead(activePed.entity) then
        Wait(2000)
        TaskFollowTargetedPlayer(activePed.entity, PlayerPedId(), 3.0, true)
    end
end

-- ============================
--    K9: Search Vehicle
-- ============================

local searchOffsets = {
    { offset = vector4(-1.5, 0.0, 0.0, -90.0) },
    { offset = vector4(0.0, -2.8, 0.0, 0.0) },
}

function k9SearchVehicle(veh, activePed)
    if not activePed.petConfig or not activePed.petConfig.isK9 then
        lib.notify({ description = 'This pet can not do that!', type = 'error', duration = 7000 })
        return
    end

    if not isK9Job() then
        lib.notify({ description = 'You are not allowed to do this action', type = 'error', duration = 7000 })
        return
    end

    local job = QBX.PlayerData.job
    if not job or not job.onduty then
        lib.notify({ description = 'You must be on duty to do this action', type = 'error', duration = 7000 })
        return
    end

    for key, value in pairs(searchOffsets) do
        local vehHead = GetEntityHeading(veh)
        local plate = GetVehicleNumberPlateText(veh)
        local pos = GetOffsetFromEntityInWorldCoords(veh, value.offset.x, value.offset.y, value.offset.z)
        TaskFollowNavMeshToCoord(activePed.entity, pos.x, pos.y, pos.z, 3.0, -1, 0.0, 1, 0)
        Wait(4000)
        TaskAchieveHeading(activePed.entity, vehHead + value.offset.w, -1)
        Wait(2000)

        local result = lib.callback.await('murderface-pets:server:searchVehicle', false, { key = key, plate = plate })
        if result then
            SetAnimalMood(activePed.entity, 1)
            PlayAnimalVocalization(activePed.entity, 3, 'bark')
            Anims.play(activePed.entity, activePed.animClass, 'misc', { clip = 'indicate_high' })
            -- Award K9 search XP
            TriggerServerEvent('murderface-pets:server:updatePetStats',
                activePed.item.metadata.hash, { key = 'activity', action = 'k9Search' })
        else
            Anims.play(activePed.entity, activePed.animClass, 'sit')
        end
        Wait(3000)
    end

    -- Resume following owner after search completes
    if DoesEntityExist(activePed.entity) and not IsEntityDead(activePed.entity) then
        Wait(1000)
        TaskFollowTargetedPlayer(activePed.entity, PlayerPedId(), 3.0, true)
    end
end
