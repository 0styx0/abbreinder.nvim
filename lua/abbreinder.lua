local api = vim.api

local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

local abbreinder = {
    cache = {
        abbrevs = '',
        abbrev_map_value_trigger = {},
        multiword_abbrev_map = {},
        keylogger = ''
    }
}


-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return two maps - {trigger, value} and for multiword abbrevs, {last_word_of_value, full_value}
local function get_abbrevs_val_trigger()

    local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if (abbreinder.cache.abbrevs == abbrevs) then

        return abbreinder.cache.abbrev_map_value_trigger,
            abbreinder.cache.abbrev_map_multiword
    end
    abbreinder.cache.abbrevs = abbrevs

    -- using {value, trigger} instead of {trigger, value} because
    -- the user types the value, not the trigger
    local abbrev_map_value_trigger = {}

    -- multiword map only uses last word of multiword values for the key
    -- if that word is found, check full list for key/value
    local abbrev_map_multiword = {}

    for trigger, val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

        for _, prefix in ipairs(abbreinder.config.value_prefixes) do
            val = val:gsub('^'..prefix, '')
        end

        local multiword_expansion = val:find(' ') ~= nil
        if (multiword_expansion) then
            local last_word = val:match('(%S+)$')
            abbrev_map_multiword[last_word] = val
        end

        abbrev_map_value_trigger[val] = trigger
    end

    abbreinder.cache.abbrev_map_value_trigger = abbrev_map_value_trigger
    abbreinder.cache.abbrev_map_multiword = abbrev_map_multiword

    return abbrev_map_value_trigger, abbrev_map_multiword
end


-- @Summary checks if abbreviation functionality was used.
-- if value was manually typed, notify user
-- @return true if a valid abbreviation (expanded or not) was found
local function check_abbrev_expanded(trigger, value)

    -- format of keylogger will be `randomWords trigger value` for expanded abbreviation
    -- or `randomWords value` for unexpanded
    local expanded_start = abbreinder.cache.keylogger:find(trigger .. ' ' .. value)

    if (expanded_start ~= nil) then
        print('expanded found')
        vim.cmd [[doautocmd User AbbreinderAbbrExpanded]]
        abbreinder.cache.keylogger = ''
        return true
    end

    local unexpanded_start = abbreinder.cache.keylogger:find(value)

    if (unexpanded_start ~= nil) then
        print('unexpanded found')
        ui.highlight_unexpanded_abbr(abbreinder, value)
        vim.cmd [[doautocmd User AbbreinderAbbrUnexpanded]]
        abbreinder.cache.keylogger = ''
        return true
    end
end

-- @Summary searches through what has been typed since the user last typed
-- an abbreviation-expanding character, to see if an abbreviation has been used
function abbreinder.find_abbrev()

    abbreinder.cache.keylogger = abbreinder.cache.keylogger .. vim.v.char

    -- fname = characters that expand abbreviations.
    local cur_char_is_abbr_expanding = vim.fn.fnameescape(vim.v.char) ~= vim.v.char
    if (not cur_char_is_abbr_expanding) then
        return
    end


    local text_to_search = abbreinder.cache.keylogger

    local word_start, word_end = text_to_search:find('%S+')
    while word_start ~= nil do

        local value_trigger, multiword_map = get_abbrevs_val_trigger()
        local potential_value = text_to_search:sub(word_start, word_end)
        local potential_trigger = value_trigger[potential_value]

        local potential_multiword_abbrev = multiword_map[potential_value] ~= nil
        if (potential_multiword_abbrev) then
            local multi_value = multiword_map[potential_value]
            local multi_trigger = value_trigger[multi_value]
            check_abbrev_expanded(multi_trigger, multi_value)
        end

        if (potential_trigger ~= nil and potential_value ~= nil) then
            check_abbrev_expanded(potential_trigger, potential_value)
        end

        word_start, word_end = text_to_search:find('%S+', word_end + 1)
    end
end


abbreinder.create_commands = function()

    vim.cmd([[
    augroup Abbreinder
    autocmd!
    autocmd InsertCharPre * :lua require('abbreinder').find_abbrev()
    augroup END
    ]])

end


-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function abbreinder.setup(user_config)

    user_config = user_config or {}

    abbreinder.config = vim.tbl_extend('force', default_config, user_config)

    abbreinder.create_commands()
end

return abbreinder
