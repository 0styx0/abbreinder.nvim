local api = vim.api
local ns_name = 'abbreinder'
local ui = {
    -- [id] = {original_text, tooltip_id}
    _ext_data = {},
}

-- @return zero indexed current line num, index of value on line, index of value end
function ui.get_coordinates(value)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local line_num = row - 1
    local value_start = col - #value - 1
    local value_end = col - 1

    return line_num, value_start, value_end
end

local function close_tooltip(win_id)
    -- nvim_win_is_valid doesn't check if id is nil
    if win_id ~= nil and api.nvim_win_is_valid(win_id) then
        api.nvim_win_close(win_id, true)
    end
end

local function open_tooltip(abbreinder, value, text, ext_id)
    local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'buflisted', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_lines(buf, 0, -1, true, { text })
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { silent = true, nowait = true, noremap = true })

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
        bufpos = { line_num, abbr_start },
    }

    opts = vim.tbl_extend('force', opts, abbreinder.config.output.tooltip.opts)

    -- and finally create it with buffer attached
    local tooltip_id = api.nvim_open_win(buf, false, opts)
    api.nvim_buf_add_highlight(buf, -1, abbreinder.config.output.tooltip.highlight, 0, 0, -1)
    ui._ext_data[ext_id].tooltip_id = tooltip_id

    vim.defer_fn(function()
        close_tooltip(tooltip_id)
    end, abbreinder.config.output.tooltip.time_open)
end

function ui.monitor_reminders()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local ns_id = api.nvim_create_namespace(ns_name)

    local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, { row - 1, 0 }, { row + 1, 0 }, { details = true })

    if vim.tbl_isempty(marks) then
        return
    end

    for _, value in ipairs(marks) do
        local ext_id, row, col, details = unpack(value)

        local line = vim.api.nvim_get_current_line()
        local ext_contents = string.sub(line, col + 1, details.end_col)

        local ext_data = ui._ext_data[ext_id]

        if ext_data.original_text ~= ext_contents then
            api.nvim_buf_del_extmark(0, ns_id, ext_id)
            close_tooltip(ext_data.tooltip_id)
        end
    end
end

-- uses extmarks to manage highlights of value based on user-given config
-- @return ext_id
local function highlight_unexpanded_abbr(abbreinder, value)
    local line_num, abbr_start, abbr_end = ui.get_coordinates(value)
    local buf = api.nvim_get_current_buf()

    local ns_id = api.nvim_create_namespace(ns_name)

    local ext_id = api.nvim_buf_set_extmark(buf, ns_id, line_num, abbr_start + 1, {
        end_col = abbr_end + 1,
        hl_group = abbreinder.config.output.msg.highlight,
    })

    ui._ext_data[ext_id] = {
        original_text = value,
    }

    if abbreinder.config.output.msg.highlight_time ~= -1 then
        vim.defer_fn(function()
            api.nvim_buf_del_extmark(0, ns_id, ext_id)
        end, abbreinder.config.output.msg.highlight_time)
    end

    return ext_id
end

function ui.output_reminder(abbreinder, trigger, value)
    local msg = abbreinder.config.output.msg.format(trigger, value)

    local ext_id = highlight_unexpanded_abbr(abbreinder, value)

    if abbreinder.config.output.as.tooltip then
        -- if not deferred, E523 because can't manipulate buffers
        -- on InsertCharPre
        vim.defer_fn(function()
            open_tooltip(abbreinder, value, msg, ext_id)
        end, 0)
    end

    if abbreinder.config.output.as.echo then
        api.nvim_echo({ { msg } }, { false }, {})
    end
end

return ui
