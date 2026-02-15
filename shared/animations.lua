-- murderface-pets: Config-driven animation registry
-- Organized by animClass (from Config.pets), then by action category.
-- Each action has an array of animation clips to choose from.

local FLAG = {
    DEFAULT  = 0,
    LOOP     = 1,
    HOLD     = 2,    -- freeze on last frame
    UPPER    = 16,
    CONTROL  = 32,
    CANCEL   = 120,
}

Anims = {}

Anims.classes = {
    -- ===== Large Dogs (Husky, Shepherd, Rottweiler, Retriever, Chop) =====
    large_dog = {
        bark = {
            { dict = 'creatures@retriever@amb@world_dog_barking@idle_a', clip = 'idle_a' },
            { dict = 'creatures@retriever@amb@world_dog_barking@idle_a', clip = 'idle_b' },
            { dict = 'creatures@retriever@amb@world_dog_barking@idle_a', clip = 'idle_c' },
        },
        sit = {
            { dict = 'creatures@retriever@amb@world_dog_sitting@idle_a', clip = 'idle_a' },
            { dict = 'creatures@retriever@amb@world_dog_sitting@idle_a', clip = 'idle_c' },
            { dict = 'creatures@retriever@amb@world_dog_sitting@base',   clip = 'base', flag = FLAG.HOLD },
        },
        sleep = {
            { dict = 'creatures@rottweiler@amb@sleep_in_kennel@', clip = 'sleep_in_kennel', flag = FLAG.HOLD },
        },
        tricks = {
            beg = {
                sequence = {
                    { dict = 'creatures@rottweiler@tricks@', clip = 'beg_enter',  flag = FLAG.HOLD,    duration = 3 },
                    { dict = 'creatures@rottweiler@tricks@', clip = 'beg_loop',   flag = FLAG.LOOP,    duration = 5 },
                    { dict = 'creatures@rottweiler@tricks@', clip = 'beg_exit',   flag = FLAG.DEFAULT, duration = 3 },
                },
            },
            paw = {
                sequence = {
                    { dict = 'creatures@rottweiler@tricks@', clip = 'paw_right_enter', flag = FLAG.HOLD,    duration = 3 },
                    { dict = 'creatures@rottweiler@tricks@', clip = 'paw_right_loop',  flag = FLAG.LOOP,    duration = 5 },
                    { dict = 'creatures@rottweiler@tricks@', clip = 'paw_right_exit',  flag = FLAG.DEFAULT, duration = 3 },
                },
            },
            play_dead = {
                { dict = 'creatures@rottweiler@move', clip = 'dying', flag = FLAG.HOLD },
            },
        },
        petting = {
            pet_anim  = { dict = 'creatures@rottweiler@tricks@', clip = 'petting_chop' },
            human_anim = { dict = 'creatures@rottweiler@tricks@', clip = 'petting_franklin' },
        },
        misc = {
            { dict = 'creatures@rottweiler@indication@', clip = 'indicate_ahead' },
            { dict = 'creatures@rottweiler@indication@', clip = 'indicate_high' },
            { dict = 'creatures@rottweiler@indication@', clip = 'indicate_low' },
        },
        pickup = {
            { dict = 'CREATURES@ROTTWEILER@MOVE', clip = 'fetch_pickup' },
            { dict = 'CREATURES@ROTTWEILER@MOVE', clip = 'fetch_drop' },
        },
        revive = {
            sequence = {
                { dict = 'amb@medic@standing@tendtodead@enter',  clip = 'enter',  flag = FLAG.HOLD,    duration = 3 },
                { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_c', flag = FLAG.LOOP,    duration = 5 },
                { dict = 'amb@medic@standing@tendtodead@exit',   clip = 'exit',   flag = FLAG.DEFAULT, duration = 3 },
            },
        },
    },

    -- ===== Small Dogs (Westy, Pug, Poodle) =====
    small_dog = {
        bark = {
            { dict = 'creatures@pug@amb@world_dog_barking@idle_a', clip = 'idle_a' },
            { dict = 'creatures@pug@amb@world_dog_barking@idle_a', clip = 'idle_b' },
            { dict = 'creatures@pug@amb@world_dog_barking@idle_a', clip = 'idle_c' },
        },
        sit = {
            { dict = 'creatures@pug@amb@world_dog_sitting@idle_a', clip = 'idle_a' },
            { dict = 'creatures@pug@amb@world_dog_sitting@idle_a', clip = 'idle_b' },
            { dict = 'creatures@pug@amb@world_dog_sitting@idle_a', clip = 'idle_c' },
        },
        sit_sequence = {
            sequence = {
                { dict = 'creatures@pug@amb@world_dog_sitting@enter', clip = 'enter', flag = FLAG.HOLD,    duration = 3 },
                { dict = 'creatures@pug@amb@world_dog_sitting@base',  clip = 'base',  flag = FLAG.LOOP,    duration = 8 },
                { dict = 'creatures@pug@amb@world_dog_sitting@exit',  clip = 'exit',  flag = FLAG.DEFAULT, duration = 2 },
            },
        },
        -- small dogs have no sleep/tricks/petting animations
    },

    -- ===== Cat (House Cat) =====
    cat = {
        idle = {
            { dict = 'creatures@cat@move', clip = 'idle' },
            { dict = 'creatures@cat@move', clip = 'idle_dwn' },
            { dict = 'creatures@cat@move', clip = 'idle_upp' },
        },
        sit = {
            { dict = 'creatures@cat@amb@world_cat_sleeping_ledge@idle_a', clip = 'idle_a', flag = FLAG.HOLD },
        },
        sleep = {
            { dict = 'creatures@cat@amb@world_cat_sleeping_ground@enter', clip = 'enter' },
            { dict = 'creatures@cat@amb@world_cat_sleeping_ground@base',  clip = 'base', flag = FLAG.LOOP },
        },
        wake = {
            { dict = 'creatures@cat@amb@world_cat_sleeping_ground@exit', clip = 'base' },
        },
    },

    -- ===== Cougar (Panther, Mountain Lion, Coyote) =====
    cougar = {
        idle = {
            { dict = 'creatures@cat@move', clip = 'idle' },
        },
        sit = {
            { dict = 'creatures@cougar@amb@world_cougar_rest@idle_a', clip = 'idle_c', flag = FLAG.HOLD },
        },
        sleep = {
            { dict = 'creatures@cougar@amb@world_cougar_rest@idle_a', clip = 'idle_a', flag = FLAG.HOLD },
        },
    },

    -- ===== Primates (Chimp, Rhesus) =====
    -- Limited animation support — basic idle only
    primate = {
        idle = {},  -- uses default ped idle
    },

    -- ===== Player animations (used during pet interactions) =====
    player = {
        revive = {
            sequence = {
                { dict = 'amb@medic@standing@tendtodead@enter',  clip = 'enter',  flag = FLAG.HOLD,    duration = 3 },
                { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_c', flag = FLAG.LOOP,    duration = 5 },
                { dict = 'amb@medic@standing@tendtodead@exit',   clip = 'exit',   flag = FLAG.DEFAULT, duration = 3 },
            },
        },
    },
}

-- ========================================
--  Animation Playback
-- ========================================

--- Load an animation dictionary and wait until ready
---@param dict string Animation dictionary name
local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then return end
    end
end

--- Play a single animation clip on a ped
---@param ped number Entity handle
---@param dict string Animation dictionary
---@param clip string Animation clip name
---@param flag? number Animation flag (default 0)
local function playClip(ped, dict, clip, flag)
    loadDict(dict)
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, flag or FLAG.DEFAULT, 0, false, false, false)
end

--- Play a sequential (multi-step) animation on a ped
---@param ped number Entity handle
---@param steps table Array of { dict, clip, flag, duration }
local function playSequence(ped, steps)
    CreateThread(function()
        for i, step in ipairs(steps) do
            local stepFlag = step.flag or FLAG.DEFAULT
            if i == 1 then
                stepFlag = step.flag or FLAG.HOLD
            elseif i == #steps then
                stepFlag = step.flag or FLAG.DEFAULT
            else
                stepFlag = step.flag or FLAG.LOOP
            end

            playClip(ped, step.dict, step.clip, stepFlag)

            -- Wait for animation to finish or timeout
            local elapsed = 0
            local maxTime = (step.duration or 5) * 1000
            Wait(100)
            while IsEntityPlayingAnim(ped, step.dict, step.clip, 3) == 1 and elapsed < maxTime do
                Wait(500)
                elapsed = elapsed + 500
            end
        end
    end)
end

--- Check if an animClass has a specific action available
---@param animClass string|nil The animation class key (e.g. 'large_dog')
---@param action string The action name (e.g. 'sit', 'bark', 'tricks')
---@return boolean
function Anims.hasAction(animClass, action)
    if not animClass then return false end
    local cls = Anims.classes[animClass]
    if not cls then return false end
    local actionData = cls[action]
    if not actionData then return false end

    -- Check if it's a non-empty table
    if type(actionData) == 'table' then
        -- Could be an array of clips or a table with a sequence key
        if actionData.sequence then return true end
        if #actionData > 0 then return true end
        -- Check for named sub-actions (like tricks.beg, tricks.paw)
        for _ in pairs(actionData) do return true end
    end
    return false
end

--- Play a random animation from an action category
---@param ped number Entity handle
---@param animClass string The animation class key
---@param action string The action name
---@param opts? table Optional: { clip = string, flag = number }
function Anims.play(ped, animClass, action, opts)
    if not animClass then return end
    local cls = Anims.classes[animClass]
    if not cls or not cls[action] then return end

    opts = opts or {}
    local actionData = cls[action]

    -- If action data has a sequence key, play it as a sequence
    if actionData.sequence then
        playSequence(ped, actionData.sequence)
        return
    end

    -- If it's an array of clips, pick one (or use specified index)
    if #actionData > 0 then
        local entry
        if opts.clip then
            -- Find by clip name
            for _, e in ipairs(actionData) do
                if e.clip == opts.clip then
                    entry = e
                    break
                end
            end
        end
        if not entry then
            entry = actionData[math.random(#actionData)]
        end
        playClip(ped, entry.dict, entry.clip, opts.flag or entry.flag)
        return
    end
end

--- Play a named sub-action (e.g. tricks.beg, tricks.paw)
---@param ped number Entity handle
---@param animClass string The animation class key
---@param action string The action category (e.g. 'tricks')
---@param subAction string The specific sub-action (e.g. 'beg', 'paw')
function Anims.playSub(ped, animClass, action, subAction)
    if not animClass then return end
    local cls = Anims.classes[animClass]
    if not cls or not cls[action] or not cls[action][subAction] then return end

    local data = cls[action][subAction]

    if data.sequence then
        playSequence(ped, data.sequence)
    elseif type(data) == 'table' and #data > 0 then
        local entry = data[math.random(#data)]
        playClip(ped, entry.dict, entry.clip, entry.flag)
    elseif data.dict and data.clip then
        playClip(ped, data.dict, data.clip, data.flag)
    end
end

--- Get the petting animation pair (pet anim + human anim)
---@param animClass string The animation class key
---@return table|nil petting { pet_anim = {dict, clip}, human_anim = {dict, clip} }
function Anims.getPetting(animClass)
    if not animClass then return nil end
    local cls = Anims.classes[animClass]
    if not cls or not cls.petting then return nil end
    return cls.petting
end

--- Get list of available trick names for an animClass
---@param animClass string The animation class key
---@return table names Array of trick name strings
function Anims.getTrickNames(animClass)
    if not animClass then return {} end
    local cls = Anims.classes[animClass]
    if not cls or not cls.tricks then return {} end

    local names = {}
    for name in pairs(cls.tricks) do
        names[#names + 1] = name
    end
    return names
end
