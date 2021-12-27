local config_defaults = {
    output = {
        as = {
            echo = false,
            tooltip = true,
        },
        msg = {
            format = function(key, val) -- format to print reminder in
                return 'abbrev: "' .. key .. '"->' .. '"' .. val .. '"'
            end,
            highlight = 'Special', -- highlight to use
            -- if want highlight to stop after x ms. -1 for permanent highlight
            highlight_time = 4000,
        },
        tooltip = { -- only takes effect if output_as.tooltip = true
            time_open = 4000, -- time before tooltip closes
            opts = {}, -- see :help nvim_open_win
            highlight = 'Special',
        },
    },
    -- vim-abolish prefixes each abbreviation value.
    -- adding prefixes here accounts for them
    value_prefixes = { '*@' },
}

return config_defaults
