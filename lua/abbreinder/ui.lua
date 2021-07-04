local api = vim.api;
local ui = {
  floating_win = -1,
}

local function open_window(abbreinder, text)

  ui.close_floating_win()

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
  ui.floating_win = api.nvim_open_win(buf, false, opts)
  api.nvim_buf_add_highlight(buf, -1, abbreinder.config.output.msg.highlight, 0, 0, -1)

  vim.defer_fn(ui.close_floating_win, abbreinder.config.output.floating_win.time_open)
end


function ui.close_floating_win()

  if api.nvim_win_is_valid(ui.floating_win) then
    api.nvim_win_close(ui.floating_win, true)
  end
end


function ui.output_reminder(abbreinder, key, val)

  local msg = abbreinder.config.output.msg.format(key, val)

  if abbreinder.config.output.as.floating_win then
    open_window(abbreinder, msg)
  end

  if (abbreinder.config.output.as.echo) then
    api.nvim_echo({{msg}}, {false}, {})
  end

end

return ui
