local assert = require('luassert.assert')
local abbreinder = require('abbreinder')
local spy = require('luassert.spy')
local stub = require('luassert.stub')
local helpers = require('test.plenary.helpers')

describe('find_abbrev', function()

    -- removed at eof. plenary doesn't support teardown()
    local keyword, non_keyword = helpers.set_keyword()

    -- unit test, don't rely on other functionality
    stub(abbreinder, '_check_abbrev_remembered').returns(nil)

    it('short circuits if abbreviation not possible', function()

        -- matchstrpos just happens to be a method used in find_abbrev
        local spied_matchstrpos = spy.on(vim.fn, 'matchstrpos')
        vim.v.char = keyword
        local remembered = abbreinder.find_abbrev()
        assert.are.same(-1, remembered)

        assert.spy(spied_matchstrpos).was_not_called()
        vim.fn.matchstrpos:revert()
    end)

    helpers.run_multi_category_tests(function(category, abbr)

        it('accounts for '..category..' word abbrs', function()

            helpers.create_abbr({}, abbr.trigger, abbr.value)

            abbreinder._keylogger = 'random text ' .. abbr.value
            vim.v.char = non_keyword
            local _, actual_trigger, actual_value = abbreinder.find_abbrev()

            assert.are.same(abbr.trigger, actual_trigger)
            assert.are.same(abbr.value, actual_value)
        end)
    end)

    it('uses most recently typed abbr, if multiple typed', function()

        abbreinder._keylogger = ''

        for i = 1, 2, 1 do

            local abbr = helpers.abbrs.generic[i]
            helpers.create_abbr({}, abbr.trigger, abbr.value)

            abbreinder._keylogger = abbreinder._keylogger .. ' random text ' .. abbr.value
            vim.v.char = non_keyword
            local _, actual_trigger, actual_value = abbreinder.find_abbrev()

            assert.are.same(abbr.trigger, actual_trigger, i .. 'th abbrev')
            assert.are.same(abbr.value, actual_value)
        end
    end)
end)

helpers.reset()
