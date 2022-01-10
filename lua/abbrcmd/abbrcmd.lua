
local ns_name = 'abbrcmd'

-- note: nk = non-keyword (which can expand abbrevations. but can also be part of abbreviation values)
-- functions exposed for unit tests prefixed with _. else local, or part of `abbrcmd`
local abbrcmd = {
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
    _clients = {
        forgotten = {},
        remembered = {},
        on_change = {},
    },
    _enabled = false,
    -- [id] = {original_text, tooltip_id}
    _ext_data = {},
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
function abbrcmd._create_abbrev_maps()
    local abbrevs = vim.api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if abbrcmd._cache.abbrevs == abbrevs then
        return abbrcmd._cache.value_to_trigger, abbrcmd._cache.last_chunk_to_full_values
    end
    abbrcmd._cache.abbrevs = abbrevs

    local cur_val_to_trig = {}
    local cur_lchunk_to_vals = {}

    for trigger, value in abbrevs:gmatch('i%s%s(.-)%s%s*(.-)\n') do
        -- support for plugins such as vim-abolish, which adds prefix
        -- see :help map /can appear
        value = string.gsub(value, '^[*&@]+', '')

        local value_contains_non_keyword_pat = vim.regex('[^[:keyword:]]')
        local value_contains_non_keyword = value_contains_non_keyword_pat:match_str(value)
        if value_contains_non_keyword then
            cur_lchunk_to_vals = add_nk_containing_abbr(cur_lchunk_to_vals, value)
        end

        cur_val_to_trig[value] = trigger
    end

    abbrcmd._cache.value_to_trigger = cur_val_to_trig
    abbrcmd._cache.last_chunk_to_full_values = cur_lchunk_to_vals

    return cur_val_to_trig, cur_lchunk_to_vals
end

function abbrcmd.clear_keylogger()
    -- doing this on bufread fixes bug where characters C> are part of keylogger string
    abbrcmd._keylogger = ''
end

-- @Summary tracks backspacing. more complex than logic might initially seem
--   because on abbreviation expansion, vim backspaces the trigger.
--   so must differentiate between user vs expansion backspacing
local function handle_backspacing(backspace_typed)
    if backspace_typed then
        if abbrcmd._backspace_data.consecutive_backspaces == 0 then
            abbrcmd._backspace_data.saved_keylogger = abbrcmd._keylogger
            abbrcmd._backspace_data.potential_trigger = ''
        end

        abbrcmd._keylogger = abbrcmd._keylogger:sub(1, -2)
        abbrcmd._backspace_data.consecutive_backspaces = abbrcmd._backspace_data.consecutive_backspaces + 1
        return
    end

    if abbrcmd._backspace_data.consecutive_backspaces == 0 then
        return
    end

    -- when abbr expanded, it deletes the trigger
    -- so later in @see check_abbrev_remembered, compare with actual trigger
    abbrcmd._backspace_data.potential_trigger = string.sub(
        abbrcmd._backspace_data.saved_keylogger,
        #abbrcmd._backspace_data.saved_keylogger - abbrcmd._backspace_data.consecutive_backspaces + 1
    )

    abbrcmd._backspace_data.consecutive_backspaces = 0
    abbrcmd._backspace_data.saved_keylogger = ''
end

-- @return {boolean} if anything is using the plugin
local function has_subscribers()
    local clients = abbrcmd._clients
    return vim.tbl_count(clients.forgotten) > 0 or vim.tbl_count(clients.remembered) > 0
end

function abbrcmd.start()
    vim.api.nvim_buf_attach(0, false, {

        on_detach = abbrcmd.clear_keylogger,

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

            if not has_subscribers() then
                abbrcmd.disable()
                return true
            end

            -- if don't have this, then the nvim_buf_get_lines will throw out of bounds error
            -- even if not actually accessing an index of it, even though start_row is a valid index
            if vim.api.nvim_get_mode().mode ~= 'i' then
                -- allows for reminders to take into account normal mode changes
                -- using nvim_get_current_line gives out of bounds error for some reason
                abbrcmd._keylogger = vim.fn.getline('.')
                return false
            end

            local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, true)[1]

            local cur_char = line:sub(start_col + 1, start_col + 1)
            abbrcmd._keylogger = abbrcmd._keylogger .. cur_char

            local cursor_col = start_col + new_end_col
            local line_until_cursor = line:sub(0, cursor_col)

            local user_backspaced = cur_char == ''
                and new_end_col == old_end_col - 1
                and new_end_row == old_end_row
                and new_length == 0

            if user_backspaced then
                handle_backspacing(true)
            else
                abbrcmd._find_abbrev(cur_char, line_until_cursor)
                handle_backspacing(false)
            end
        end,
    })
end

-- @return value if val_after_nk points to abbr value, else false
function abbrcmd._contains_nk_abbr(text, val_after_nk)
    if not abbrcmd._cache.last_chunk_to_full_values[val_after_nk] then
        return false
    end

    local potential_values = abbrcmd._cache.last_chunk_to_full_values[val_after_nk]

    for _, value in ipairs(potential_values) do
        if abbrcmd._cache.value_to_trigger[value] and string.find(text, value, #text - #value, true) then
            return value
        end
    end

    return false
end

-- @Summary searches through what has been typed since the user last typed
-- an abbreviation-expanding character, to see if an abbreviation has been used
-- @return trigger, value. or -1 if not found
function abbrcmd._find_abbrev(cur_char, line_until_cursor)
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

    local value_to_trigger = abbrcmd._create_abbrev_maps()
    local potential_trigger = value_to_trigger[potential_value]

    -- potential_value only contains characters after last non-keyword char
    local nk_value = abbrcmd._contains_nk_abbr(line_until_cursor, potential_value)
    if nk_value then
        local nk_trigger = value_to_trigger[nk_value]
        abbrcmd._check_abbrev_remembered(nk_trigger, nk_value, line_until_cursor)
        return nk_trigger, nk_value
    elseif potential_trigger then
        abbrcmd._check_abbrev_remembered(potential_trigger, potential_value, line_until_cursor)
        return potential_trigger, potential_value
    end

    return -1
end

-- @return zero indexed {row, col, col_end} of value. assumes value ends at cursor pos
function abbrcmd._get_coordinates(value)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local line_num = row - 1
    local value_start = col - #value - 1
    local value_end = col - 1

    return {
	    row = line_num,
	    col = value_start,
	    col_end = value_end
    }
end

local function set_extmark(abbr_data)

    local ns_id = vim.api.nvim_create_namespace(ns_name)

    local ext_id = vim.api.nvim_buf_set_extmark(0, ns_id, abbr_data.row, abbr_data.col + 1, {
        end_col = abbr_data.col_end + 1,
    })

    abbrcmd._ext_data[ext_id] = {
        original_text = abbr_data.value,
        abbr_data = abbr_data,
    }

    return ext_id
end

function abbrcmd._monitor_abbrs()

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local ns_id = vim.api.nvim_create_namespace(ns_name)

    local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, { row - 1, 0 }, { row + 1, 0 }, { details = true })

    if vim.tbl_isempty(marks) then
        return
    end

    for _, value in ipairs(marks) do
        local ext_id, row, col, details = unpack(value)

        local line = vim.api.nvim_get_current_line()
        local ext_contents = string.sub(line, col + 1, details.end_col)

        local ext_data = abbrcmd._ext_data[ext_id]

        if ext_data.original_text ~= ext_contents then
            for _, callback in ipairs(abbrcmd._clients.on_change[ext_id]) do
                callback(ext_contents)
            end
            vim.api.nvim_buf_del_extmark(0, ns_id, ext_id)
        end
    end
end

local function trigger_callbacks(trigger, value, callbacks)

	local coordinates = abbrcmd._get_coordinates(value)
	local abbr = { trigger = trigger, value = value }
	local abbr_data = vim.tbl_extend('error', abbr, coordinates)

    local ext_id = set_extmark(abbr_data)
    abbrcmd._clients.on_change[ext_id] = {}


	abbr_data.on_change = function(change_callback)
        table.insert(abbrcmd._clients.on_change[ext_id], change_callback)
	end

    for key, callback in ipairs(callbacks) do
        local cb_result = callback(abbr_data)

        if cb_result == false then
            table.remove(callbacks, key)
        end
    end
end

-- @Summary checks if abbreviation functionality was used.
--   if value was manually typed, notify user
-- @return {-1, 0, 1} - if no abbreviation found (0), if user typed out the full value
--   instead of using trigger (0), if it was triggered properly (1)
function abbrcmd._check_abbrev_remembered(trigger, value, line_until_cursor)
    local value_trigger = abbrcmd._create_abbrev_maps()
    local abbr_exists = value_trigger[value] == trigger
    if not abbr_exists then
        return -1
    end

    local expanded_pat = vim.regex(trigger .. '[^[:keyword:]]' .. value)
    local abbr_remembered = expanded_pat:match_str(abbrcmd._keylogger)

    local expanded_midline_pat = vim.regex(trigger .. '[[:keyword:]]\\{' .. #trigger .. '}' .. value)
    local abbr_remembered_midline = expanded_midline_pat:match_str(abbrcmd._keylogger)

    if abbr_remembered or abbrcmd._backspace_data.potential_trigger == trigger or abbr_remembered_midline then
        abbrcmd.clear_keylogger()
        trigger_callbacks(trigger, value, abbrcmd._clients.remembered)
        abbrcmd._backspace_data.potential_trigger = ''
        return 1
    end

    local forgotten_pat = vim.regex(value .. '[^[:keyword:]]')
    local abbr_forgotten = forgotten_pat:match_str(line_until_cursor)

    local val_in_logger = string.find(abbrcmd._keylogger, value, 1, true)

    if abbr_forgotten and val_in_logger then
        abbrcmd.clear_keylogger()
        trigger_callbacks(trigger, value, abbrcmd._clients.forgotten)
        return 0
    end

    return -1
end

function abbrcmd.disable()
    -- setting this makes `nvim_buf_attach` return true,
    -- detaching from buffer and clearing keylogger
    -- @see abbrcmd.start
    abbrcmd._enabled = false
end

local function create_autocmds()

    vim.cmd[[
    augroup AbbrCmd
    autocmd!
    autocmd TextChanged,TextChangedI * :lua require('abbrcmd.abbrcmd')._monitor_abbrs()
    augroup END
    ]]
end

function abbrcmd.enable()
    abbrcmd.start()
    create_autocmds()
    abbrcmd._enabled = true
end

-- @param callback: function which will receive as arguments:
-- function({trigger, value, row, col, col_end, on_change})
--   as arguments when abbreviation was forgotten
--   on_change will be fired if value is modified later
-- If callback returns `false` it is unsubscribed from future forgotten events
function abbrcmd.on_abbr_forgotten(callback)
    if not abbrcmd._enabled then
        abbrcmd.enable()
    end
    table.insert(abbrcmd._clients.forgotten, callback)
end

-- @param callback: function which will receive as arguments:
-- function({trigger, value, row, col, col_end, on_change})
--   as arguments when abbreviation was expanded
--   on_change will be fired if value is modified later
-- If callback returns `false` it is unsubscribed from future remembered events
function abbrcmd.on_abbr_remembered(callback)
    if not abbrcmd._enabled then
        abbrcmd.enable()
    end
    table.insert(abbrcmd._clients.remembered, callback)
end

return abbrcmd
