
local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

-- note: nk = non-keyword (which can expand abbrevations. but can also be part of abbreviation values)
local abbreinder = {
    _cache = {
        abbrevs = '',
        abbrev_map_value_trigger = {},
        -- multiword map only uses last word of multiword values for the key
        -- if that word is found, check full list for key/value
        abbrev_map_multiword = {},
    },
    _keylogger = '',
    _should_stop = false,
}

-- @param trigger, value - of an abbreviation whose value contains a non-keyword char
-- @return updated abbreinder._cache.abbrev_map_multiword
local function add_nk_containing_abbr(map_nk_val, value)

    local val_after_non_keyword_reg = vim.regex('[[:keyword:]]\\+$')
    local val_after_nk_start, val_after_nk_end = val_after_non_keyword_reg:match_str(value)

    local val_is_only_one_char_and_is_nk_keyword = not val_after_nk_start
    if val_is_only_one_char_and_is_nk_keyword then

        if not map_nk_val[''] then
            map_nk_val[''] = {}
        end
        table.insert(map_nk_val[''], value)
        return map_nk_val
    end

    val_after_nk_start = val_after_nk_start + 1

    local val_after_nk = value:sub(val_after_nk_start, val_after_nk_end)

    if (not map_nk_val[val_after_nk]) then
        map_nk_val[val_after_nk] = {}
    end

    table.insert(map_nk_val[val_after_nk], value)

    return map_nk_val
end

-- @return value if val_after_nk points to value of an abbreviation, else false
function abbreinder._contains_nk_abbr(text, val_after_nk)

    if not abbreinder._cache.abbrev_map_multiword[val_after_nk] then
        return false
    end

    local potential_values = abbreinder._cache.abbrev_map_multiword[val_after_nk]

    for _,value in ipairs(potential_values) do
        if abbreinder._cache.abbrev_map_value_trigger[value] and
            string.find(text, value, #text - #value, true)
        then
            return value
        end
    end

    return false
end

-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return two maps - {trigger, value} and for multiword abbrevs, {last_word_of_value, full_value}
function abbreinder._get_abbrevs_val_trigger()

    local abbrevs = vim.api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if (abbreinder._cache.abbrevs == abbrevs) then

        return abbreinder._cache.abbrev_map_value_trigger,
            abbreinder._cache.abbrev_map_multiword
    end
    abbreinder._cache.abbrevs = abbrevs

    -- using {last_word_of_value, full_value} instead of {trigger, value} because
    -- the user types the value, not the trigger
    local abbrev_map_value_trigger = {}
    local map_nk_val = {}

    for trigger, value in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

        -- support for plugins such as vim-abolish, which adds prefix
        for _, prefix in ipairs(abbreinder.config.value_prefixes) do
            value = value:gsub('^'..prefix, '')
        end

        -- support for values which contain keywords
        local value_contains_non_keyword_reg = vim.regex('[^[:keyword:]]')
        local value_contains_non_keyword = value_contains_non_keyword_reg:match_str(value)
        if (value_contains_non_keyword) then
            map_nk_val = add_nk_containing_abbr(map_nk_val, value)
        end

        abbrev_map_value_trigger[value] = trigger
    end

    abbreinder._cache.abbrev_map_value_trigger = abbrev_map_value_trigger
    abbreinder._cache.abbrev_map_multiword = map_nk_val

    -- map_multi updated @see by add_nk_containing_abbr
    return abbrev_map_value_trigger, abbreinder._cache.abbrev_map_multiword
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
function abbreinder.find_abbrev(cur_char)

    abbreinder._keylogger = abbreinder._keylogger .. cur_char
    local abbr_remembered = -1

    local keyword_regex = vim.regex('[[:keyword:]]')
    local not_trigger_char = keyword_regex:match_str(cur_char)
    if (not_trigger_char) then
        return abbr_remembered
    end

    local text_to_search = abbreinder._keylogger

    -- value + trigger char
    local value_regex = vim.regex('[[:keyword:]]\\+[^[:keyword:]]\\+$')
    local val_start,val_end = value_regex:match_str(text_to_search)
    if val_start == nil then
        return -1
    end

    val_start = val_start + 1
    val_end = val_end - 1
    -- match_str doesn't support capture groups
    local potential_value = text_to_search:sub(val_start, val_end)

    local value_trigger = abbreinder._get_abbrevs_val_trigger()
    local potential_trigger = value_trigger[potential_value]

    -- potential_value would only be character after last non-keyword char
    local nk_value = abbreinder._contains_nk_abbr(text_to_search, potential_value)
    if (nk_value) then
        local multi_trigger = value_trigger[nk_value]
        abbr_remembered = abbreinder._check_abbrev_remembered(multi_trigger, nk_value)
        return abbr_remembered, multi_trigger, nk_value

    elseif (potential_trigger) then
        abbr_remembered = abbreinder._check_abbrev_remembered(potential_trigger, potential_value)
        return abbr_remembered, potential_trigger, potential_value
    end

    return abbr_remembered
end


function abbreinder.start()

    vim.api.nvim_buf_attach(0, false, {

        on_detach = abbreinder.clear_keylogger,

        on_bytes = function(byte_str, buf, changed_tick, start_row, start_col, byte_offset, old_end_row, old_end_col, old_length, new_end_row, new_end_col, new_length)

            if abbreinder._should_stop then
                return true
            end

            -- if don't have this, then the nvim_buf_get_lines will throw out of bounds error
            -- even if not actually accessing an index of it, and start_row is a valid index
            if vim.fn.mode() ~= 'i' then
                return false
            end

            local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, true)[1]
            local cur_char = line:sub(start_col + 1, start_col + 1)

            local user_backspaced = new_end_col == old_end_col - 1 and
                new_end_row == old_end_row and new_length == 0
            if user_backspaced then
                abbreinder._keylogger = abbreinder._keylogger:sub(1, -2)
            else
                abbreinder.find_abbrev(cur_char)
            end
        end
    })
end

function abbreinder.clear_keylogger()
    -- doing this on bufread fixes bug where characters C> are part of keylogger string
    abbreinder._keylogger = ''
end

local function create_ex_commands()

    vim.cmd([[
    command! -bang AbbreinderEnable lua require('abbreinder').enable()
    command! -bang AbbreinderDisable lua require('abbreinder').disable()
    ]])
end


function abbreinder.create_autocmds()

    vim.cmd([[
    augroup Abbreinder
    autocmd!
    autocmd BufReadPre * :lua require('abbreinder').clear_keylogger()
    autocmd BufReadPre * :lua require('abbreinder').start()
    augroup END
    ]])
end

function abbreinder.remove_autocmds()

    vim.cmd([[
    command! -bang AbbreinderDisable autocmd! Abbreinder
    ]])
end

function abbreinder.disable()
    -- setting this makes `nvim_buf_attach` return true,
    -- detaching from buffer and clearing keylogger
    -- @see abbreinder.start
    abbreinder._should_stop = true
end

function abbreinder.enable()
    abbreinder._should_stop = false
    create_ex_commands()
    abbreinder.create_autocmds()
    abbreinder.start()
end


-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function abbreinder.setup(user_config)

    user_config = user_config or {}

    abbreinder.config = vim.tbl_extend('force', default_config, user_config)
    abbreinder.enable()
end

return abbreinder
