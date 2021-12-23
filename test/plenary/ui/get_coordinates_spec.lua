local assert = require('luassert.assert')
local stub = require('luassert.stub')
local ui = require'abbreinder.ui'



local function get_coordinates_helper(value, beginning_text, end_text)

    local start_text = beginning_text
    local line = start_text .. value .. end_text
    stub(vim.api, 'nvim_get_current_line').returns(line)

    local cursor_line = 42
    local cursor_col = #beginning_text + #value + 1
    stub(vim.fn, 'getcurpos').returns({-1, cursor_line, cursor_col})

    local line_num, value_start, value_end = ui.get_coordinates(value)

    vim.api.nvim_get_current_line:revert()
    vim.fn.getcurpos:revert()

    local expected_start = #start_text
    local expected_end = expected_start + #value

    assert.equals(cursor_line, line_num, 'line index')
    assert.equals(expected_start, value_start, 'starting col index')
    assert.equals(expected_end, value_end, 'ending col index')
end


describe('get_coordinates works correctly if', function()

    describe('abbr is single word and', function()

        local value = 'value'

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
            local end_text =  value .. ' more'
            get_coordinates_helper(value, beginning_text, end_text)
        end)
    end)


    describe('abbr is multi word and', function()

        local value = 'point of view'

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

        it('value is first of two of the same values in a line', function()

            local beginning_text = 'here is some text '
            local end_text = ' even ' .. value .. ' more'
            get_coordinates_helper(value, beginning_text, end_text)

        end)

        it('value is second of two of the same values in a line', function()

            local beginning_text = 'here is ' .. value .. ' some text '
            local end_text =  value .. ' more'
            get_coordinates_helper(value, beginning_text, end_text)
        end)
    end)
end)
