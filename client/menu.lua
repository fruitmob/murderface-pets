-- murderface-pets: Context menus (ox_lib)
-- Config-driven — uses pet traits (animClass, canHunt, isK9, canPet, canTrick, icon).

local alreadyHunting = { state = false }

-- =======================================
--        Supply Shop Icons
-- =======================================

local supplyIcons = {
    murderface_leash       = { icon = 'link',         iconColor = '#228be6', desc = 'Keep your pet on a leash' },
    murderface_food        = { icon = 'bowl-food',    iconColor = '#e8590c', desc = 'Restores 50 hunger' },
    murderface_firstaid    = { icon = 'kit-medical',  iconColor = '#e03131', desc = 'Heals 25% max HP or revives' },
    murderface_waterbottle = { icon = 'bottle-water', iconColor = '#228be6', desc = 'Refillable — holds 10 uses' },
    murderface_collar      = { icon = 'ring',         iconColor = '#fab005', desc = 'Transfer pet ownership' },
    murderface_nametag     = { icon = 'tag',          iconColor = '#fab005', desc = 'Give your pet a new name' },
    murderface_groomingkit = { icon = 'scissors',     iconColor = '#e64980', desc = 'Change appearance' },
    murderface_doghouse   = { icon = 'house-chimney', iconColor = '#e8590c', desc = 'Place for breeding & pet rest' },
}

-- =======================================
--           Action Menu Items
-- =======================================

local menu = {
    {
        label = Lang:t('menu.action_menu.follow'),
        TYPE = 'Follow',
        icon = 'person-walking',
        iconColor = '#12b886',
        description = 'Your pet follows at your side',
        triggerNotification = { 'PETNAME is now following you!', 'PETNAME failed to follow you!' },
        action = function(plyped, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            return TaskFollowTargetedPlayer(activePed.entity, plyped, 3.0, false)
        end
    },
    {
        label = Lang:t('menu.action_menu.hunt'),
        TYPE = 'Hunt',
        icon = 'crosshairs',
        iconColor = '#e8590c',
        description = 'Target an animal to hunt',
        triggerNotification = { 'PETNAME is now hunting!', 'PETNAME can not do that!' },
        show = function(activePed)
            if not activePed.canHunt then return false end
            local hash = activePed.item.metadata.hash
            if IsLeashed(hash) or IsGuarding(hash) then return false end
            return (activePed.item.metadata.level or 0) >= Config.progression.minHuntLevel
        end,
        action = function(_, activePed)
            local minLevel = Config.progression.minHuntLevel
            if not activePed.canHunt then
                lib.notify({ description = Lang:t('menu.action_menu.error.pet_unable_to_hunt'), type = 'error', duration = 7000 })
                return false
            end

            if alreadyHunting.state then
                lib.notify({ description = Lang:t('menu.action_menu.error.already_hunting_something'), type = 'error', duration = 7000 })
                return
            end

            if activePed.item.metadata.level < minLevel then
                lib.notify({
                    description = string.format(Lang:t('menu.action_menu.error.not_meet_min_requirement_to_hunt'), minLevel),
                    type = 'error', duration = 7000
                })
                return false
            end

            doSomethingIfPedIsInsideVehicle(activePed.entity)
            return attackLogic(alreadyHunting)
        end
    },
    {
        label = Lang:t('menu.action_menu.hunt_and_grab'),
        TYPE = 'HuntandGrab',
        icon = 'hand-fist',
        iconColor = '#e8590c',
        description = 'Hunt and bring the prey to you',
        show = function(activePed)
            if not activePed.canHunt then return false end
            local hash = activePed.item.metadata.hash
            if IsLeashed(hash) or IsGuarding(hash) then return false end
            return (activePed.item.metadata.level or 0) >= Config.progression.minHuntLevel
        end,
        action = function(plyped, activePed)
            local minLevel = Config.progression.minHuntLevel
            if not activePed.canHunt then
                lib.notify({ description = Lang:t('menu.action_menu.error.pet_unable_to_hunt'), type = 'error', duration = 7000 })
                return false
            end

            if activePed.item.metadata.level < minLevel then
                lib.notify({
                    description = string.format(Lang:t('menu.action_menu.error.not_meet_min_requirement_to_hunt'), minLevel),
                    type = 'error', duration = 7000
                })
                return false
            end

            doSomethingIfPedIsInsideVehicle(activePed.entity)
            HuntandGrab(plyped, activePed)
            return true
        end
    },
    {
        label = Lang:t('menu.action_menu.go_there'),
        TYPE = 'There',
        icon = 'location-arrow',
        iconColor = '#12b886',
        description = 'Point where your pet should go',
        show = function(activePed)
            local hash = activePed.item.metadata.hash
            return not IsLeashed(hash) and not IsGuarding(hash)
        end,
        action = function(_, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            goThere(activePed.entity)
        end
    },
    {
        label = Lang:t('menu.action_menu.wait'),
        TYPE = 'Wait',
        icon = 'hand',
        iconColor = '#12b886',
        description = 'Stay at current position',
        action = function(_, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            ClearPedTasks(activePed.entity)
        end
    },
    {
        label = Lang:t('menu.action_menu.guard'),
        TYPE = 'Guard',
        icon = 'shield-halved',
        iconColor = '#e03131',
        description = 'Guard the current position',
        triggerNotification = { 'PETNAME is now guarding!', 'PETNAME cannot guard here!' },
        show = function(activePed)
            if not Config.guard or not Config.guard.enabled then return false end
            if IsLeashed(activePed.item.metadata.hash) then return false end
            if IsGuarding(activePed.item.metadata.hash) then return false end
            local species = activePed.petConfig and activePed.petConfig.species
            if not species then return false end
            for _, s in ipairs(Config.guard.speciesAllowed) do
                if species == s then
                    return (activePed.item.metadata.level or 0) >= Config.progression.minGuardLevel
                end
            end
            return false
        end,
        action = function(_, activePed)
            if IsLeashed(activePed.item.metadata.hash) then
                lib.notify({ description = Lang:t('menu.action_menu.error.cannot_guard_leashed'), type = 'error', duration = 5000 })
                return false
            end
            StartGuard(activePed)
            return true
        end,
    },
    {
        label = Lang:t('menu.action_menu.recall_guard'),
        TYPE = 'RecallGuard',
        icon = 'arrow-rotate-left',
        iconColor = '#e03131',
        description = 'Stop guarding and return',
        triggerNotification = { 'PETNAME stopped guarding!', 'PETNAME is not guarding!' },
        show = function(activePed)
            return IsGuarding(activePed.item.metadata.hash)
        end,
        action = function(_, activePed)
            StopGuard(activePed.item.metadata.hash)
            return true
        end,
    },
    {
        label = Lang:t('menu.action_menu.get_in_car'),
        TYPE = 'GetinCar',
        icon = 'car-side',
        iconColor = '#12b886',
        description = 'Hop into the nearest vehicle',
        action = function()
            getIntoCar()
        end
    },
    {
        label = Lang:t('menu.action_menu.specialize'),
        TYPE = 'Specialize',
        icon = 'star',
        iconColor = '#fab005',
        description = 'Choose a specialization path',
        show = function(activePed)
            if not Config.specializations then return false end
            if activePed.item.metadata.specialization then return false end
            return (activePed.item.metadata.level or 0) >= Config.progression.minSpecializationLevel
        end,
        action = function(_, activePed)
            openSpecializationMenu(activePed)
            return true
        end,
    },
    {
        label = Lang:t('menu.action_menu.track'),
        TYPE = 'Track',
        icon = 'location-crosshairs',
        iconColor = '#228be6',
        description = 'Detect nearby peds and animals',
        triggerNotification = { 'PETNAME is scanning the area!', 'PETNAME cannot track!' },
        show = function(activePed)
            return activePed.item.metadata.specialization == 'tracker'
        end,
        action = function(_, activePed)
            TrackerScan(activePed)
            return true
        end,
    },
    {
        label = 'Search Person',
        TYPE = 'SearchPerson',
        icon = 'magnifying-glass',
        iconColor = '#228be6',
        description = 'K9 sniff search on nearest person',
        show = function(activePed)
            if not isK9Job() then return false end
            if not activePed.petConfig or not activePed.petConfig.isK9 then return false end
            return (activePed.item.metadata.level or 0) >= Config.progression.minK9Level
        end,
        action = function(plyped, activePed)
            SearchLogic(plyped, activePed)
        end
    },
    {
        label = 'Search Car',
        TYPE = 'SearchCar',
        icon = 'car',
        iconColor = '#228be6',
        description = 'K9 sniff search on nearest vehicle',
        show = function(activePed)
            if not isK9Job() then return false end
            if not activePed.petConfig or not activePed.petConfig.isK9 then return false end
            return (activePed.item.metadata.level or 0) >= Config.progression.minK9Level
        end,
        action = function(_, activePed)
            local vehicle = getClosestVehicle()
            k9SearchVehicle(vehicle, activePed)
        end
    },
    {
        label = 'Sit',
        TYPE = 'Sit',
        icon = 'couch',
        iconColor = '#9c36b5',
        description = 'Tell your pet to sit down',
        show = function(activePed)
            return Anims.hasAction(activePed.animClass, 'sit')
        end,
        action = function(_, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            Anims.play(activePed.entity, activePed.animClass, 'sit')
        end,
    },
    {
        label = 'Lay Down',
        TYPE = 'LayDown',
        icon = 'bed',
        iconColor = '#9c36b5',
        description = 'Tell your pet to lay down and rest',
        show = function(activePed)
            return Anims.hasAction(activePed.animClass, 'sleep')
        end,
        action = function(_, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            Anims.play(activePed.entity, activePed.animClass, 'sleep')
        end,
    },
    {
        label = 'Speak',
        TYPE = 'Speak',
        icon = 'volume-high',
        iconColor = '#9c36b5',
        description = 'Make some noise!',
        show = function(activePed)
            return Anims.hasAction(activePed.animClass, 'bark')
        end,
        action = function(_, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            SetAnimalMood(activePed.entity, 1)
            PlayAnimalVocalization(activePed.entity, 3, 'bark')
            Anims.play(activePed.entity, activePed.animClass, 'bark')
        end,
    },
    {
        label = 'Toggle Leash',
        TYPE = 'ToggleLeash',
        icon = 'link',
        iconColor = '#228be6',
        description = 'Attach or remove a leash',
        show = function(activePed)
            if not Config.leash or not Config.leash.enabled then return false end
            local species = activePed.petConfig and activePed.petConfig.species
            if not species then return false end
            for _, s in ipairs(Config.leash.speciesAllowed) do
                if species == s then
                    -- Already leashed = always show (to allow removal)
                    if IsLeashed(activePed.item.metadata.hash) then return true end
                    -- Otherwise require leash item in inventory
                    local count = exports.ox_inventory:Search('count', Config.items.leash.name)
                    return count and count > 0
                end
            end
            return false
        end,
        action = function(_, activePed)
            if not IsLeashed(activePed.item.metadata.hash) then
                local count = exports.ox_inventory:Search('count', Config.items.leash.name)
                if not count or count < 1 then
                    lib.notify({ description = 'You need a leash!', type = 'error', duration = 5000 })
                    return false
                end
            end
            ToggleLeash(activePed)
            return true
        end,
    },
    {
        label = 'Pet',
        TYPE = 'PetCaress',
        icon = 'heart',
        iconColor = '#e64980',
        description = 'Show your companion some love',
        show = function(activePed)
            return activePed.petConfig and activePed.petConfig.canPet
        end,
        action = function(plyped, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            local pet = activePed.entity
            makeEntityFaceEntity(pet, plyped)
            makeEntityFaceEntity(plyped, pet)

            local dist = #(GetEntityCoords(plyped) - GetEntityCoords(pet))
            if dist > 2.0 then
                TaskGoToEntity(plyped, pet, -1, 1.0, 2.0, 0, 0)
                Wait(2000)
            end

            Anims.playSub(pet, activePed.animClass, 'petting', 'pet_anim')
            Anims.playSub(plyped, activePed.animClass, 'petting', 'human_anim')
            Wait(5000)
            ClearPedTasks(plyped)

            -- Award petting XP
            TriggerServerEvent('murderface-pets:server:updatePetStats',
                activePed.item.metadata.hash, { key = 'activity', action = 'petting' })

            if Config.stressRelief.enabled then
                local amount = math.random(Config.stressRelief.amount.min, Config.stressRelief.amount.max)
                -- Companion specialization: bonus stress relief
                if activePed.item.metadata.specialization == 'companion' then
                    local specCfg = Config.specializations and Config.specializations.companion
                    if specCfg and specCfg.stressReliefMult then
                        amount = math.floor(amount * specCfg.stressReliefMult)
                    end
                end
                TriggerServerEvent(Config.stressRelief.event, amount)
            end
            return true
        end,
    },
}

-- =======================================
--          Tricks Menu Items
-- =======================================

local function buildTrickItems(activePed)
    local trickNames = Anims.getTrickNames(activePed.animClass)
    local items = {}
    local petLevel = activePed.item.metadata.level or 0
    local trickIcons = {
        beg       = { icon = 'hands-praying', desc = 'Stand up and beg for treats' },
        paw       = { icon = 'paw',           desc = 'Offer a friendly paw shake' },
        play_dead = { icon = 'face-dizzy',     desc = 'Dramatic death performance!' },
    }

    for _, name in ipairs(trickNames) do
        local info = trickIcons[name] or { icon = 'wand-magic-sparkles', desc = name }
        local reqLevel = Config.trickLevels[name] or 0
        local locked = petLevel < reqLevel

        items[#items + 1] = {
            label = name:gsub('_', ' '):gsub('^%l', string.upper),
            icon = info.icon,
            iconColor = locked and '#868e96' or '#9c36b5',
            description = locked and string.format('Unlocks at level %d', reqLevel) or info.desc,
            disabled = locked,
            action = function(_, ped)
                Anims.playSub(ped.entity, ped.animClass, 'tricks', name)
                -- Award trick XP
                TriggerServerEvent('murderface-pets:server:updatePetStats',
                    ped.item.metadata.hash, { key = 'activity', action = 'trick' })
            end,
        }
    end
    return items
end

-- =======================================
--       Forward declarations
-- =======================================

local openMenu_variation_list

-- =======================================
--       ox_lib Context Menu Functions
-- =======================================

-- =======================================
--     Specialization Picker Menu
-- =======================================

function openSpecializationMenu(activePed)
    local options = {}
    for specKey, spec in pairs(Config.specializations) do
        options[#options + 1] = {
            title = spec.label,
            description = spec.description,
            icon = spec.icon,
            iconColor = spec.iconColor,
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Choose ' .. spec.label .. '?',
                    content = spec.description .. '\n\nThis choice is **permanent** and cannot be changed!',
                    centered = true,
                    cancel = true,
                })
                if confirm ~= 'confirm' then return end

                local success, result = lib.callback.await(
                    'murderface-pets:server:chooseSpecialization', false,
                    activePed.item.metadata.hash, specKey)
                if success then
                    activePed.item.metadata.specialization = result
                    lib.notify({
                        title = 'Specialization Chosen!',
                        description = (activePed.item.metadata.name or 'Pet') .. ' is now a ' .. spec.label .. '!',
                        type = 'success',
                        duration = 10000,
                    })
                else
                    lib.notify({ description = result or 'Failed', type = 'error', duration = 5000 })
                end
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_specialization',
        title = 'Choose Specialization',
        menu = 'mfpets_actions',
        options = options,
    })
    lib.showContext('mfpets_specialization')
end

local function registerTricksMenu(pet)
    local trickItems = buildTrickItems(pet)
    if #trickItems == 0 then return end

    local options = {}
    for _, value in ipairs(trickItems) do
        options[#options + 1] = {
            title = value.label,
            description = value.description,
            icon = value.icon,
            iconColor = value.iconColor,
            disabled = value.disabled,
            onSelect = value.disabled and nil or function()
                local activePed = ActivePed:read()
                if not activePed then return end
                activePed.entity = NetworkGetEntityFromNetworkId(activePed.netId)
                value.action(PlayerPedId(), activePed)
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_tricks',
        title = string.format(Lang:t('menu.tricks.header'), pet.item.metadata.name),
        menu = 'mfpets_actions',
        options = options,
    })
end

local function registerActionMenu()
    local pet = ActivePed:read()
    if not pet then return end
    local name = pet.item.metadata.name

    local options = {}

    for _, value in ipairs(menu) do
        if not value.show or value.show(pet) then
            options[#options + 1] = {
                title = value.label,
                description = value.description,
                icon = value.icon,
                iconColor = value.iconColor,
                onSelect = function()
                    local plyped = PlayerPedId()
                    local activePed = ActivePed:read()
                    if not activePed then return end
                    activePed.entity = NetworkGetEntityFromNetworkId(activePed.netId)
                    local result = value.action(plyped, activePed)
                    if result == true then
                        if value.triggerNotification then
                            local msg = value.triggerNotification[1]:gsub('PETNAME', activePed.item.metadata.name)
                            lib.notify({ description = msg, type = 'success', duration = 7000 })
                        end
                    else
                        if value.triggerNotification then
                            local msg = value.triggerNotification[2]:gsub('PETNAME', activePed.item.metadata.name)
                            lib.notify({ description = msg, type = 'error', duration = 7000 })
                        end
                    end
                end,
            }
        end
    end

    -- Add Tricks sub-menu entry (only for pets with trick animations)
    if pet.petConfig and pet.petConfig.canTrick and Anims.hasAction(pet.animClass, 'tricks') then
        options[#options + 1] = {
            title = Lang:t('menu.action_menu.tricks'),
            description = 'Teach your pet some tricks',
            icon = 'wand-magic-sparkles',
            iconColor = '#9c36b5',
            menu = 'mfpets_tricks',
        }
        registerTricksMenu(pet)
    end

    lib.registerContext({
        id = 'mfpets_actions',
        title = string.format(Lang:t('menu.action_menu.header'), name),
        menu = 'mfpets_main',
        options = options,
    })
end

local function registerSwitchMenu()
    local options = {}
    for _, value in pairs(ActivePed:petsList()) do
        local petCfg = value.petConfig
        local displayLabel = petCfg and petCfg.label or value.model:gsub('A_C_', ''):gsub('_', ' ')
        local icon = petCfg and petCfg.icon or 'paw'

        options[#options + 1] = {
            title = value.name,
            description = string.format('Lvl %d  |  %s', value.level or 0, displayLabel),
            icon = icon,
            iconColor = '#12b886',
            metadata = {
                { label = 'Health', value = string.format('%d / %d', value.health or 0, value.maxHealth or 0) },
                { label = 'Level', value = tostring(value.level or 0) },
            },
            onSelect = function()
                ActivePed:switchControl(value.hash)
                openMainMenu()
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_switch',
        title = Lang:t('menu.main_menu.switchcontrol_header'),
        menu = 'mfpets_main',
        options = options,
    })
end

function openMainMenu()
    local pet = ActivePed:read()
    if not pet then return end

    local name = pet.item.metadata.name

    registerActionMenu()
    registerSwitchMenu()

    local petCount = #ActivePed:petsList()
    lib.registerContext({
        id = 'mfpets_main',
        title = string.format(Lang:t('menu.main_menu.header'), name),
        options = {
            {
                title = Lang:t('menu.main_menu.btn_actions'),
                description = 'Command your companion',
                icon = 'circle-play',
                iconColor = '#12b886',
                menu = 'mfpets_actions',
            },
            {
                title = Lang:t('menu.main_menu.btn_switchcontrol'),
                description = string.format('%d active companion%s', petCount, petCount == 1 and '' or 's'),
                icon = 'repeat',
                iconColor = '#868e96',
                menu = 'mfpets_switch',
            },
        }
    })

    lib.showContext('mfpets_main')
end

-- =======================================
--           Customization Menus
-- =======================================

function openMenu_customization(data)
    local c_name = data.item.metadata.name
    local c_variation = data.item.metadata.variation

    lib.registerContext({
        id = 'mfpets_customize',
        title = Lang:t('menu.customization_menu.header'),
        options = {
            {
                title = Lang:t('menu.customization_menu.btn_rename'),
                description = Lang:t('menu.customization_menu.btn_txt_btn_rename') .. c_name,
                icon = 'pen-to-square',
                iconColor = '#e64980',
                disabled = data.pet_information.disable.rename,
                onSelect = function()
                    openMenu_customization_rename(data)
                end,
            },
            {
                title = Lang:t('menu.customization_menu.btn_select_variation'),
                description = Lang:t('menu.customization_menu.btn_txt_select_variation') .. tostring(c_variation),
                icon = 'palette',
                iconColor = '#e64980',
                onSelect = function()
                    openMenu_customization_select_variation(data)
                end,
            },
            {
                title = Lang:t('menu.general_menu_items.confirm'),
                icon = 'circle-check',
                iconColor = '#2f9e44',
                onSelect = function()
                    TriggerServerEvent('murderface-pets:server:applyCustomization', data.item, data.pet_information.type)
                end,
            },
        }
    })
    lib.showContext('mfpets_customize')
end

function openMenu_customization_rename(data)
    local c_name = data.item.metadata.name

    lib.registerContext({
        id = 'mfpets_customize_rename',
        title = Lang:t('menu.rename_menu.header'),
        menu = 'mfpets_customize',
        options = {
            {
                title = c_name,
                icon = 'tag',
                iconColor = '#868e96',
                disabled = true,
            },
            {
                title = Lang:t('menu.rename_menu.btn_rename'),
                description = 'Max 12 characters, single word',
                icon = 'keyboard',
                iconColor = '#e64980',
                onSelect = function()
                    local input = lib.inputDialog(Lang:t('menu.customization_menu.rename.inputs.header'), {
                        { type = 'input', label = 'Name', required = true, min = 1, max = 12 },
                    })
                    if not input then
                        openMenu_customization_rename(data)
                        return
                    end

                    local newName = input[1]
                    if not newName or type(newName) ~= 'string' then
                        openMenu_customization_rename(data)
                        return
                    end

                    local validation = ValidatePetName(newName, 12)
                    if validation ~= true then
                        if validation.reason == 'blocked_word' then
                            lib.notify({ description = Lang:t('error.badword_inside_pet_name'), type = 'error', duration = 7000 })
                        elseif validation.reason == 'multiple_words' then
                            lib.notify({ description = Lang:t('error.more_than_one_word_as_name'), type = 'error', duration = 7000 })
                        else
                            lib.notify({ description = Lang:t('error.failed_to_validate_name'), type = 'error', duration = 7000 })
                        end
                        openMenu_customization_rename(data)
                        return
                    end

                    data.item.metadata.name = newName
                    openMenu_customization_rename(data)
                end,
            },
        }
    })
    lib.showContext('mfpets_customize_rename')
end

function openMenu_customization_select_variation(data)
    lib.registerContext({
        id = 'mfpets_customize_variation',
        title = Lang:t('menu.variation_menu.header'),
        menu = 'mfpets_customize',
        options = {
            {
                title = tostring(data.item.metadata.variation),
                icon = 'droplet',
                iconColor = '#868e96',
                disabled = true,
            },
            {
                title = Lang:t('menu.variation_menu.btn_select_variation'),
                description = Lang:t('menu.variation_menu.btn_txt_select_variation'),
                icon = 'palette',
                iconColor = '#e64980',
                onSelect = function()
                    openMenu_variation_list(data)
                end,
            },
        }
    })
    lib.showContext('mfpets_customize_variation')
end

openMenu_variation_list = function(data)
    local options = {}
    for _, value in pairs(data.pet_information.pet_variation_list) do
        options[#options + 1] = {
            title = Lang:t('menu.variation_menu.selection_menu.btn_variation_items') .. value,
            description = Lang:t('menu.variation_menu.selection_menu.btn_desc'),
            icon = 'droplet',
            iconColor = '#e64980',
            onSelect = function()
                data.item.metadata.variation = value
                openMenu_customization_select_variation(data)
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_customize_variation_list',
        title = Lang:t('menu.variation_menu.selection_menu.header'),
        menu = 'mfpets_customize_variation',
        options = options,
    })
    lib.showContext('mfpets_customize_variation_list')
end

-- =======================================
--             Keybind
-- =======================================

lib.addKeybind({
    name = 'mfpets_menu',
    description = 'Open pet companion menu',
    defaultKey = Config.petMenuKeybind,
    onPressed = function()
        local metadata = QBX.PlayerData.metadata
        local job = QBX.PlayerData.job

        if not metadata or not job then return end

        local isDowned = metadata.isdead or metadata.inlaststand
        local isHandcuffed = metadata.ishandcuffed
        local isPoliceOrEMS = (job.name == 'police' or job.name == 'ambulance')

        if ((isDowned and isPoliceOrEMS) or not isDowned) and not isHandcuffed and not IsPauseMenuActive() then
            if not ActivePed:read() then
                lib.notify({ description = Lang:t('error.no_pet_under_control'), type = 'error', duration = 7000 })
                return
            end
            openMainMenu()
        end
    end,
})

-- =======================================
--              Pet Shop
-- =======================================

local function openPetShopMenu()
    local options = {}
    for _, pet in ipairs(Config.pets) do
        options[#options + 1] = {
            title = pet.label,
            description = string.format('$%s', lib.math.groupdigits(pet.price)),
            icon = pet.icon or 'paw',
            iconColor = '#2f9e44',
            metadata = {
                { label = 'Type', value = pet.species:gsub('^%l', string.upper) },
                { label = 'Max Health', value = tostring(pet.maxHealth) },
                { label = 'Can Hunt', value = pet.canHunt and 'Yes' or 'No' },
            },
            onSelect = function()
                local success = lib.callback.await('murderface-pets:server:buyPet', false, pet.item)
                if success then
                    lib.notify({ description = 'Purchased a new companion!', type = 'success', duration = 7000 })
                else
                    lib.notify({ description = 'Not enough money!', type = 'error', duration = 7000 })
                end
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_shop',
        title = Config.petShop.blip.text or 'Pet Shop',
        options = options,
    })
    lib.showContext('mfpets_shop')
end

CreateThread(function()
    if not Config.petShop.enabled then return end
    local shop = Config.petShop

    -- Create map blip
    local blip = AddBlipForCoord(shop.ped.coords.x, shop.ped.coords.y, shop.ped.coords.z)
    SetBlipSprite(blip, shop.blip.sprite)
    SetBlipColour(blip, shop.blip.colour)
    SetBlipAsShortRange(blip, shop.blip.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(shop.blip.text)
    EndTextCommandSetBlipName(blip)

    -- Spawn shop ped
    local model = joaat(shop.ped.model)
    lib.requestModel(model)
    local ped = CreatePed(0, model, shop.ped.coords.x, shop.ped.coords.y, shop.ped.coords.z - 1.0, shop.ped.coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mfpets_shop_browse',
            icon = 'fas fa-paw',
            label = 'Browse Pets',
            onSelect = function()
                openPetShopMenu()
            end,
            distance = 2.5,
        },
    })
end)

-- =======================================
--           Pet Supplies Shop
-- =======================================

local function openSuppliesShopMenu()
    local options = {}
    for _, supply in ipairs(Config.suppliesShop.items) do
        local info = supplyIcons[supply.name] or { icon = 'box', iconColor = '#2f9e44', desc = '' }
        options[#options + 1] = {
            title = supply.label,
            description = string.format('$%s ea. — %s', lib.math.groupdigits(supply.price), info.desc),
            icon = info.icon,
            iconColor = info.iconColor,
            onSelect = function()
                local input = lib.inputDialog('Purchase ' .. supply.label, {
                    { type = 'slider', label = 'Quantity', default = 1, min = 1, max = 10, step = 1 },
                })
                if not input then return end

                local qty = input[1]
                if not qty or qty < 1 then return end

                local totalPrice = supply.price * qty
                local success = lib.callback.await('murderface-pets:server:buySupply', false, supply.name, supply.price, qty)
                if success then
                    lib.notify({
                        description = string.format('Purchased %dx %s for $%s!', qty, supply.label, lib.math.groupdigits(totalPrice)),
                        type = 'success',
                        duration = 7000,
                    })
                else
                    lib.notify({ description = 'Not enough money!', type = 'error', duration = 7000 })
                end
            end,
        }
    end

    lib.registerContext({
        id = 'mfpets_supplies',
        title = 'Pet Supplies',
        options = options,
    })
    lib.showContext('mfpets_supplies')
end

CreateThread(function()
    if not Config.suppliesShop or not Config.suppliesShop.enabled then return end
    local shop = Config.suppliesShop

    local model = joaat(shop.ped.model)
    lib.requestModel(model)
    local ped = CreatePed(0, model, shop.ped.coords.x, shop.ped.coords.y, shop.ped.coords.z - 1.0, shop.ped.coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'mfpets_supplies_browse',
            icon = 'fas fa-box',
            label = 'Pet Supplies',
            onSelect = function()
                openSuppliesShopMenu()
            end,
            distance = 2.5,
        },
    })
end)
