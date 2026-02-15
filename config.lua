Config = {}

-- ========================================
--  General Settings
-- ========================================
Config.debug = false

Config.maxActivePets = 2          -- max pets a player can have spawned at once
Config.dataUpdateInterval = 10    -- seconds between server XP/food/thirst ticks
Config.itemCooldown = 1           -- seconds between consecutive item uses
Config.callDuration = 2           -- seconds for whistle/spawn progress bar
Config.despawnDuration = 3        -- seconds for despawn progress bar
Config.customizeAfterPurchase = true -- open customization menu after buying a pet

Config.petMenuKeybind = 'o'       -- key to open pet companion menu

Config.chaseDistance = 50.0       -- max distance pet will chase a target
Config.chaseIndicator = true      -- show indicator when pet is chasing

Config.blip = {
    enabled = true,
    sprite = 442,
    colour = 2,
    shortRange = false,
}

Config.nameTag = {
    enabled = true,
    distance = 15.0,          -- max draw distance
    scale = 0.35,
    showLevel = true,          -- show level title under name
}

Config.petEmotes = {
    happy = { mood = 1, vocalization = 'bark',  anim = 'bark' },
    angry = { mood = 0, vocalization = 'growl', anim = 'bark' },
    sad   = { mood = 3, vocalization = 'whine' },
    bark  = { mood = 1, vocalization = 'bark',  anim = 'bark' },
    sit   = { anim = 'sit' },
    sleep = { anim = 'sleep' },
}

Config.leash = {
    enabled = true,
    length = 3.0,              -- rope length in meters
    ropeType = 5,              -- 5 = RopeReins (thin leash look)
    playerBone = 18905,        -- SKEL_L_Hand
    petBone = 39317,           -- SKEL_Neck_1
    enforceDistance = true,     -- script-side distance cap (rope is visual only)
    speciesAllowed = { 'dog' },
}

Config.guard = {
    enabled = true,
    radius = 10.0,              -- default guard radius in meters
    checkInterval = 500,        -- ms between enforcement checks
    attackPlayers = false,      -- true = attack player peds too, false = NPCs only
    speciesAllowed = { 'dog', 'wild' },
    notifyOwner = true,
    combatAbility = 100,
    combatRange = 2,            -- 0=near, 1=medium, 2=far
    combatMovement = 3,         -- 0=stationary, 1=defensive, 2=offensive, 3=suicidal
}

Config.stressRelief = {
    enabled = true,              -- set true if you have a HUD with stress mechanics
    event = 'hud:server:RelieveStress',
    amount = { min = 12, max = 24 },
}

-- ========================================
--  Stray / Wild Animal Taming
-- ========================================
Config.strays = {
    enabled = true,
    trustThreshold = 100,         -- total trust needed to tame
    trustPerFeed = 20,            -- trust gained per feed
    feedCooldown = 300,           -- seconds between feeds (per player per stray)
    feedItem = 'murderface_food', -- item consumed when feeding
    feedRadius = 3.0,             -- max interaction distance
    respawnTime = 3600,           -- seconds before stray reappears after being tamed

    spawnPoints = {
        {
            id = 'stray_sandy_1',
            coords = vector4(1690.0, 4785.0, 41.9, 180.0),
            model = 'A_C_shepherd',
            item = 'murderface_shepherd',
            label = 'Stray German Shepherd',
            spawnChance = 0.6,
            rareCoat = 'white',
        },
        {
            id = 'stray_paleto_1',
            coords = vector4(-292.0, 6237.0, 31.5, 90.0),
            model = 'A_C_Husky',
            item = 'murderface_husky',
            label = 'Stray Husky',
            spawnChance = 0.4,
            rareCoat = nil,
        },
        {
            id = 'stray_city_1',
            coords = vector4(200.0, -1660.0, 29.3, 0.0),
            model = 'A_C_Rottweiler',
            item = 'murderface_rottweiler',
            label = 'Stray Rottweiler',
            spawnChance = 0.3,
            rareCoat = 'darkBrown',
        },
    },
}

-- ========================================
--  Breeding / Dog House
-- ========================================
Config.breeding = {
    enabled = true,
    propModel = 'prop_doghouse_01',       -- GTA V native dog house prop
    minBreedLevel = 10,                   -- both parents must be at least this level
    breedingCooldownHours = 24,           -- hours before a pet can breed again (real time)
    maxDoghousesPerPlayer = 1,            -- only one placed at a time
    restBonusRadius = 15.0,               -- meters; pets within this get rest bonus
    placementMaxDistance = 50.0,          -- max raycast distance during placement

    restBonus = {
        foodDrainMult = 0.5,              -- 50% less food drain
        thirstIncreaseMult = 0.5,         -- 50% less thirst increase
        healthRegenBonus = 1.0,           -- bonus HP regen per tick
    },

    offspring = {
        inheritSpecialization = false,    -- offspring starts with no specialization
        startLevel = 0,
    },

    speciesAllowed = { 'dog' },           -- only dogs can breed (need a dog house)
}

-- ========================================
--  Balance / Progression
-- ========================================
Config.balance = {
    maxLevel = 50,

    afk = {
        resetAfter = 120,         -- seconds before AFK timer resets
        wanderInterval = 60,      -- seconds before idle pet starts wandering
        animInterval = 90,        -- seconds before idle pet plays random anim
    },

    food = {
        feedAmount = 50,          -- hunger restored per food item
        decreasePerTick = 1,      -- hunger lost per server tick
        healthDrainWhenStarving = 0.2, -- HP lost per tick at 0 food
    },

    thirst = {
        increasePerTick = 0.1,    -- thirst gained per server tick
        reductionPerDrink = 25,   -- thirst reduced per drink action
        healthDrainWhenDehydrated = 0.5, -- HP lost per tick at 100 thirst
    },
}

-- ========================================
--  XP Awards (per action)
-- ========================================
Config.xp = {
    passive    = 10,   -- base XP per passive tick (scales down with level)
    huntKill   = 50,
    petting    = 15,
    trick      = 10,
    feeding    = 20,
    watering   = 15,
    k9Search   = 40,
    healing    = 10,
    guarding   = 5,
    tracking   = 30,
}

-- Seconds between XP awards for the same activity (prevents spam)
Config.activityCooldowns = {
    huntKill = 30,
    petting  = 60,
    trick    = 15,
    k9Search = 30,
    guarding = 60,
    tracking = 30,
}

-- ========================================
--  Progression / Level-Gated Unlocks
-- ========================================
Config.progression = {
    minHuntLevel      = 5,
    minK9Level        = 10,
    healthRegenLevel  = 25,
    healthRegenAmount = 0.5,  -- HP per save tick when level qualifies
    followSpeed = {
        { minLevel = 0,  speed = 3.0 },
        { minLevel = 15, speed = 4.0 },
        { minLevel = 30, speed = 5.0 },
    },
    minGuardLevel          = 10,
    minSpecializationLevel = 20,
    milestones = { 10, 25, 50 },
}

Config.trickLevels = {
    sit       = 0,
    beg       = 5,
    paw       = 10,
    play_dead = 20,
}

Config.levelTitles = {
    { maxLevel = 5,  title = 'Puppy' },
    { maxLevel = 15, title = 'Trained' },
    { maxLevel = 30, title = 'Veteran' },
    { maxLevel = 49, title = 'Elite' },
    { maxLevel = 50, title = 'Legendary' },
}

-- ========================================
--  Specializations
--  Unlocked at Config.progression.minSpecializationLevel.
--  Each path modifies existing systems via multipliers.
-- ========================================
Config.specializations = {
    guardian = {
        label = 'Guardian',
        icon = 'shield-halved',
        iconColor = '#e03131',
        description = 'Larger guard radius, enhanced combat ability.',
        guardRadiusMult = 1.5,       -- 50% larger guard radius
        combatAbilityBonus = 50,     -- added to base combat ability
    },
    tracker = {
        label = 'Tracker',
        icon = 'location-crosshairs',
        iconColor = '#228be6',
        description = 'Detect and highlight nearby peds and animals.',
        trackRadius = 50.0,          -- detection range in meters
        markerDuration = 10000,      -- ms markers stay visible
    },
    companion = {
        label = 'Companion',
        icon = 'heart',
        iconColor = '#e64980',
        description = 'Better stress relief, faster regen, bonus XP.',
        stressReliefMult = 2.0,      -- 2x stress relief
        healthRegenMult = 2.0,       -- 2x health regen rate
        xpBonusMult = 1.25,          -- 25% bonus passive XP
    },
}

-- ========================================
--  Shared Helpers (available on client + server)
-- ========================================

--- XP threshold for a given level (quadratic curve)
---@param level number
---@return number
function Config.xpForLevel(level)
    if level <= 0 then return 0 end
    return 75 + (level * level * 15)
end

--- Lookup level title from Config.levelTitles
---@param level number
---@return string
function Config.getLevelTitle(level)
    for _, t in ipairs(Config.levelTitles) do
        if level <= t.maxLevel then return t.title end
    end
    return 'Legendary'
end

--- Get follow speed for a given pet level
---@param level number
---@return number speed
function Config.getFollowSpeed(level)
    local speed = Config.progression.followSpeed[1].speed
    for _, tier in ipairs(Config.progression.followSpeed) do
        if level >= tier.minLevel then
            speed = tier.speed
        end
    end
    return speed
end

-- ========================================
--  Pets
--  Each entry defines a pet with structured traits.
--  animClass maps to the animation system (shared/animations.lua)
--  Boolean fields control per-pet feature availability.
-- ========================================

Config.pets = {
    -- ===== Large Dogs =====
    {
        model    = 'A_C_Husky',
        item     = 'murderface_husky',
        label    = 'Husky',
        maxHealth = 350,
        price    = 12000,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
    },
    {
        model    = 'A_C_shepherd',
        item     = 'murderface_shepherd',
        label    = 'German Shepherd',
        maxHealth = 250,
        price    = 8000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
    },
    {
        model    = 'A_C_Rottweiler',
        item     = 'murderface_rottweiler',
        label    = 'Rottweiler',
        maxHealth = 300,
        price    = 10000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
    },
    {
        model    = 'A_C_Retriever',
        item     = 'murderface_retriever',
        label    = 'Golden Retriever',
        maxHealth = 300,
        price    = 7500,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
    },
    {
        model    = 'a_c_chop_02',
        item     = 'murderface_chop',
        label    = 'Chop',
        maxHealth = 300,
        price    = 15000,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
    },

    -- ===== Small Dogs =====
    {
        model    = 'A_C_Westy',
        item     = 'murderface_westy',
        label    = 'Westie',
        maxHealth = 150,
        price    = 2500,
        canHunt  = false,
        isK9     = false,
        animClass = 'small_dog',
        size     = 'small',
        species  = 'dog',
        canPet   = false,
        canTrick = false,
        icon     = 'dog',
    },
    {
        model    = 'A_C_Pug',
        item     = 'murderface_pug',
        label    = 'Pug',
        maxHealth = 150,
        price    = 3000,
        canHunt  = false,
        isK9     = false,
        animClass = 'small_dog',
        size     = 'small',
        species  = 'dog',
        canPet   = false,
        canTrick = false,
        icon     = 'dog',
    },
    {
        model    = 'A_C_Poodle',
        item     = 'murderface_poodle',
        label    = 'Poodle',
        maxHealth = 150,
        price    = 4000,
        canHunt  = false,
        isK9     = false,
        animClass = 'small_dog',
        size     = 'small',
        species  = 'dog',
        canPet   = false,
        canTrick = false,
        icon     = 'dog',
    },

    -- ===== Cats =====
    {
        model    = 'A_C_Cat_01',
        item     = 'murderface_cat',
        label    = 'House Cat',
        maxHealth = 150,
        price    = 2000,
        canHunt  = false,
        isK9     = false,
        animClass = 'cat',
        size     = 'small',
        species  = 'cat',
        canPet   = false,
        canTrick = false,
        icon     = 'cat',
    },

    -- ===== Big Cats / Wild =====
    {
        model    = 'A_C_Panther',
        item     = 'murderface_panther',
        label    = 'Black Panther',
        maxHealth = 350,
        price    = 50000,
        canHunt  = true,
        isK9     = false,
        animClass = 'cougar',
        size     = 'large',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'cat',
    },
    {
        model    = 'A_C_MtLion',
        item     = 'murderface_mtlion',
        label    = 'Mountain Lion',
        maxHealth = 350,
        price    = 40000,
        canHunt  = true,
        isK9     = false,
        animClass = 'cougar',
        size     = 'large',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'cat',
    },
    {
        model    = 'A_C_Coyote',
        item     = 'murderface_coyote',
        label    = 'Coyote',
        maxHealth = 350,
        price    = 15000,
        canHunt  = false,
        isK9     = false,
        animClass = 'cougar',
        size     = 'medium',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'paw',
    },

    -- ===== Small Animals =====
    {
        model    = 'A_C_Hen',
        item     = 'murderface_hen',
        label    = 'Chicken',
        maxHealth = 200,
        price    = 500,
        canHunt  = false,
        isK9     = false,
        animClass = nil,
        size     = 'small',
        species  = 'bird',
        canPet   = false,
        canTrick = false,
        icon     = 'kiwi-bird',
    },
    {
        model    = 'A_C_Rabbit_01',
        item     = 'murderface_rabbit',
        label    = 'Rabbit',
        maxHealth = 200,
        price    = 1000,
        canHunt  = false,
        isK9     = false,
        animClass = nil,
        size     = 'small',
        species  = 'small',
        canPet   = false,
        canTrick = false,
        icon     = 'paw',
    },

    -- ===== Primates =====
    {
        model    = 'a_c_chimp_02',
        item     = 'murderface_chimp',
        label    = 'Chimpanzee',
        maxHealth = 250,
        price    = 75000,
        canHunt  = false,
        isK9     = false,
        animClass = 'primate',
        size     = 'medium',
        species  = 'primate',
        canPet   = false,
        canTrick = false,
        icon     = 'paw',
    },
    {
        model    = 'a_c_rhesus',
        item     = 'murderface_rhesus',
        label    = 'Rhesus Monkey',
        maxHealth = 150,
        price    = 35000,
        canHunt  = false,
        isK9     = false,
        animClass = 'primate',
        size     = 'small',
        species  = 'primate',
        canPet   = false,
        canTrick = false,
        icon     = 'paw',
    },

    -- ===== Addon Pets (Optional — require streaming resources) =====
    -- popcornrp-pets: https://github.com/alberttheprince/popcornrp-pets
    {
        model    = 'k9_male',
        item     = 'murderface_k9m',
        label    = 'K9 Shepherd (M)',
        maxHealth = 300,
        price    = 10000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'k9_female',
        item     = 'murderface_k9f',
        label    = 'K9 Shepherd (F)',
        maxHealth = 300,
        price    = 10000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'a_c_k9',
        item     = 'murderface_k9',
        label    = 'K9 Original',
        maxHealth = 300,
        price    = 8000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'a_c_dalmatian',
        item     = 'murderface_dalmatian',
        label    = 'Dalmatian',
        maxHealth = 250,
        price    = 7500,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'doberman',
        item     = 'murderface_doberman',
        label    = 'Doberman',
        maxHealth = 300,
        price    = 9000,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'chowchow',
        item     = 'murderface_chowchow',
        label    = 'Chow Chow',
        maxHealth = 250,
        price    = 6000,
        canHunt  = false,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'robot_dog',
        item     = 'murderface_robotdog',
        label    = 'Robot Dog',
        maxHealth = 350,
        price    = 20000,
        canHunt  = true,
        isK9     = false,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
    {
        model    = 'armadillo',
        item     = 'murderface_armadillo',
        label    = 'Armadillo',
        maxHealth = 150,
        price    = 5000,
        canHunt  = false,
        isK9     = false,
        animClass = 'cat',
        size     = 'small',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'paw',
        addon    = true,
    },
    {
        model    = 'cockroach',
        item     = 'murderface_cockroach',
        label    = 'Giant Cockroach',
        maxHealth = 100,
        price    = 1000,
        canHunt  = false,
        isK9     = false,
        animClass = nil,
        size     = 'small',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'bug',
        addon    = true,
    },
    {
        model    = 'tarantula',
        item     = 'murderface_tarantula',
        label    = 'Tarantula',
        maxHealth = 100,
        price    = 1500,
        canHunt  = false,
        isK9     = false,
        animClass = nil,
        size     = 'small',
        species  = 'wild',
        canPet   = false,
        canTrick = false,
        icon     = 'spider',
        addon    = true,
    },
    -- AddonPDK9: https://github.com/12LetterMeme/AddonPDK9
    {
        model    = 'pdk9',
        item     = 'murderface_pdk9',
        label    = 'Police K9',
        maxHealth = 300,
        price    = 10000,
        canHunt  = true,
        isK9     = true,
        animClass = 'large_dog',
        size     = 'large',
        species  = 'dog',
        canPet   = true,
        canTrick = true,
        icon     = 'dog',
        addon    = true,
    },
}

-- ========================================
--  Pre-indexed Lookups
--  Built at load time. Eliminates all O(n) loops.
--  Usage: Config.petsByItem['murderface_husky']
--         Config.petsByModel['A_C_Husky']
-- ========================================
Config.petsByItem = {}
Config.petsByModel = {}

for _, pet in ipairs(Config.pets) do
    Config.petsByItem[pet.item] = pet
    Config.petsByModel[pet.model] = pet
end

-- ========================================
--  Support Items
-- ========================================
Config.items = {
    food = {
        name = 'murderface_food',
        duration = 5,             -- seconds for feeding progress bar
    },
    collar = {
        name = 'murderface_collar',
        duration = 10,
    },
    nametag = {
        name = 'murderface_nametag',
        duration = 10,
    },
    firstaid = {
        name = 'murderface_firstaid',
        duration = 2,
        healPercent = 25,         -- % of maxHealth restored per use
        reviveBonus = 25,         -- HP above 100 after reviving dead pet
    },
    groomingkit = {
        name = 'murderface_groomingkit',
    },
    waterbottle = {
        name = 'murderface_waterbottle',
        duration = 2,
        maxCapacity = 10,         -- max water units in one bottle
        refillCost = 2,           -- water units consumed per drink
    },
    doghouse = {
        name = 'murderface_doghouse',
        duration = 3,             -- seconds for placement progress bar
    },
    leash = {
        name = 'murderface_leash',
    },
}

-- ========================================
--  K9 Settings
--  K9-eligible models are determined by pet.isK9 = true above.
-- ========================================
Config.k9 = {
    jobs = { 'police' },
    illegalItems = {
        -- existing
        'weed_brick',
        'coke_small_brick',
        'coke_brick',
        -- cocaine
        'coke_box',
        'coke_leaf',
        'coke_raw',
        'coke_pure',
        'coke_figure',
        'coke_figureempty',
        -- meth
        'meth_bag',
        'meth_glass',
        'meth_sharp',
        -- weed
        'weed_package',
        'weed_bud',
        'weed_budclean',
        'weed_blunt',
        'weed_joint',
        -- heroin / opiates
        'heroin',
        'heroin_syringe',
        'poppyplant',
        -- crack
        'crack',
        -- pills / psychedelics
        'ecstasy1',
        'ecstasy2',
        'ecstasy3',
        'ecstasy4',
        'ecstasy5',
        'lsd1',
        'lsd2',
        'lsd3',
        'lsd4',
        'lsd5',
        'xanaxpack',
        'xanaxplate',
        'xanaxpill',
        'magicmushroom',
        'peyote',
        -- paraphernalia
        'meth_pipe',
        'crack_pipe',
        'syringe',
        'meth_syringe',
    },
}

-- ========================================
--  Pet Shop
-- ========================================
Config.petShop = {
    enabled = true,
    ped = {
        model = 'a_m_m_farmer_01',
        coords = vector4(561.27, 2740.83, 42.8, 179.59),
        -- MLO coords (Patoche Pet Hospital): vector4(561.59, 2752.89, 42.16, 180.37)
    },
    blip = {
        sprite = 442,
        colour = 3,
        text = 'Pet Shop',
        shortRange = true,
    },
}

-- ========================================
--  Supplies Shop
-- ========================================
Config.suppliesShop = {
    enabled = true,
    ped = {
        model = 'a_f_y_hipster_02',
        coords = vector4(563.42, 2741.02, 42.8, 181.57),
        -- MLO coords (Patoche Pet Hospital): vector4(563.59, 2751.89, 42.16, 180.37)
    },
    items = {
        { name = 'murderface_food',        label = 'Pet Food',              price = 100 },
        { name = 'murderface_firstaid',    label = 'Pet First Aid Kit',     price = 500 },
        { name = 'murderface_waterbottle', label = 'Portable Water Bottle', price = 300 },
        { name = 'murderface_collar',      label = 'Pet Collar',            price = 250 },
        { name = 'murderface_nametag',     label = 'Name Tag',              price = 150 },
        { name = 'murderface_leash',       label = 'Pet Leash',              price = 200 },
        { name = 'murderface_groomingkit', label = 'Grooming Kit',          price = 750 },
        { name = 'murderface_doghouse',   label = 'Dog House',             price = 5000 },
    },
}
