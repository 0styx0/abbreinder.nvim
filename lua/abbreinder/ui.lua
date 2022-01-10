local abbreinder = require('abbreinder')
local default_config = require('abbreinder.config')

local api = vim.api

local ui = {
    _abbr_id = 0,
    -- [abbr_id] = {tooltip_id, hl_id}
    _abbr_data = {},
    _enabled = false,
}

-- @return namespace id
local function get_namespace()
    local ns_name = 'abbreinder'
    return api.nvim_create_namespace(ns_name)
end

local function close_tooltip(win_id)
    -- nvim_win_is_valid doesn't check if id is nil
    if win_id ~= nil and api.nvim_win_is_valid(win_id) then
        api.nvim_win_close(win_id, true)
    end
end

local function open_tooltip(abbr_data, abbr_id)
    local text = ui.config.tooltip.format(abbr_data.trigger, abbr_data.value)

    local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'buflisted', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_lines(buf, 0, -1, true, { text })
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { silent = true, nowait = true, noremap = true })

    -- set some options
    local opts = {
        style = 'minimal',
        relative = 'win',
        anchor = 'SW',
        width = #text,
        height = 1,
        focusable = false,
        noautocmd = true,
        bufpos = { abbr_data.row, abbr_data.col },
    }

    opts = vim.tbl_extend('force', opts, ui.config.tooltip.opts)

    -- and finally create it with buffer attached
    local tooltip_id = api.nvim_open_win(buf, false, opts)

    if ui.config.tooltip.highlight.enabled then
        api.nvim_buf_add_highlight(buf, -1, ui.config.tooltip.highlight.group, 0, 0, -1)
    end

    ui._abbr_data[abbr_id].tooltip_id = tooltip_id

    vim.defer_fn(function()
        close_tooltip(tooltip_id)
    end, ui.config.tooltip.time)
end

local function remove_value_highlight(hl_id)
    local ns_id = get_namespace()
    api.nvim_buf_del_extmark(0, ns_id, hl_id)
end

-- uses extmarks to manage highlights of value based on user-given config
-- @return ext_id
local function add_value_highlight(abbr_data, abbr_id)
    local ns_id = get_namespace()

    local ext_id = api.nvim_buf_set_extmark(0, ns_id, abbr_data.row, abbr_data.col + 1, {
        end_col = abbr_data.col_end + 1,
        hl_group = ui.config.value_highlight.group,
    })

    ui._abbr_data[abbr_id].hl_id = ext_id

    if ui.config.value_highlight.time ~= -1 then
        vim.defer_fn(function()
            api.nvim_buf_del_extmark(0, ns_id, ext_id)
        end, ui.config.value_highlight.time)
    end
end

local function close_reminders(abbr_id)

    local abbr_data = ui._abbr_data[abbr_id]
    remove_value_highlight(abbr_data.hl_id)
    close_tooltip(abbr_data.tooltip_id)
end

-- @param abbr {trigger, value, row, col, col_end, on_change}
local function output_reminders(abbr_data)

    if not ui._enabled then
        -- false = unsubscribe
        return false
    end

    -- case of people using abbreviations to correct typos
    if #abbr_data.trigger == #abbr_data.value then
        return
    end

    local abbr_id = ui._abbr_id
    ui._abbr_id = ui._abbr_id + 1
    ui._abbr_data[abbr_id] = {}

    if ui.config.value_highlight.enabled then
        add_value_highlight(abbr_data, abbr_id)
    end

    if ui.config.tooltip.enabled then
        -- if not scheduled, E523 because can't manipulate buffers
        -- on InsertCharPre
        vim.schedule(function()
            open_tooltip(abbr_data, abbr_id)
        end)
    end

    abbr_data.on_change(function()
        close_reminders(abbr_id)
    end)
end

local function create_ex_commands()
    vim.cmd([[
    command! -bang AbbreinderEnable lua require('abbreinder.ui').enable()
    command! -bang AbbreinderDisable lua require('abbreinder.ui').disable()
    ]])
end

function ui.disable()
    ui._enabled = false
end

function ui.enable()
    ui._enabled = true
    create_ex_commands()
    abbreinder.on_abbr_forgotten(output_reminders)
end

-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
function ui.setup(user_config)
    user_config = user_config or {}

    ui.config = vim.tbl_deep_extend('force', default_config, user_config)
    ui.enable()
end

return ui
