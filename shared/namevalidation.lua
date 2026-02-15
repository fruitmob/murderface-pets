-- murderface-pets: Pet name validation
-- Checks length, single word, and filters inappropriate names.

local blocked = {}

local blockedWords = {
    'fuck', 'fucker', 'fucking', 'fck', 'fuk',
    'shit', 'shitter', 'shitty',
    'bitch', 'bitches',
    'ass', 'asshole',
    'dick', 'cock', 'cunt', 'cunts',
    'nigger', 'nigga', 'n1gger', 'n1gga',
    'faggot', 'fag', 'faggy',
    'retard', 'retarded',
    'whore', 'slut', 'slutty',
    'pussy', 'piss',
    'bastard', 'damn', 'nazi',
    'chink', 'spic', 'kike',
    'twat', 'wanker', 'bollocks',
}

for _, w in ipairs(blockedWords) do
    blocked[w:lower()] = true
end

--- Validate a pet name for appropriateness and format
---@param name string The proposed pet name
---@param maxLen? number Maximum character length (default 12)
---@return true|table True if valid, or { reason = string } if invalid
function ValidatePetName(name, maxLen)
    maxLen = maxLen or 12

    if type(name) ~= 'string' then
        return { reason = 'invalid_type' }
    end

    if name:find('%s') then
        return { reason = 'multiple_words' }
    end

    if #name < 1 or #name > maxLen then
        return { reason = 'invalid_length' }
    end

    if blocked[name:lower()] then
        return { reason = 'blocked_word' }
    end

    return true
end
