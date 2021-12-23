local api = vim.api

local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

local abbreinder = {
    _cache = {
        abbrevs = '',
        abbrev_map_value_trigger = {},
        multiword_abbrev_map = {},
    },
    _keylogger = '',
}


-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return two maps - {trigger, value} and for multiword abbrevs, {last_word_of_value, full_value}
function abbreinder._get_abbrevs_val_trigger()

    local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if (abbreinder._cache.abbrevs == abbrevs) then

        return abbreinder._cache.abbrev_map_value_trigger,
            abbreinder._cache.abbrev_map_multiword
    end
    abbreinder._cache.abbrevs = abbrevs

    -- using {last_word_of_value, full_value} instead of {trigger, value} because
    -- the user types the value, not the trigger
    local abbrev_map_value_trigger = {}

    -- multiword map only uses last word of multiword values for the key
    -- if that word is found, check full list for key/value
    local abbrev_map_multiword = {}

    for trigger, val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

        -- support for plugins such as vim-abolish, which adds prefix
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

    abbreinder._cache.abbrev_map_value_trigger = abbrev_map_value_trigger
    abbreinder._cache.abbrev_map_multiword = abbrev_map_multiword

    return abbrev_map_value_trigger, abbrev_map_multiword
end


-- @Summary checks if abbreviation functionality was used.
--   if value was manually typed, notify user
-- @return {-1, 0, 1} - if no abbreviation found (0), if user typed out the full value
--   instead of using trigger (0), if it was triggered properly (1)
function abbreinder._check_abbrev_remembered(trigger, value)

    local value_trigger = abbreinder._get_abbrevs_val_trigger()
    local abbr_exists = value_trigger[value] == trigger
    if (not abbr_exists) then
        return -1
    end

    local expanded_reg = vim.regex(trigger .. '[^[:keyword:]]' .. value)
    local abbr_remembered = expanded_reg:match_str(abbreinder._keylogger)

    if (abbr_remembered) then
        vim.cmd [[doautocmd User AbbreinderAbbrExpanded]]
        abbreinder._keylogger = ''
        return 1
    end

    local forgotten_reg = vim.regex(value .. '[^[:keyword:]]')
    local abbr_forgotten = forgotten_reg:match_str(abbreinder._keylogger)

    if (abbr_forgotten) then
        ui.output_reminder(abbreinder, trigger, value)
        vim.cmd [[doautocmd User AbbreinderAbbrNotExpanded]]
        abbreinder._keylogger = ''
        return 0
    end

    return -1
end


-- @Summary searches through what has been typed since the user last typed
-- an abbreviation-expanding character, to see if an abbreviation has been used
function abbreinder.find_abbrev()

    local cur_char = vim.v.char
    abbreinder._keylogger = abbreinder._keylogger .. cur_char
    local abbr_remembered = -1

    local keyword_regex = vim.regex('[[:keyword:]]')
    local not_trigger_char = keyword_regex:match_str(cur_char)
    if (not_trigger_char) then
        return abbr_remembered
    end

    local text_to_search = abbreinder._keylogger

    -- value + trigger char
    local value_regex = vim.regex('[[:keyword:]]\\+[^[:keyword:]]$')
    local val_start,val_end = value_regex:match_str(text_to_search)
    if val_start == nil then
        return -1
    end

    val_start = val_start + 1
    val_end = val_end - 1
    -- match_str doesn't support capture groups
    local potential_value = text_to_search:sub(val_start, val_end)

    local value_trigger, multiword_map = abbreinder._get_abbrevs_val_trigger()
    local potential_trigger = value_trigger[potential_value]

    local potential_multiword_abbrev = multiword_map[potential_value] ~= nil
    if (potential_multiword_abbrev) then
        local multi_value = multiword_map[potential_value]
        local multi_trigger = value_trigger[multi_value]
        abbr_remembered = abbreinder._check_abbrev_remembered(multi_trigger, multi_value)
        return abbr_remembered, multi_trigger, multi_value

    elseif (potential_trigger) then
        abbr_remembered = abbreinder._check_abbrev_remembered(potential_trigger, potential_value)
        return abbr_remembered, potential_trigger, potential_value
    end

    return abbr_remembered
end

local function create_commands()

    vim.cmd([[
    command! -bang AbbreinderEnable lua require('abbreinder').create_autocmds()
    command! -bang AbbreinderDisable autocmd! Abbreinder
    ]])
end

function abbreinder.clear_keylogger()
    -- doing this on bufread fixes bug where characters C> are part of keylogger string
    abbreinder._keylogger = ''
end

function abbreinder.create_autocmds()

    vim.cmd([[
    augroup Abbreinder
    autocmd!
    autocmd InsertCharPre * :lua require('abbreinder').find_abbrev()
    autocmd BufReadPre * :lua require('abbreinder').clear_keylogger()
    augroup END
    ]])
end


-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function abbreinder.setup(user_config)

    user_config = user_config or {}

    abbreinder.config = vim.tbl_extend('force', default_config, user_config)

    create_commands()
    abbreinder.create_autocmds()
end

return abbreinder
