local api = vim.api;
local ui = {
  floating_win = {},
}

local function open_window(abbreinder, text)

  local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buflisted', false)
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_lines(buf, 0, -1, true, {text})
  api.nvim_buf_set_option(buf, 'modifiable', false)
  api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, nowait = true, noremap = true})

  local pos = vim.fn.getpos('.')
  local line = pos[2]
  local col = pos[3]

  -- set some options
  local opts = {
    style = 'minimal',
    relative = 'win',
    anchor = 'SE',
    width = #text,
    height = 1,
    focusable = false,
    noautocmd = true,
    --bufpos = {line, col},
    row = line - 1,
    col = col,
    -- border = 'solid',
  }

  opts = vim.tbl_extend('force', opts, abbreinder.config.output.floating_win.opts)

  -- and finally create it with buffer attached
  local id = api.nvim_open_win(buf, false, opts)
  api.nvim_buf_add_highlight(buf, -1, abbreinder.config.output.floating_win.highlight, 0, 0, -1)

  vim.defer_fn(function() ui.close_floating_win(id) end, abbreinder.config.output.floating_win.time_open)
end


function ui.close_floating_win(win_id)

  if api.nvim_win_is_valid(win_id) then
    api.nvim_win_close(win_id, true)
  end
end


local function highlight_unexpanded_abbr(abbreinder)

  local line = vim.fn.getpos('.')[2]
  local abbr_hl = vim.fn.matchaddpos(abbreinder.config.output.msg.highlight, {{line, abbreinder.abbr.start_idx, #abbreinder.abbr.val}})

  if abbreinder.config.output.msg.highlight_time ~= -1 then
    vim.defer_fn(function() vim.fn.matchdelete(abbr_hl) end, abbreinder.config.output.msg.highlight_time)
  end
end


function ui.output_reminder(abbreinder, key, val)

  local msg = abbreinder.config.output.msg.format(key, val)

  highlight_unexpanded_abbr(abbreinder)

  if abbreinder.config.output.as.floating_win then
    open_window(abbreinder, msg)
  end

  if (abbreinder.config.output.as.echo) then
    api.nvim_echo({{msg}}, {false}, {})
  end

end

return ui
