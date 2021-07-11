local api = vim.api;

local default_config = require('abbreinder.config')
local ui = require('abbreinder.ui')

local abbreinder = {
  cache = {
    abbrevs = '',
    abbrev_map = '',
    source = '',
  },
  abbr = {
    triggered = false,
    key = '',
    val = '',
    start_idx = -1,
    unexpanded = false
  }
}


-- @Summary Parses neovim's list of abbrevations into a map
local function get_abbrevs()

  local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

  if (abbreinder.cache.abbrevs == abbrevs) then
    return abbreinder.cache.abbrev_map
  end
  abbreinder.cache.abbrevs = abbrevs


  local abbrev_map = {}
  for key,val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

    local vim_abolish_delim = '*@'
    local vim_abolish_escaped_val = val:gsub('^'..vim_abolish_delim, '')
    abbrev_map[key] = vim_abolish_escaped_val
    -- if key == 'abbr' then print ('abbr find') end
  end
  abbreinder.cache.abbrev_map = abbrev_map

  return abbrev_map
end


function abbreinder.check()

  if abbreinder.abbr.triggered then
    vim.cmd [[doautocmd User AbbreinderAbbrExpanded]]
    -- print 'triggered'
  end

  if not abbreinder.abbr.triggered and abbreinder.abbr.key ~= '' then

    local text_to_search = abbreinder.config.source()
    -- print('unexpanded: '..abbreinder.abbr.key..' val: '..abbreinder.abbr.val)

    if text_to_search:find(abbreinder.abbr.val..' ', abbreinder.abbr.start_idx) ~= nil then

      ui.output_reminder(abbreinder, abbreinder.abbr.key, abbreinder.abbr.val)
      vim.cmd [[doautocmd User AbbreinderAbbrNotExpanded]]
    end
  end

  abbreinder.abbr.triggered = false
  abbreinder.abbr.unexpanded = false
  abbreinder.abbr.key = ''
  abbreinder.abbr.start_idx = -1
end

function abbreinder.did_abbrev_trigger()

  local text_to_search = abbreinder.config.source()
  local abbrev_map = get_abbrevs()
  -- print(abbrev_map['abbr'])

  -- print('did_trg: '..abbreinder.abbr.key)
  -- fname = characters that expand abbreviations. see :help abbreviations
  local cur_char_is_abbr_expanding = vim.fn.fnameescape(vim.v.char) ~= vim.v.char

  -- get the start/end indices of abbr. so later can tell if abbr expanded or not
  local start_idx, end_idx = text_to_search:find('%S+')

  while start_idx ~= nil do

    local potential_key = text_to_search:sub(start_idx, end_idx)
  --for potential_key in text_to_search:gmatch('%S+') do

    -- if key typed previously, but now not expanding character
    local abbr_key_typed = abbrev_map[potential_key] ~= nil

    if abbr_key_typed then
      abbreinder.abbr.key = potential_key
      abbreinder.abbr.val = abbrev_map[potential_key]
      abbreinder.abbr.start_idx = start_idx
    end

    if abbr_key_typed and cur_char_is_abbr_expanding then
      abbreinder.abbr.triggered = true
    end

    start_idx, end_idx = text_to_search:find('%S+', end_idx + 1)
  end
end


abbreinder.create_commands = function()

  vim.cmd([[
  augroup Abbreinder
    autocmd!
    autocmd InsertCharPre * :lua require('abbreinder').did_abbrev_trigger()
    autocmd ]]..abbreinder.config.run_on..[[ * :lua require('abbreinder').check()
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

