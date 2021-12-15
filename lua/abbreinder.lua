local api = vim.api;

local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

local abbreinder = {
    cache = {
        abbrevs = '',
        abbrev_map_key_value = '',
        abbrev_map_value_key = '',
        saved = ''
    }
}


-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
local function get_abbrevs()

    local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if (abbreinder.cache.abbrevs == abbrevs) then
        return abbreinder.cache.abbrev_map_key_value
    end
    abbreinder.cache.abbrevs = abbrevs


    local abbrev_map_key_value = {}
    local abbrev_map_value_key = {}

    for key,val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

        local vim_abolish_delim = '*@'
        local vim_abolish_escaped_val = val:gsub('^'..vim_abolish_delim, '')
        abbrev_map_key_value[key] = vim_abolish_escaped_val
        abbrev_map_value_key[vim_abolish_escaped_val] = key
        -- if key == 'abbr' then print ('abbr find') end
    end
    abbreinder.cache.abbrev_map_key_value = abbrev_map_key_value
    abbreinder.cache.abbrev_map_value_key = abbrev_map_value_key

    return abbrev_map_key_value
end



local function checkPastTypings(key)

    get_abbrevs()

    local value = abbreinder.cache.abbrev_map_key_value[key]

    if (key == nil or value == nil) then
        return
    end

    -- format of saved will be `randomWords key value` for expanded abbreviation
    -- or `randomWords value` for unexpanded
    local expanded_abbr_start = abbreinder.cache.saved:find(key .. ' ' .. value)

    if (expanded_abbr_start ~= nil) then
        print('expanded found')
        vim.cmd [[doautocmd User AbbreinderAbbrExpanded]]
        abbreinder.cache.saved = ''
        return
    end

    local unexpanded_abbr_start = abbreinder.cache.saved:find(value)
    if (unexpanded_abbr_start ~= nil) then
        print('unexpanded found')
        vim.cmd [[doautocmd User AbbreinderAbbrUnexpanded]]
        abbreinder.cache.saved = ''
    end
end

function abbreinder.did_abbrev_trigger()


    abbreinder.cache.saved = abbreinder.cache.saved .. vim.v.char

    -- fname = characters that expand abbreviations.
    local cur_char_is_abbr_expanding = vim.fn.fnameescape(vim.v.char) ~= vim.v.char
    if (not cur_char_is_abbr_expanding) then
        return
    end


    local text_to_search = abbreinder.config.source()

    local word_start, word_end = text_to_search:find('%S+')
    while word_start ~= nil do

        local potential_key = text_to_search:sub(word_start, word_end)
        checkPastTypings(abbreinder.cache.abbrev_map_value_key[potential_key])

        word_start, word_end = text_to_search:find('%S+', word_end + 1)
    end
end



abbreinder.create_commands = function()

    vim.cmd([[
        augroup Abbreinder
            autocmd!
            autocmd InsertCharPre * :lua require('abbreinder').did_abbrev_trigger()
        augroup END
    ]])

end


-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function abbreinder.setup(user_config)

    -- print('hello -abbrs')
    user_config = user_config or {}

    abbreinder.config = vim.tbl_extend('force', default_config, user_config)

    abbreinder.create_commands()
end

return abbreinder
