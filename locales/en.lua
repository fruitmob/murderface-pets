local Translations = {
    error = {
        no_pet_under_control = 'At least one pet must be under your control',
        badword_inside_pet_name = 'Do not name your pet like that!',
        more_than_one_word_as_name = 'You can not use that many words in your pet name!',
        failed_to_start_process = 'Failed to start process!',
        failed_to_find_pet = 'Could not find your pet!',
        could_not_do_that = 'Could not do that',
        string_type = 'Wrong name type (only string)!',
        not_enough_first_aid = 'You need first aid to do this!',
        reached_max_allowed_pet = 'You can not have more than %s active pets!',
        failed_to_validate_name = 'We can not validate this name, try something else!',
        failed_to_rename = 'Failed to rename your pet',
        failed_to_rename_same_name = 'The new name is the same as the current one',
        your_pet_is_dead = 'Your pet is dead, try again when your pet is alive',
        your_pet_died_by = 'Your pet died by %s',
        not_owner_of_pet = 'You are not owner of this pet',
        failed_to_remove_item_from_inventory = 'Failed to remove from your inventory',
        failed_to_transfer_ownership_same_owner = 'You can not transfer your pet to yourself!',
        failed_to_transfer_ownership_could_not_find_new_owner_id = 'Could not find new owner (wrong id)',
        failed_to_transfer_ownership_missing_current_owner = 'Can not transfer this pet, missing current owner information!',
        not_enough_water_bottles = 'You are not carrying enough water bottles (min: %d)',
        not_enough_water_in_your_bottle = 'Your water bottle is empty!',
        blocked_name = 'That name is not allowed!',
        pet_died = '%s died!',
    },
    success = {
        pet_initialization_was_successful = 'Congratulations on your new companion',
        pet_rename_was_successful = 'Your pet name changed to ',
        healing_was_successful = 'Your pet healed for: %s maxHealth: %s',
        successful_revive = '%s your pet revived',
        successful_ownership_transfer = 'The transfer was successful. You can now give this pet to the new owner',
        successful_drinking = 'Drinking was successful, wait a little bit to take effect',
        successful_grooming = 'Grooming was successful',
    },
    info = {
        use_3th_eye = 'Use your 3rd eye on your pet',
        full_life_pet = 'Your pet is on full health',
        still_on_cooldown = 'Still on cooldown remaining: %s sec',
        level_up = '%s gained a new level: %d',
    },
    stray = {
        feeding = 'Feeding stray...',
        tamed = '%s trusts you completely! Check your inventory.',
        cooldown = 'Come back later to feed this stray',
    },
    breeding = {
        placing_doghouse = 'Placing dog house...',
        doghouse_placed = 'Dog house placed successfully!',
        placement_failed = 'Failed to place dog house',
        placement_cancelled = 'Placement cancelled',
        already_have_doghouse = 'You already have a dog house placed!',
        breed_pets = 'Breed Pets',
        claim_puppy = 'Claim Puppy',
        check_status = 'Check Breeding Status',
        pickup_doghouse = 'Pick Up Dog House',
        no_eligible_pairs = 'No eligible breeding pairs found. Need same breed, opposite gender, both level 10+.',
        menu_title = 'Select Breeding Pair',
        confirm_header = 'Confirm Breeding',
        confirm_body = 'Breed %s and %s together?\n\nOffspring will be a %s and available after the next server restart.',
        breeding_in_progress = 'Initiating breeding...',
        success_title = 'Breeding Started!',
        success_body = 'Your new puppy will be available after the next server restart. Check the dog house to claim it!',
        failed = 'Breeding failed',
        status_pending = 'A %s puppy is on the way! Available after the next server restart.',
        claim_header = 'Claim Your Puppy',
        claim_body = 'Claim %s and add them to your inventory?',
        puppy_claimed_title = 'New Companion!',
        puppy_claimed_body = 'Welcome %s to the family! Check your inventory.',
        claim_failed = 'Failed to claim puppy',
        cannot_pickup_breeding_active = 'Cannot pick up dog house while breeding is in progress or a puppy is waiting!',
        picking_up = 'Picking up dog house...',
        doghouse_picked_up = 'Dog house returned to your inventory',
    },
    menu = {
        general_menu_items = {
            btn_leave = 'Leave',
            btn_back = 'Back',
            success = 'Success',
            confirm = 'Confirm',
        },
        main_menu = {
            header = 'Name: %s',
            sub_header = 'Current pet under your control',
            btn_actions = 'Actions',
            btn_switchcontrol = 'Switch Control',
            switchcontrol_header = 'Switch Pet Under Your Control',
            switchcontrol_sub_header = 'Click on pet which you want to control',
        },
        action_menu = {
            header = 'Name: %s',
            sub_header = 'Current pet under your control',
            follow = 'Follow Owner',
            hunt = 'Hunt',
            hunt_and_grab = 'Hunt and Grab',
            go_there = 'Go There',
            wait = 'Wait Here',
            get_in_car = 'Get in Car',
            beg = 'Do Some Tricks',
            paw = 'Paw',
            play_dead = 'Play Dead',
            tricks = 'Tricks',
            sit = 'Sit',
            lay_down = 'Lay Down',
            speak = 'Speak',
            pet_caress = 'Pet',
            guard = 'Guard Here',
            recall_guard = 'Recall from Guard',
            guard_intruder = 'Intruder detected in guard zone!',
            specialize = 'Specialize',
            track = 'Track Nearby',
            error = {
                pet_unable_to_hunt = 'Your pet can not hunt',
                not_meet_min_requirement_to_hunt = 'Your pet needs to level up in order to hunt. (min level: %s)',
                already_hunting_something = 'Already hunting something!',
                pet_unable_to_do_that = 'Unable to do your command',
                need_to_be_inside_car = 'You need to be inside a car',
                to_far = 'Too far',
                no_empty_seat = 'No empty seat found!',
                cannot_guard_leashed = 'Cannot guard while leashed',
            },
            success = {},
            info = {},
        },
        tricks = {
            header = 'Name: %s',
            sub_header = 'Current pet under your control',
        },
        switchControl_menu = {
            header = 'Name: %s',
            sub_header = 'Current pet under your control',
        },
        customization_menu = {
            header = 'Customization Menu',
            sub_header = '',
            btn_rename = 'Rename',
            btn_txt_btn_rename = 'Current name: ',
            btn_select_variation = 'Select Variation',
            btn_txt_select_variation = 'Current color: ',
            rename = {
                inputs = {
                    header = 'Type new name',
                },
            },
        },
        rename_menu = {
            header = 'Current Name',
            btn_rename = 'Rename',
        },
        variation_menu = {
            header = 'Current Color',
            btn_select_variation = 'Select Variation',
            btn_txt_select_variation = 'Choose a color for your pet',
            selection_menu = {
                header = 'Variation List',
                btn_variation_items = 'Variation: ',
                btn_desc = 'Select to apply',
            },
        },
    },
}

--- Standalone locale shim
--- Traverses the Translations table by dot-separated path
local function deepGet(tbl, path)
    local current = tbl
    for key in path:gmatch('[^.]+') do
        if type(current) ~= 'table' then return path end
        current = current[key]
    end
    return current or path
end

Lang = {
    t = function(_, path)
        return deepGet(Translations, path)
    end,
}
