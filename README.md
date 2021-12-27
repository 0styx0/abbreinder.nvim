### Table of Contents
+ [Usecase](#usecase)
+ [Installation](#installation)
+ [Commands](#commands)
+ [Exports](#exports)

Note: This plugin is now in "beta". I'm adding nice to have features before release (at which point the plugin will be at a point where it should always be stable to use). If you happen to stumble upon this and find a bug, please raise an issue letting me know.

---

### Usecase
I often come up with abbreviations that _should_ make typing faster, but I also forget they exist.
This dilemma especially comes up when I create abbreviations using Tim Pope's [vim-abolish](https://github.com/tpope/vim-abolish) - I create hundreds of abbreviations, but can't take full advantage of them. To solve this, Abbreinder works by notifying you when you've typed the expanded form of an abbreviation instead of using the abbreviation functionality.


#### Usage
+ Define abbreviations (eg, `iabbrev nvim Neovim`, `iabbrev rsvp Répondez, s'il vous plait`, `Abolish alg{,s,y} algorithm{,s,ically}`)
+ Start typing
+ If you type an abbreviation's value (eg, `Neovim`) instead of using the trigger, you will get a message reminding you of the abbreviation

---

### Installation

#### Packer:
```lua
  use {
    '0styx0/abbreinder.nvim',
    -- <config> can be empty to stay with defaults
    -- or anything can be changed, with anything unspecified
    -- retaining the default values
    config = function() require'abbreinder'.setup(<config>) end
  }
```

----

##### Config
```lua
config_defaults = {
  output = {
    as = {
      echo = false,
      tooltip = true,
    },
    msg = {
      format = function(key, val) -- format to print reminder in
        return 'abbrev: "'..key..'"->'..'"'..val..'"'
      end,
      highlight = 'Special', -- highlight to use
      -- if want highlight to stop after x ms. -1 for permanent highlight
      highlight_time = 4000
    },
    tooltip = { -- only takes effect if output_as.tooltip = true
      time_open = 4000, -- time before tooltip closes
      opts = {}, -- see :help nvim_open_win
      highlight = 'Special'
    },
  },
  -- vim-abolish prefixes each abbreviation value.
  -- adding prefixes here accounts for them
  value_prefixes = {'*@'}
}
```
While the config here will most likely be kept up to date, feel free to check out [./lua/abbreinder/config.lua](./lua/abbreinder/config.lua) for the actual version.

---

### Commands
+ `:AbbreinderEnable`
+ `:AbbreinderDisable`

---

### Exports
+ Two autocmds are exported:
  + `AbbreinderAbbrExpanded`, called when an abbreviations is expanded (ie, used correctly)
  + `AbbreinderAbbrNotExpanded`, called when an abbreviation is _not_ expanded (ie, abbreviation functionality was not used)


