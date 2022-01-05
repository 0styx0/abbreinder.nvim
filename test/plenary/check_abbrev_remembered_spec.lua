local assert = require('luassert.assert')
local stub = require('luassert.stub')
local abbreinder = require('abbreinder')
local ui = require('abbreinder.ui')
local helpers = require('test.plenary.helpers')

describe('check_abbrev_remembered', function()
    local trigger = helpers.abbrs.generic[1].trigger
    local value = helpers.abbrs.generic[1].value
    helpers.create_abbr({}, trigger, value)

    -- removed at eof. plenary doesn't support teardown()
    local keyword, non_keyword = helpers.set_keyword()

    stub(abbreinder, '_get_abbrevs_val_trigger').returns({ [value] = trigger })
    before_each(function()
        stub(ui, 'output_reminder').returns(nil)
    end)

    after_each(function()
        ui.output_reminder:revert()
    end)

    it('identifies when an abbreviation _was_ expanded', function()
        abbreinder._keylogger = trigger .. non_keyword .. value

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(1, remembered)
        assert.stub(ui.output_reminder).was_not_called()
    end)

    it('identifies when an abbreviation was _not_ expanded', function()
        abbreinder._keylogger = 'random no trigger stuff ' .. value .. non_keyword

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(0, remembered)
        assert.stub(ui.output_reminder).was_called(1)
    end)

    it('identifies when something is _not_ a potential abbreviation', function()
        abbreinder._keylogger = value .. keyword

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(-1, remembered)
        assert.stub(ui.output_reminder).was_not_called()
    end)

    describe('identifies correctly if called twice in a row and', function()
        it('first time expanded, second not expanded', function()
            abbreinder._keylogger = trigger .. non_keyword .. value .. non_keyword

            local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
            assert.are.same(1, remembered)

            abbreinder._keylogger = abbreinder._keylogger .. value .. non_keyword
            local remembered_second = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
            assert.are.same(0, remembered_second)
        end)

        it('first time not an abbreviation, second not expanded', function()
            abbreinder._keylogger = value .. keyword

            local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
            assert.are.same(-1, remembered)

            abbreinder._keylogger = abbreinder._keylogger .. value .. non_keyword
            local remembered_second = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
            assert.are.same(0, remembered_second)
        end)
    end)
end)

helpers.reset()
