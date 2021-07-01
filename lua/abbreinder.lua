local api = vim.api;

local default_config = require('abbreinder.config')

local abbreinder = {
  floating_win = -1,
  cache = {
    abbrevs = '',
    abbrev_map = '',
    source = '',
  },
  last_reminder = {
    index = '',
    key = ''
  },
  abbr = {
    triggered = false,
    key = '',
    val = ''
  }
}


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

  opts = vim.tbl_extend('force', opts, abbreinder.config.output.floating_win.opts)

  -- and finally create it with buffer attached
  abbreinder.floating_win = api.nvim_open_win(buf, false, opts)
  api.nvim_buf_add_highlight(buf, -1, abbreinder.config.output.msg.highlight, 0, 0, -1)

  vim.defer_fn(abbreinder.close_floating_win, abbreinder.config.output.floating_win.time_open)
end


function abbreinder.close_floating_win()

  if api.nvim_win_is_valid(abbreinder.floating_win) then
    api.nvim_win_close(abbreinder.floating_win, true)
  end
end


local function output_reminder(key, val)

    local msg = abbreinder.config.output.msg.format(key, val)

    if abbreinder.config.output.as.floating_win then
      open_window(msg)
    end

    if (abbreinder.config.output.as.echo) then
      api.nvim_echo({{msg}}, {false}, {})
    end

end


-- @Summary Parses neovim's list of abbrevations into a map
local function get_abbrevs()

  local abbrevs = api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

  if (abbreinder.cache.abbrevs == abbrevs) then
    return abbreinder.abbrev_map_cache
  end
  abbreinder.cache.abbrevs = abbrevs


  local abbrev_map = {}
  for key,val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do

    local vim_abolish_delim = '*@'
    local vim_abolish_escaped_val = val:gsub('^'..vim_abolish_delim, '')
    abbrev_map[key] = vim_abolish_escaped_val
  end
  abbreinder.abbrev_map_cache = abbrev_map

  return abbrev_map
end


function abbreinder.check()

  if abbreinder.abbr.triggered then
    output_reminder(abbreinder.abbr.key, abbreinder.abbr.val)
  end

  abbreinder.abbr.triggered = false
end

function abbreinder.did_abbrev_trigger()

  local text_to_search = abbreinder.config.source()
  local abbrev_map = get_abbrevs()

  -- fname = characters that expand abbreviations. see help abbreviations
  local cur_char_is_abbr_expanding = vim.fn.fnameescape(vim.v.char) ~= vim.v.char

  for potential_key in text_to_search:gmatch('%S+') do

    local abbr_key_typed = abbrev_map[potential_key] ~= nil
    if (abbr_key_typed and cur_char_is_abbr_expanding) then

      abbreinder.abbr.triggered = true
      abbreinder.abbr.key = potential_key
      abbreinder.abbr.val = abbrev_map[potential_key]
      -- print(potential_key..' triggered ')
      return
    end
  end
end


abbreinder.create_commands = function()

  vim.cmd [[command! Abbreinder            lua require('abbreinder').check()]]
  vim.cmd [[command! AbbreinderCheck       lua require('abbreinder').check()]]

  -- using BufEnter because BufLeave creates a new empty buffer for some reason
  vim.cmd([[
  augroup Abbreinder
  autocmd!
  " autocmd TextChanged * :echom 'TextChanged' getline('.')
  autocmd InsertCharPre * :lua require('abbreinder').did_abbrev_trigger()
  " autocmd CursorMovedI * :echom 'CursorMovedI' getline('.')
  autocmd ]]..abbreinder.config.run_on..[[ * :lua require('abbreinder').check(false)
  " autocmd     BufEnter                     * :lua require('abbreinder').close_floating_win()
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

