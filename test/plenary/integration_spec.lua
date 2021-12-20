

local assert = require('luassert.assert')
local helpers = require'test.plenary.helpers'
local abbreinder = require'abbreinder'

local mock = require('luassert.mock')
local spy = require('luassert.spy')
local match = require("luassert.match")

local ui = require'abbreinder.ui'
local api = vim.api;
-- local util = require "plenary.async.util"
-- local async_tests = require "plenary.async.tests"

--[[
describe('Integration tests', function()

    local function test_highlight(abbr, buf)

        local text = abbr.value

        helpers.create_abbreviation(abbr)

        local spied = spy.on(api, 'nvim_buf_add_highlight')

        local text_typed, pos = helpers.type_text(text, true, buf)

        local _ = match._

        assert.spy(api.nvim_buf_add_highlight).was_called()
        pending('l: '.. pos.before.line .. ' c: '.. pos.before.col .. ' len: '.. pos.after.col)
        -- 6
        assert.spy(api.nvim_buf_add_highlight).was_called_with(_, _, _, pos.before.line, pos.before.col, pos.after.col)

        local line = vim.api.nvim_get_current_line()
        assert.equals(text_typed, line)
    end

    -- it('highlights single word abbrs at start of line', function()
    --
    --     local abbr = helpers.abbrs.single_word.generic[0]
    --     test_highlight(abbr)
    -- end)

    -- it('highlights single word abbrs in middle of line', function()
    --
    --     local abbr = helpers.abbrs.single_word.generic[0]
    --
    --     local text = abbr.value
    --
    --     helpers.create_abbreviation(abbr)
    --
    --     local text_typed, pos, buf = helpers.type_text('random text ' .. abbr.value, true)
    --
    --     local spied = spy.on(api, 'nvim_buf_add_highlight')
    --
    --     -- text_typed, pos = helpers.type_text(text, true, buf)
    --
    --     local _ = match._
    --
    --     assert.spy(api.nvim_buf_add_highlight).was_called()
    --     pending('HERE l: '.. pos.before.line .. ' c: '.. pos.before.col .. ' len: '.. pos.after.col)
    --     -- 6
    --     assert.spy(api.nvim_buf_add_highlight).was_called_with(_, _, _, pos.before.line, pos.before.col, pos.after.col)
    --
    --     -- expected: 11 to 18
    --     -- actual:   12 to 18
    --     local line = vim.api.nvim_get_current_line()
    --     assert.equals(text_typed, line)
    -- end)

    -- it('highlights multi word abbrs at start of line', function()
    --
    --     local abbr = helpers.abbrs.multi_word.generic[0]
    --     test_highlight(abbr)
    -- end)

end)
--]]
