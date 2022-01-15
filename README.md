### Table of Contents
+ [Usecase](#usecase)
+ [Installation](#installation)
+ [Features](#features)
+ [Commands](#commands)

---

### Usecase
I often come up with abbreviations that _should_ make typing faster, but then I forget they exist.
This dilemma especially comes up when I create abbreviations using Tim Pope's [vim-abolish](https://github.com/tpope/vim-abolish) - I create hundreds of abbreviations, but can't take full advantage of them. To solve this, Abbreinder works by notifying you when you've typed the expanded form of an abbreviation instead of using the abbreviation functionality.


#### Usage
+ Define abbreviations (eg, `iabbrev nvim Neovim`, `iabbrev rsvp Répondez, s'il vous plait`, `Abolish alg{,s,y} algorithm{,s,ically}`)
+ Start typing
+ If you type an abbreviation's value (eg, `Neovim`) instead of using the trigger, you will get a message reminding you of the abbreviation

![Plugin in use](https://user-images.githubusercontent.com/18606569/149605161-ab656f03-bb0a-4e7b-a68f-ce7f44f169b1.gif)


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
    tooltip = {
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

### Features
+ Takes into account normal mode commands and backspacing while typing
+ Close reminders on buffer change or if the abbreviation value is deleted
+ Works with abbreviations added/removed on the fly

---

### Commands

#### Vim
+ `:AbbreinderEnable`
+ `:AbbreinderDisable`

#### Lua
+ `require('abbreinder').enable()`
+ `require('abbreinder').disable()`

