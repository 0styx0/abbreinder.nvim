
local config_defaults = {
  output = {
    as = {
      echo = true,
      floating_win = true,
    },
    msg = {
      format = function(key, val) -- format to print reminder in
        return 'abbrev: "'..key..'"->'..'"'..val..'"'
      end,
      highlight = 'Special',
      highlight_time = 5000 -- if want highlight to stop after x ms. -1 for permanent highlight
    },
    floating_win = { -- only takes effect if output_as.floating_win = true
      time_open = 5000, -- time before float closes
      opts = {}, -- see :help nvim_open_win
      highlight = 'Special'
    },
  },
  value_prefixes = {'*@'} -- vim-abolish prefixes each abbreviation value
}

return config_defaults
