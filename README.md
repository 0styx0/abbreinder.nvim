
### Installation

##### Packer: 
```lua
  use {
    'styx-meiseles/abbreinder',
    config = require('abbreinder').setup(<config>)
  }
```

#### Config
```lua
config_defaults = {
  hot_reload = false, -- check for new abbreviations on every plugin call
  floating_window = false, -- false => echo command output
  source = nvim_get_current_line, -- function called to obtain text to parse
  run_on = 'CursorMovedI,TextChanged' -- autocmds to run plugin on
  formatted_msg = function(key, val): string -- format to print reminder in
}
```
While the config here will most likely be kept up to date, feel free to check out [./lua/abbreinder/config.lua](./lua/abbreinder/config.lua) for the actual version.

