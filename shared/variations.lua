-- murderface-pets: Pet coat/color variation data
-- Maps model names to available appearance options.
-- Each coat is { name, component, drawable, texture } for SetPedComponentVariation.

Variations = {}

Variations.coats = {
    ['A_C_Husky'] = {
        { name = 'dark',      component = 0, drawable = 0, texture = 0 },
        { name = 'brown',     component = 0, drawable = 0, texture = 1 },
        { name = 'white',     component = 0, drawable = 0, texture = 2 },
    },
    ['A_C_Westy'] = {
        { name = 'white',     component = 4, drawable = 0, texture = 0 },
        { name = 'brown',     component = 4, drawable = 0, texture = 1 },
        { name = 'dark',      component = 4, drawable = 0, texture = 2 },
    },
    ['A_C_shepherd'] = {
        { name = 'darkBrown', component = 0, drawable = 0, texture = 0 },
        { name = 'white',     component = 0, drawable = 0, texture = 1 },
        { name = 'brown',     component = 0, drawable = 0, texture = 2 },
    },
    ['A_C_Rottweiler'] = {
        { name = 'dark',      component = 4, drawable = 0, texture = 0 },
        { name = 'brown',     component = 4, drawable = 0, texture = 1 },
        { name = 'darkBrown', component = 4, drawable = 0, texture = 2 },
    },
    ['A_C_Retriever'] = {
        { name = 'brown',     component = 0, drawable = 0, texture = 0 },
        { name = 'dark',      component = 0, drawable = 0, texture = 1 },
        { name = 'white',     component = 0, drawable = 0, texture = 2 },
        { name = 'darkBrown', component = 0, drawable = 0, texture = 3 },
    },
    ['A_C_Pug'] = {
        { name = 'white',     component = 4, drawable = 0, texture = 0 },
        { name = 'gray',      component = 4, drawable = 0, texture = 1 },
        { name = 'brown',     component = 4, drawable = 0, texture = 2 },
        { name = 'dark',      component = 4, drawable = 0, texture = 3 },
    },
    ['A_C_Poodle'] = {
        { name = 'white',     component = 0, drawable = 0, texture = 0 },
    },
    ['A_C_MtLion'] = {
        { name = 'white',     component = 0, drawable = 0, texture = 0 },
        { name = 'brown',     component = 0, drawable = 0, texture = 1 },
        { name = 'darkBrown', component = 0, drawable = 0, texture = 2 },
    },
    ['A_C_Panther'] = {
        { name = 'dark',      component = 0, drawable = 0, texture = 0 },
    },
    ['A_C_Cat_01'] = {
        { name = 'gray',      component = 0, drawable = 0, texture = 0 },
        { name = 'dark',      component = 0, drawable = 0, texture = 1 },
        { name = 'brown',     component = 0, drawable = 0, texture = 2 },
    },
    ['A_C_Coyote'] = {
        { name = 'gray',      component = 0, drawable = 0, texture = 0 },
        { name = 'lightGray', component = 0, drawable = 0, texture = 1 },
        { name = 'brown',     component = 0, drawable = 0, texture = 2 },
        { name = 'lightBrown', component = 0, drawable = 0, texture = 3 },
    },
    ['A_C_Hen'] = {
        { name = 'brown',     component = 0, drawable = 0, texture = 0 },
    },
    ['A_C_Rabbit_01'] = {
        { name = 'brown',     component = 0, drawable = 0, texture = 0 },
        { name = 'darkBrown', component = 0, drawable = 0, texture = 1 },
        { name = 'lightBrown', component = 0, drawable = 0, texture = 2 },
        { name = 'gray',      component = 0, drawable = 0, texture = 3 },
    },
    -- DLC models (build 3258+)
    ['a_c_chop_02'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },
    ['a_c_chimp_02'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },
    ['a_c_rhesus'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },

    -- Addon models (popcornrp-pets)
    ['k9_male'] = {
        { name = 'tan',       component = 0, drawable = 0, texture = 0 },
        { name = 'black',     component = 0, drawable = 0, texture = 1 },
        { name = 'sable',     component = 0, drawable = 0, texture = 2 },
        { name = 'bicolor',   component = 0, drawable = 0, texture = 3 },
        { name = 'white',     component = 0, drawable = 0, texture = 4 },
        { name = 'silver',    component = 0, drawable = 0, texture = 5 },
        { name = 'red',       component = 0, drawable = 0, texture = 6 },
        { name = 'dark',      component = 0, drawable = 0, texture = 7 },
    },
    ['k9_female'] = {
        { name = 'tan',       component = 0, drawable = 0, texture = 0 },
        { name = 'black',     component = 0, drawable = 0, texture = 1 },
        { name = 'sable',     component = 0, drawable = 0, texture = 2 },
        { name = 'bicolor',   component = 0, drawable = 0, texture = 3 },
        { name = 'white',     component = 0, drawable = 0, texture = 4 },
        { name = 'silver',    component = 0, drawable = 0, texture = 5 },
        { name = 'red',       component = 0, drawable = 0, texture = 6 },
        { name = 'dark',      component = 0, drawable = 0, texture = 7 },
    },
    ['a_c_k9'] = {
        { name = 'tan',       component = 0, drawable = 0, texture = 0 },
        { name = 'black',     component = 0, drawable = 0, texture = 1 },
        { name = 'sable',     component = 0, drawable = 0, texture = 2 },
        { name = 'bicolor',   component = 0, drawable = 0, texture = 3 },
    },
    ['a_c_dalmatian'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },
    ['doberman'] = {
        { name = 'black',     component = 0, drawable = 0, texture = 0 },
        { name = 'red',       component = 0, drawable = 0, texture = 1 },
        { name = 'blue',      component = 0, drawable = 0, texture = 2 },
    },
    ['chowchow'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },
    ['robot_dog'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },
    ['armadillo'] = {
        { name = 'default',   component = 0, drawable = 0, texture = 0 },
    },

    -- Addon model (AddonPDK9)
    ['pdk9'] = {
        { name = 'tan',       component = 0, drawable = 0, texture = 0 },
        { name = 'black',     component = 0, drawable = 0, texture = 1 },
        { name = 'sable',     component = 0, drawable = 0, texture = 2 },
        { name = 'bicolor',   component = 0, drawable = 0, texture = 3 },
    },
}

--- Apply a coat variation to a ped
---@param ped number Entity handle
---@param model string GTA model name
---@param coatName string Variation name (e.g. 'dark', 'brown')
---@return boolean success
function Variations.apply(ped, model, coatName)
    local modelCoats = Variations.coats[model]
    if not modelCoats then return false end

    for _, coat in ipairs(modelCoats) do
        if coat.name == coatName then
            if IsPedComponentVariationValid(ped, coat.component, coat.drawable, coat.texture) then
                SetPedComponentVariation(ped, coat.component, coat.drawable, coat.texture, 0)
                return true
            end
            return false
        end
    end
    return false
end

--- Get a random coat name for a model
---@param model string GTA model name
---@return string|nil coatName
function Variations.getRandom(model)
    local modelCoats = Variations.coats[model]
    if not modelCoats or #modelCoats == 0 then return nil end
    return modelCoats[math.random(#modelCoats)].name
end

--- Get all available coat names for a model
---@param model string GTA model name
---@return table names Array of coat name strings
function Variations.getNames(model)
    local modelCoats = Variations.coats[model]
    if not modelCoats then return {} end

    local names = {}
    for _, coat in ipairs(modelCoats) do
        names[#names + 1] = coat.name
    end
    return names
end
