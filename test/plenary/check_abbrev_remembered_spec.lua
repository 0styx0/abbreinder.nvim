local assert = require('luassert.assert')
local stub = require('luassert.stub')
local abbreinder = require('abbreinder')
local helpers = require('test.plenary.helpers')
local spy = require('luassert.spy')

describe('check_abbrev_remembered', function()
    local trigger = helpers.abbrs.generic[1].trigger
    local value = helpers.abbrs.generic[1].value
    helpers.create_abbr({}, trigger, value)

    -- removed at eof. plenary doesn't support teardown()
    local keyword, non_keyword = helpers.set_keyword()
    local spied_callback;

    stub(abbreinder, '_get_abbrevs_val_trigger').returns({ [value] = trigger })

    before_each(function()
        spied_callback = spy.new(function() end)
        abbreinder.register_abbr_forgotten(spied_callback)
    end)

    after_each(function()
        spied_callback:revert()
    end)

    it('identifies when an abbreviation _was_ expanded', function()
        abbreinder._keylogger = trigger .. non_keyword .. value

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(1, remembered)
        assert.spy(spied_callback).was.Not.called()
    end)

    it('identifies when an abbreviation was _not_ expanded', function()
        abbreinder._keylogger = 'random no trigger stuff ' .. value .. non_keyword

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(0, remembered)
        assert.spy(spied_callback).was.called(1)
    end)

    it('identifies when something is _not_ a potential abbreviation', function()
        abbreinder._keylogger = value .. keyword

        local remembered = abbreinder._check_abbrev_remembered(trigger, value, abbreinder._keylogger)
        assert.are.same(-1, remembered)
        assert.spy(spied_callback).was.Not.called()
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
