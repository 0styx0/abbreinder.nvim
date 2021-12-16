local api = vim.api

local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

local abbreinder = {
    cache = {
        abbrevs = '',
        abbrev_map_value_trigger = '',
        multiword_abbrev_map = {},
        keylogger = ''
    }
}


-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return two maps - {trigger, value} and {value, trigger}
local function get_abbrevs_val_trigger()

    local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if (abbreinder.cache.abbrevs == abbrevs) then
        -- returning both values, because user types a value and we need to see
        -- if there's a trigger for it
        -- but also if it's a multiword value, we'll then have the key,
        -- but need the value
        return abbreinder.cache.abbrev_map_trigger_value,
            abbreinder.cache.abbrev_map_value_trigger,
            abbreinder.cache.abbrev_map_multiword
    end
    abbreinder.cache.abbrevs = abbrevs

    -- using {value, trigger} instead of {trigger, value} because
    -- the user types the value, not the trigger
    local abbrev_map_trigger_value = {}
    local abbrev_map_value_trigger = {}

    -- have the abbrev_map only store last word of multiword values
    -- if that word is found, check a multiword map for the values
    -- pov point of view
    -- map {last_word_in_value, }
    local multiword_abbrev_map = {}

    for trigger, val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

        for _, prefix in ipairs(abbreinder.config.value_prefixes) do
            val = val:gsub('^'..prefix, '')
        end

        local multiword_expansion = val:find(' ') ~= nil
        if (multiword_expansion) then
            local last_word = val:match('(%S+)$')
            multiword_abbrev_map[last_word] = val
        end

        abbrev_map_trigger_value[trigger] = val
        abbrev_map_value_trigger[val] = trigger
    end

    -- todo: see if need in obj
    abbreinder.cache.abbrev_map_trigger_value = abbrev_map_trigger_value
    abbreinder.cache.abbrev_map_value_trigger = abbrev_map_value_trigger
    abbreinder.cache.abbrev_map_multiword = multiword_abbrev_map

    return abbrev_map_trigger_value,
        abbrev_map_value_trigger,
        multiword_abbrev_map
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

    -- print('logger...'..abbreinder.cache.keylogger .. ' key..'.. trigger .. ' val...'..value)

    -- if it can be start of multiword value, don't clear logger
    if (unexpanded_start ~= nil) then
        print('unexpanded found')
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

        -- written: point of view. trigger: pov
        -- if abbrev[value] would be [point]
        local potential_value = text_to_search:sub(word_start, word_end)

        local k_t, t_k, last_multi = get_abbrevs_val_trigger()
        local potential_trigger = t_k[potential_value]
        local potential_trigger_multiword = k_t[potential_value]

        local potential_multiword_abbrev = last_multi[potential_value] ~= nil
        if (potential_multiword_abbrev) then
            local multi_value = last_multi[potential_value]
            local multi_trigger = t_k[multi_value]
            check_abbrev_expanded(multi_trigger, multi_value)
        end

        local flag = false
        if (potential_trigger ~= nil and potential_value ~= nil) then
            flag = check_abbrev_expanded(potential_trigger, potential_value)
        end

        if (potential_trigger_multiword ~= nil and potential_value ~= nil and not flag) then
            check_abbrev_expanded(potential_value, potential_trigger_multiword)
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
