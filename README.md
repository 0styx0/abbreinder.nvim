
### Project Goal
I often come up with abbreviations that _should_ make typing faster, yet I often forget the shortcuts exist.
This dilemma especially comes up when I create abbreviations using Tim Pope's [vim-abolish](https://github.com/tpope/vim-abolish) - I create hundreds of abbreviations, but can't take full advantage of them.
Abbreinder works by notifying you when you've typed the expanded form of an abbreviation (either created through vanilla neovim's `abbrev` commands, or through `Abolish`. It is designed to be as configurable as possible, so these notifications may be displayed in a variety of ways, depending on how you specify.


### Installation

#### Packer: 
```lua
  use {
    'styx-meiseles/abbreinder.nvim',
    config = require('abbreinder').setup(<config>) -- <config> can be empty to stay with defaults
  }
```

#### Config
```lua
config_defaults = {
  source = vim.api.nvim_get_current_line, -- function called to obtain text to parse
  run_on = 'TextChangedI,TextChanged', -- autocmds to run plugin on
  output = {
    as = {
      echo = true,
      floating_win = true,
    },
    msg = {
      format = function(key, val) -- format to print reminder in
        return 'abbrev: "'..key..'"->'..'"'..val..'"'
      end,
      highlight = 'BlueItalic'
    },
    floating_win = { -- only takes effect if output_as.floating_win = true
      time_open = 5000, -- time before float closes
      opts = {} -- see :help nvim_open_win
    },
  },
}
```
While the config here will most likely be kept up to date, feel free to check out [./lua/abbreinder/config.lua](./lua/abbreinder/config.lua) for the actual version.

### Exports
+ Two autocmds are exported:
  + `AbbreinderAbbrExpanded`, called when an abbreviations is expanded (ie, used correctly)
  + `AbbreinderAbbrNotExpanded`, called when an abbreviation is _not_ expanded (ie, used _incorrectly_)


### Todo
+ Add `:help`
+ Add screenshots
