local abbremand = require('abbremand')
local default_config = require('config')

local api = vim.api

local abbreinder = {
    next_abbr_id = 0,
    -- [abbr_id] = {tooltip_id, hl_id}
    abbr_data = {},
    -- [buf_num] = bool
    enabled = {},
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
    local text = abbreinder.config.tooltip.format(abbr_data.trigger, abbr_data.value)

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

    opts = vim.tbl_extend('force', opts, abbreinder.config.tooltip.opts)

    -- and finally create it with buffer attached
    local tooltip_id = api.nvim_open_win(buf, false, opts)

    if abbreinder.config.tooltip.highlight.enabled then
        api.nvim_buf_add_highlight(buf, -1, abbreinder.config.tooltip.highlight.group, 0, 0, -1)
    end

    abbreinder.abbr_data[abbr_id].tooltip_id = tooltip_id

    vim.defer_fn(function()
        close_tooltip(tooltip_id)
    end, abbreinder.config.tooltip.time)
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
        hl_group = abbreinder.config.value_highlight.group,
    })

    abbreinder.abbr_data[abbr_id].hl_id = ext_id

    if abbreinder.config.value_highlight.time ~= -1 then
        vim.defer_fn(function()
            api.nvim_buf_del_extmark(0, ns_id, ext_id)
        end, abbreinder.config.value_highlight.time)
    end
end

local function close_reminders(abbr_id)

    local abbr_data = abbreinder.abbr_data[abbr_id]
    remove_value_highlight(abbr_data.hl_id)
    close_tooltip(abbr_data.tooltip_id)
end

-- @param abbr {trigger, value, row, col, col_end, on_change}
local function output_reminders(abbr_data)

    local buf = vim.api.nvim_get_current_buf()
    if not abbreinder.enabled[buf] then
        -- false = unsubscribe
        return false
    end

    -- case of people using abbreviations to correct typos
    if #abbr_data.trigger == #abbr_data.value then
        return
    end

    local abbr_id = abbreinder.next_abbr_id
    abbreinder.next_abbr_id = abbreinder.next_abbr_id + 1
    abbreinder.abbr_data[abbr_id] = {}

    if abbreinder.config.value_highlight.enabled then
        add_value_highlight(abbr_data, abbr_id)
    end

    if abbreinder.config.tooltip.enabled then
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

local function remove_autocmds()
    vim.cmd([[
    command! -bang AbbreinderDisable autocmd! Abbreinder
    ]])
end

local function create_autocmds()
    vim.cmd[[
    augroup Abbreinder
    autocmd!
    autocmd BufNewFile,BufReadPre * :lua require('abbreinder').enable()
    augroup END
    ]]
end

local function create_ex_commands()
    vim.cmd([[
    command! -bang AbbreinderEnable lua require('abbreinder').enable()
    command! -bang AbbreinderDisable lua require('abbreinder').disable()
    ]])
end

local function disable()
    local buf = vim.api.nvim_get_current_buf()
    abbreinder.enabled[buf] = false
    remove_autocmds()
end

local function enable()
    local buf = vim.api.nvim_get_current_buf()
    abbreinder.enabled[buf] = true
    create_autocmds()
    create_ex_commands()
    abbremand.on_abbr_forgotten(output_reminders)
end

-- @Summary Sets up abbreinder
-- @Description launch abbreinder with specified config (falling back to defaults from ./abbreinder/config.lua)
-- @Param config(table) - user specified config
local function setup(user_config)
    user_config = user_config or {}

    abbreinder.config = vim.tbl_deep_extend('force', default_config, user_config)
    enable()
end

return {
    enable = enable,
    disable = disable,
    setup = setup,
}
