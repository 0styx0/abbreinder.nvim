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

return config_defaults
