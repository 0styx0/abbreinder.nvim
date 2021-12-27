local assert = require('luassert.assert')
local spy = require('luassert.spy')
local helpers = require('test.plenary.helpers')

local abbreinder = require('abbreinder')
local ui = require('abbreinder.ui')

describe('integration tests', function()
    local keyword, non_keyword = helpers.set_keyword()
    abbreinder.start()

    local spied_check_remembered
    local spied_find
    local spied_output_reminder

    before_each(function()
        -- technically because integration testing, don't need to
        -- check anything except output_reminder. but helps for
        -- debugging tests
        spied_check_remembered = spy.on(abbreinder, '_check_abbrev_remembered')
        spied_find = spy.on(abbreinder, '_find_abbrev')
        spied_output_reminder = spy.on(ui, 'output_reminder')
    end)

    after_each(function()
        abbreinder._check_abbrev_remembered:revert()
        abbreinder._find_abbrev:revert()
        ui.output_reminder:revert()
    end)

    helpers.run_multi_category_tests(non_keyword, function(category, abbr)
        it('reminds the user of ' .. category .. ' abbrevations', function()
            helpers.create_abbr({}, abbr.trigger, abbr.value)
            helpers.type_text(abbr.value .. non_keyword)

            assert.spy(spied_find, '_find_abbrev').was_called()
            assert.spy(spied_check_remembered, 'remembered').was_called()
            assert.spy(spied_output_reminder, 'reminder').was_called()
        end)
    end)

    it('does not remind the user of expanded abbrevations', function()
        local abbr = helpers.abbrs.generic[1]

        local expanding_trigger = helpers.format_trigger_expanding(abbr.trigger)

        helpers.create_abbr({}, abbr.trigger, abbr.value)
        helpers.type_text(expanding_trigger .. non_keyword)

        assert.spy(spied_find, '_find_abbrev').was_called()
        assert.spy(spied_check_remembered, 'remembered').was_not_called()
        assert.spy(spied_output_reminder, 'reminder').was_not_called()
    end)

    it('does not remind user of non-existent abbreviations', function()
        local abbr = { trigger = 'nonexistant', value = 'silence is golden' }

        -- not defining abbreviation

        helpers.type_text(abbr.trigger .. non_keyword)

        assert.spy(spied_find, '_find_abbrev').was_called()
        assert.spy(spied_check_remembered, 'remembered').was_not_called()
        assert.spy(spied_output_reminder, 'reminder').was_not_called()
    end)

    it('reminds about forgotten abbr even if backspace in value', function()
        local abbr = { trigger = 'hello', value = 'goodbye' }

        helpers.create_abbr({}, abbr.trigger, abbr.value)

        helpers.type_text('good<BS>dbye' .. non_keyword)

        assert.spy(spied_find, '_find_abbrev').was_called()
        assert.spy(spied_check_remembered, 'remembered').was_called()
        assert.spy(spied_output_reminder, 'reminder').was_called()
    end)

    it('does nothing on a non-insert-mode command', function()
        helpers.type_text('a<CR><Esc>dd')

        assert.spy(spied_check_remembered, 'remembered').was_not_called()
        assert.spy(spied_output_reminder, 'reminder').was_not_called()
    end)
end)

helpers.reset()
