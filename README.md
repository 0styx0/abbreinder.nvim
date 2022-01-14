### Table of Contents
+ [Usecase](#usecase)
+ [Installation](#installation)
+ [Commands](#commands)

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
    requires = {
        '0styx0/abbremand.nvim',
        module = 'abbremand' -- if want to lazy load
    },
    config = function()
        -- <config> can be empty to stay with defaults
        -- or anything can be changed, with anything unspecified
        -- retaining the default values
        require'abbreinder'.setup(<config>)
    end,
    event = 'BufRead', -- if want lazy load
}
```

----

##### Config

```lua
local config_defaults = {
    value_highlight = {
        enabled = true,
        group = 'Special', -- highlight to use
        time = 4000 -- -1 for permanent
    },
    tooltip = { -- only takes effect if output_as.tooltip = true
        enabled = true,
        time = 4000, -- time before tooltip closes
        opts = {}, -- see :help nvim_open_win
        highlight = {
            enabled = true,
            group = 'Special', -- highlight to use
        },
        format = function(trigger, value) -- format to print reminder in
            return 'abbrev: "' .. trigger .. '"->' .. '"' .. value .. '"'
        end,
    },
}
```
While the config here will most likely be kept up to date, feel free to check out [./lua/config.lua](./lua/config.lua) for the actual version.

---

### Commands

#### Vim
+ `:AbbreinderEnable`
+ `:AbbreinderDisable`

#### Lua
+ `require('abbreinder').enable()`
+ `require('abbreinder').disable()`

