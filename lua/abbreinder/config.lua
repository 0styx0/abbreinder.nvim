
local config_defaults = {
  source = vim.api.nvim_get_current_line, -- function called to obtain text to parse
  run_on = 'CursorMovedI,TextChanged', -- autocmds to run plugin on
  float = {
    enabled = true, -- false => echo command output
    time_open = 5000, -- time before float closes
    opts = {} -- see :help nvim_open_win
  },
  msg = {
    format = function(key, val) -- format to print reminder in
      return 'abbrev: "'..key..'"->'..'"'..val..'"'
    end,
    highlight = 'BlueItalic'
  }
}

return config_defaults
