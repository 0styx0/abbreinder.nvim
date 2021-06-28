local api = vim.api;

local default_config = require('abbreinder.config')

local abbreinder = {
  abbrev_cache = '',
  abbrev_map_cache = '',
  floating_win = -1,
  last_reminder = {
    index = '',
    key = ''
  }
}


function abbreinder.close_floating_win()

  if api.nvim_win_is_valid(abbreinder.floating_win) then
    api.nvim_win_close(abbreinder.floating_win, true)
  end
end

local function open_window(text)

  abbreinder.close_floating_win()

  local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buflisted', false)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_lines(buf, 0, -1, true, {text})
  api.nvim_buf_set_option(buf, 'modifiable', false)
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, nowait = true, noremap = true})

  local _, row, col = vim.fn.getcurpos()

  -- set some options
  local opts = {
    style = "minimal",
    relative = 'cursor',
    bufpos = {1, 0},
    anchor = 'SE',
    width = #text,
    height = 1,
    focusable = false,
    noautocmd = true,
    row = row,
    col = col,
  }

  -- and finally create it with buffer attached
  abbreinder.floating_win = api.nvim_open_win(buf, true, opts)
  api.nvim_buf_add_highlight(buf, -1, abbreinder.config.msg.highlight, 0, 0, -1)

  vim.api.nvim_command('wincmd w')

  vim.defer_fn(abbreinder.close_floating_win, abbreinder.config.float.time_open)
end


local function output_reminder(key, val)

    local msg = abbreinder.config.msg.format(key, val)

    if abbreinder.config.float.enabled then
      open_window(msg)
    else
      api.nvim_echo({{msg}}, {false}, {})
    end

end

-- @Summary Parses neovim's list of abbrevations into a map
local function get_abbrevs()

  local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

  if (abbreinder.abbrev_cache == abbrevs) then
    return abbreinder.abbrev_map_cache
  end
  abbreinder.abbrev_cache = abbrevs


  local abbrev_map = {}
  for key,val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

    local vim_abolish_delim = '*@'
    local vim_abolish_escaped_val = val:gsub('^'..vim_abolish_delim, '')
    abbrev_map[key] = vim_abolish_escaped_val
  end
  abbreinder.abbrev_map_cache = abbrev_map

  return abbrev_map
end

function Check_for_abbrev(duplicate_echos)

  duplicate_echos = duplicate_echos or true

  local text_to_search = abbreinder.config.source()
  local most_recent_abbr = { key = '', val = '', index = -1 }
  local abbrev_map = get_abbrevs()

  -- loop through each abbr, check if it's in `text_to_search`
  -- if there's multiple appearances of the same abbr, use the most recent one
  for key,val in pairs(abbrev_map) do

    local last_match_idx = 0

    repeat

      local abbrev_index = text_to_search:find(val, last_match_idx)

      if abbrev_index ~= nil then

	if (abbrev_index > most_recent_abbr.index) then
	  most_recent_abbr.index = abbrev_index
	  most_recent_abbr.key = key
	  most_recent_abbr.val = val
	end

	last_match_idx = abbrev_index + 1
      end

    until abbrev_index == nil

  end

  -- don't give the same correction twice in a row. annoying
  if (most_recent_abbr.key == abbreinder.last_reminder.key) then return end

  if most_recent_abbr.index ~= -1 and
    (duplicate_echos or abbreinder.last_reminder.index ~= most_recent_abbr.index)
  then

    abbreinder.last_reminder.index = most_recent_abbr.index

    output_reminder(most_recent_abbr.key, most_recent_abbr.val)

    abbreinder.last_reminder.key = most_recent_abbr.key
  end
end


abbreinder.check = Check_for_abbrev;

abbreinder.create_commands = function()

  vim.cmd [[command! Abbreinder            lua require('abbreinder').check()]]
  vim.cmd [[command! AbbreinderCheck       lua require('abbreinder').check()]]

  -- using BufEnter because BufLeave creates a new empty buffer for some reason
  vim.cmd([[
  augroup Abbreinder
  autocmd!
  autocmd ]]..abbreinder.config.run_on..[[ * :lua require('abbreinder').check(false)
  autocmd ]]..abbreinder.config.run_on..[[ * :lua require('abbreinder').check(false)
  autocmd     BufEnter                     * :lua require('abbreinder').close_floating_win()
  augroup END
  ]])

end

-- autocmd ]]..abbreinder.config.run_on..[[ * :lua vim.api.nvim_buf_call(0, Check_for_abbrev)

-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function abbreinder.setup(user_config)

  user_config = user_config or {}

  abbreinder.config = vim.tbl_extend('force', default_config, user_config)

  abbreinder.create_commands()
end

return abbreinder
