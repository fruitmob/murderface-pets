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

Config.stressRelief = {
    enabled = true,              -- set true if you have a HUD with stress mechanics
    event = 'hud:server:RelieveStress',
    amount = { min = 12, max = 24 },
}

-- ========================================
--  Balance / Progression
-- ========================================
Config.balance = {
    maxLevel = 50,
    minHuntLevel = 1,             -- minimum level before a pet can hunt

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
        maxHealth = 100,
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
        maxHealth = 100,
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
        coords = vector4(561.59, 2752.89, 42.16, 180.37),
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
        coords = vector4(563.59, 2751.89, 42.16, 180.37),
    },
    items = {
        { name = 'murderface_food',        label = 'Pet Food',              price = 100 },
        { name = 'murderface_firstaid',    label = 'Pet First Aid Kit',     price = 500 },
        { name = 'murderface_waterbottle', label = 'Portable Water Bottle', price = 300 },
        { name = 'murderface_collar',      label = 'Pet Collar',            price = 250 },
        { name = 'murderface_nametag',     label = 'Name Tag',              price = 150 },
        { name = 'murderface_groomingkit', label = 'Grooming Kit',          price = 750 },
    },
}
