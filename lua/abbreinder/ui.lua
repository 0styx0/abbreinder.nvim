local api = vim.api;
local ui = {
}

-- @return zero indexed current line num, index of value on line, index of value end
function ui.get_coordinates(value)

    local pos = vim.fn.getcurpos()
    local line_num = pos[2]
    local col_num = pos[3]

    local value_start = col_num - #value - 1
    local value_end = col_num - 1

    return line_num, value_start, value_end
end

local function close_tooltip(win_id)

    if api.nvim_win_is_valid(win_id) then
        api.nvim_win_close(win_id, true)
    end
end


local function open_tooltip(abbreinder, value, text)

    local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'buflisted', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_lines(buf, 0, -1, true, {text})
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
        {silent = true, nowait = true, noremap = true})

    local line_num, abbr_start = ui.get_coordinates(value)

    -- set some options
    local opts = {
        style = 'minimal',
        relative = 'win',
        anchor = 'SW',
        width = #text,
        height = 1,
        focusable = false,
        noautocmd = true,
        bufpos = {line_num - 1, abbr_start},
    }

    opts = vim.tbl_extend('force', opts, abbreinder.config.output.tooltip.opts)

    -- and finally create it with buffer attached
    local id = api.nvim_open_win(buf, false, opts)
    api.nvim_buf_add_highlight(buf, -1, abbreinder.config.output.tooltip.highlight, 0, 0, -1)

    vim.defer_fn(
        function() close_tooltip(id) end,
        abbreinder.config.output.tooltip.time_open
    )
end

local function highlight_unexpanded_abbr(abbreinder, value)

    local line_num, abbr_start, abbr_len = ui.get_coordinates(value)
    local buf = api.nvim_get_current_buf()

    local ns = api.nvim_create_namespace('abbreinder'..value..'l'..line_num..'s'..abbr_start)
    -- -1 because lua is one-indexed, vim.api is zero-indexed
    api.nvim_buf_add_highlight(buf, ns, abbreinder.config.output.msg.highlight,
        line_num - 1, abbr_start,  abbr_len)

    if abbreinder.config.output.msg.highlight_time ~= -1 then
        vim.defer_fn(function()
            api.nvim_buf_clear_namespace(buf, ns, line_num - 1, line_num)
        end, abbreinder.config.output.msg.highlight_time)
    end
end


function ui.output_reminder(abbreinder, trigger, value)

    local msg = abbreinder.config.output.msg.format(trigger, value)

    highlight_unexpanded_abbr(abbreinder, value)

    if abbreinder.config.output.as.tooltip then
        -- if not deferred, E523 because can't manipulate buffers
        -- on InsertCharPre
        vim.defer_fn(function()
            open_tooltip(abbreinder, value, msg)
        end, 0)
    end

    if abbreinder.config.output.as.echo then
        api.nvim_echo({{msg}}, {false}, {})
    end

end

return ui
