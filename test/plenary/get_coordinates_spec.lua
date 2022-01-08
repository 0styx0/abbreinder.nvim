local assert = require('luassert.assert')
local stub = require('luassert.stub')

local abbreinder = require('abbreinder')

local function get_coordinates_helper(value, beginning_text, end_text)
    local start_text = beginning_text
    local line = start_text .. value .. end_text
    stub(vim.api, 'nvim_get_current_line').returns(line)

    local cursor_line = 42
    local cursor_col = #beginning_text + #value + 1
    stub(vim.api, 'nvim_win_get_cursor').returns({ cursor_line, cursor_col })

    local actual_coordinates = abbreinder._get_coordinates(value)

    vim.api.nvim_get_current_line:revert()
    vim.api.nvim_win_get_cursor:revert()

    local expected_start = #start_text
    local expected_end = expected_start + #value
    local expected_line = cursor_line - 1 -- zero indexing

    assert.equals(expected_line, actual_coordinates.row, 'line index')
    assert.equals(expected_start, actual_coordinates.col, 'starting col index')
    assert.equals(expected_end, actual_coordinates.col_end, 'ending col index')
end

local function run_tests(test_case, value)
    describe('abbr is ' .. test_case .. ' word and', function()
        it('abbr value is first word on line', function()
            local beginning_text = ''
            local end_text = ''
            get_coordinates_helper(value, beginning_text, end_text)
        end)

        it('abbr value is last word on line', function()
            local beginning_text = 'here is some text '
            local end_text = ''
            get_coordinates_helper(value, beginning_text, end_text)
        end)

        it('abbr value is middle word on line', function()
            local beginning_text = 'here is some text '
            local end_text = ' even more'
            get_coordinates_helper(value, beginning_text, end_text)
        end)

        -- eg, user types a line, then edits the middle of the line
        it('value is first of two of the same values in a line', function()
            local beginning_text = 'here is some text '
            local end_text = ' even ' .. value .. ' more'
            get_coordinates_helper(value, beginning_text, end_text)
        end)

        it('value is second of two of the same values in a line', function()
            local beginning_text = 'here is ' .. value .. ' some text '
            local end_text = value .. ' more'
            get_coordinates_helper(value, beginning_text, end_text)
        end)
    end)
end

-- not using iskeyword here, because keywords don't matter
local cases = { ['single'] = 'value', ['multi'] = 'point of view' }
describe('get_coordinates works correctly if', function()
    for test_case, value in pairs(cases) do
        run_tests(test_case, value)
    end
end)
