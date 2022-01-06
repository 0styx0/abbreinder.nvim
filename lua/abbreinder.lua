local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

-- note: nk = non-keyword (which can expand abbrevations. but can also be part of abbreviation values)
-- functions exposed for unit tests prefixed with _. else local, or part of `abbreinder`
local abbreinder = {
    _cache = {
        -- to check if must update the maps
        abbrevs = '',
        -- tracks all values containing keyword chars, to be treated differently
        -- [last_chunk_of_value] = {full_val_i}
        last_chunk_to_full_values = {},
        -- tracks all abbreviations
        -- [full_value] = trigger
        value_to_trigger = {},
    },
    _keylogger = '',
    _backspace_data = {
        consecutive_backspaces = 0,
        saved_keylogger = '',
        potential_trigger = '',
    },
    _should_stop = false,
}

-- @param value - containing at least one non-keyword character
-- @return updated last_chunk_to_full_values
local function add_nk_containing_abbr(map_nk_val, value)
    local val_after_non_keyword_pat = vim.regex('[[:keyword:]]\\+$')
    local val_after_nk_start, val_after_nk_end = val_after_non_keyword_pat:match_str(value)

    local val_is_only_one_char_and_is_nk_keyword = not val_after_nk_start
    if val_is_only_one_char_and_is_nk_keyword then
        -- must be {} because last chunk could be common
        if not map_nk_val[''] then
            map_nk_val[''] = {}
        end
        table.insert(map_nk_val[''], value)

        return map_nk_val
    end

    val_after_nk_start = val_after_nk_start + 1

    local val_after_nk = value:sub(val_after_nk_start, val_after_nk_end)

    if not map_nk_val[val_after_nk] then
        map_nk_val[val_after_nk] = {}
    end
    table.insert(map_nk_val[val_after_nk], value)

    return map_nk_val
end

-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return {[trigger] = value} and {[last_word_of_value_containing_keyword] = {full_values}}
function abbreinder._create_abbrev_maps()
    local abbrevs = vim.api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if abbreinder._cache.abbrevs == abbrevs then
        return abbreinder._cache.value_to_trigger, abbreinder._cache.last_chunk_to_full_values
    end
    abbreinder._cache.abbrevs = abbrevs

    local cur_val_to_trig = {}
    local cur_lchunk_to_vals = {}

    for trigger, value in abbrevs:gmatch('i%s%s(.-)%s%s*(.-)\n') do
        -- support for plugins such as vim-abolish, which adds prefix
        for _, prefix in ipairs(abbreinder.config.value_prefixes) do
            value = value:gsub('^' .. prefix, '')
        end

        local value_contains_non_keyword_pat = vim.regex('[^[:keyword:]]')
        local value_contains_non_keyword = value_contains_non_keyword_pat:match_str(value)
        if value_contains_non_keyword then
            cur_lchunk_to_vals = add_nk_containing_abbr(cur_lchunk_to_vals, value)
        end

        cur_val_to_trig[value] = trigger
    end

    abbreinder._cache.value_to_trigger = cur_val_to_trig
    abbreinder._cache.last_chunk_to_full_values = cur_lchunk_to_vals

    return cur_val_to_trig, cur_lchunk_to_vals
end

function abbreinder.clear_keylogger()
    -- doing this on bufread fixes bug where characters C> are part of keylogger string
    abbreinder._keylogger = ''
end

-- @Summary tracks backspacing. more complex than logic might initially seem
--   because on abbreviation expansion, vim backspaces the trigger.
--   so must differentiate between user vs expansion backspacing
local function handle_backspacing(backspace_typed)
    if backspace_typed then
        if abbreinder._backspace_data.consecutive_backspaces == 0 then
            abbreinder._backspace_data.saved_keylogger = abbreinder._keylogger
            abbreinder._backspace_data.potential_trigger = ''
        end

        abbreinder._keylogger = abbreinder._keylogger:sub(1, -2)
        abbreinder._backspace_data.consecutive_backspaces = abbreinder._backspace_data.consecutive_backspaces + 1
        return
    end

    if abbreinder._backspace_data.consecutive_backspaces == 0 then
        return
    end

    -- when abbr expanded, it deletes the trigger
    -- so later in @see check_abbrev_remembered, compare with actual trigger
    abbreinder._backspace_data.potential_trigger = string.sub(
        abbreinder._backspace_data.saved_keylogger,
        #abbreinder._backspace_data.saved_keylogger - abbreinder._backspace_data.consecutive_backspaces + 1
    )

    abbreinder._backspace_data.consecutive_backspaces = 0
    abbreinder._backspace_data.saved_keylogger = ''
end

function abbreinder.start()
    vim.api.nvim_buf_attach(0, false, {

        on_detach = abbreinder.clear_keylogger,

        on_bytes = function(
            byte_str,
            buf,
            changed_tick,
            start_row,
            start_col,
            byte_offset,
            old_end_row,
            old_end_col,
            old_length,
            new_end_row,
            new_end_col,
            new_length
        )
            if abbreinder._should_stop then
                return true
            end

            -- if don't have this, then the nvim_buf_get_lines will throw out of bounds error
            -- even if not actually accessing an index of it, even though start_row is a valid index
            if vim.fn.mode() ~= 'i' then
                -- allows for reminders to take into account normal mode changes
                abbreinder._keylogger = vim.fn.getline('.')
                return false
            end

            local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, true)[1]

            local cur_char = line:sub(start_col + 1, start_col + 1)
            abbreinder._keylogger = abbreinder._keylogger .. cur_char

            local cursor_col = start_col + new_end_col
            local line_until_cursor = line:sub(0, cursor_col)

            local user_backspaced = cur_char == ''
                and new_end_col == old_end_col - 1
                and new_end_row == old_end_row
                and new_length == 0

            if user_backspaced then
                handle_backspacing(true)
            else
                abbreinder._find_abbrev(cur_char, line_until_cursor)
                handle_backspacing(false)
            end
        end,
    })
end

-- @return value if val_after_nk points to abbr value, else false
function abbreinder._contains_nk_abbr(text, val_after_nk)
    if not abbreinder._cache.last_chunk_to_full_values[val_after_nk] then
        return false
    end

    local potential_values = abbreinder._cache.last_chunk_to_full_values[val_after_nk]

    for _, value in ipairs(potential_values) do
        if abbreinder._cache.value_to_trigger[value] and string.find(text, value, #text - #value, true) then
            return value
        end
    end

    return false
end

-- @Summary searches through what has been typed since the user last typed
-- an abbreviation-expanding character, to see if an abbreviation has been used
-- @return trigger, value. or -1 if not found
function abbreinder._find_abbrev(cur_char, line_until_cursor)
    local keyword_regex = vim.regex('[[:keyword:]]')
    local not_trigger_char = keyword_regex:match_str(cur_char)

    if not_trigger_char then
        return -1
    end

    local value_regex = vim.regex('[[:keyword:]]\\+[^[:keyword:]]\\+$')
    local val_start, val_end = value_regex:match_str(line_until_cursor)
    if not val_start then
        return -1
    end

    val_start = val_start + 1
    val_end = val_end - 1
    local potential_value = line_until_cursor:sub(val_start, val_end)

    local value_to_trigger = abbreinder._create_abbrev_maps()
    local potential_trigger = value_to_trigger[potential_value]

    -- potential_value only contains characters after last non-keyword char
    local nk_value = abbreinder._contains_nk_abbr(line_until_cursor, potential_value)
    if nk_value then
        local nk_trigger = value_to_trigger[nk_value]
        abbreinder._check_abbrev_remembered(nk_trigger, nk_value, line_until_cursor)
        return nk_trigger, nk_value
    elseif potential_trigger then
        abbreinder._check_abbrev_remembered(potential_trigger, potential_value, line_until_cursor)
        return potential_trigger, potential_value
    end

    return -1
end

-- @Summary checks if abbreviation functionality was used.
--   if value was manually typed, notify user
-- @return {-1, 0, 1} - if no abbreviation found (0), if user typed out the full value
--   instead of using trigger (0), if it was triggered properly (1)
function abbreinder._check_abbrev_remembered(trigger, value, line_until_cursor)
    local value_trigger = abbreinder._create_abbrev_maps()
    local abbr_exists = value_trigger[value] == trigger
    if not abbr_exists then
        return -1
    end

    local expanded_pat = vim.regex(trigger .. '[^[:keyword:]]' .. value)
    local abbr_remembered = expanded_pat:match_str(abbreinder._keylogger)

    local expanded_midline_pat = vim.regex(trigger .. '[[:keyword:]]\\{' .. #trigger .. '}' .. value)
    local abbr_remembered_midline = expanded_midline_pat:match_str(abbreinder._keylogger)

    if abbr_remembered or abbreinder._backspace_data.potential_trigger == trigger or abbr_remembered_midline then
        abbreinder.clear_keylogger()
        vim.cmd([[doautocmd User AbbreinderAbbrExpanded]])
        abbreinder._backspace_data.potential_trigger = ''

        return 1
    end

    local forgotten_pat = vim.regex(value .. '[^[:keyword:]]')
    local abbr_forgotten = forgotten_pat:match_str(line_until_cursor)

    local val_in_logger = string.find(abbreinder._keylogger, value, 1, true)

    if abbr_forgotten and val_in_logger then
        abbreinder.clear_keylogger()
        vim.cmd([[doautocmd User AbbreinderAbbrNotExpanded]])

        if #trigger ~= #value then
            ui.output_reminder(abbreinder, trigger, value)
        end

        return 0
    end

    return -1
end

local function create_ex_commands()
    vim.cmd([[
    command! -bang AbbreinderEnable lua require('abbreinder').enable()
    command! -bang AbbreinderDisable lua require('abbreinder').disable()
    ]])
end

local function create_autocmds()
    vim.cmd([[
    augroup Abbreinder
    autocmd!
    autocmd BufNewFile,BufReadPre * :lua require('abbreinder').clear_keylogger()
    autocmd BufNewFile,BufReadPre * :lua require('abbreinder').start()
    augroup END
    ]])
end

local function remove_autocmds()
    vim.cmd([[
    command! -bang AbbreinderDisable autocmd! Abbreinder
    ]])
end

function abbreinder.disable()
    -- setting this makes `nvim_buf_attach` return true,
    -- detaching from buffer and clearing keylogger
    -- @see abbreinder.start
    abbreinder._should_stop = true
    remove_autocmds()
end

function abbreinder.enable()
    abbreinder._should_stop = false
    create_ex_commands()
    create_autocmds()
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
