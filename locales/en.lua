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
            error = {
                pet_unable_to_hunt = 'Your pet can not hunt',
                not_meet_min_requirement_to_hunt = 'Your pet needs to level up in order to hunt. (min level: %s)',
                already_hunting_something = 'Already hunting something!',
                pet_unable_to_do_that = 'Unable to do your command',
                need_to_be_inside_car = 'You need to be inside a car',
                to_far = 'Too far',
                no_empty_seat = 'No empty seat found!',
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
