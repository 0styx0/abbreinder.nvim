local assert = require('luassert.assert')

local abbreinder = require('abbreinder')
local helpers = require('test.plenary.helpers')


local abbrs = {}

describe('get_abbrevs_val_trigger works correctly if', function()

    local keyword, non_keyword = helpers.set_keyword()

    it('gets all created abbreviations', function()

        helpers.reset() -- technically not needed, but doesn't hurt
        for _,abbr in ipairs(helpers.abbrs.generic) do
            abbrs = helpers.create_abbr(abbrs, abbr.trigger, abbr.value)
        end

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger)
    end)

    -- technically a space might be a keyword. but _highly_ doubt that
    it("can follow values containing non-keywords to the main abbreviation map", function()

        local multi_trigger = 'pov'
        local after_last_nk = 'view'
        local multi_val = 'point of' .. non_keyword .. after_last_nk

        abbrs = helpers.create_abbr(abbrs, multi_trigger, multi_val)
        local abbrev_map_value_trigger = abbreinder._get_abbrevs_val_trigger()

        local nk_full_val = abbreinder._contains_nk_abbr(multi_val, after_last_nk)
        assert.truthy(nk_full_val)
        assert.are.same(multi_val, nk_full_val)
        assert.are.same(multi_trigger, abbrev_map_value_trigger[nk_full_val])
    end)

    -- technically the same as multiword, but ensuring not just checking
    -- if value contains a space
    it("adds abbreviations with special characters to list", function()

        local trigger = 'wts'
        local value = "what's"

        abbrs = helpers.create_abbr(abbrs, trigger, value)
        local abbrev_map_value_trigger = abbreinder._get_abbrevs_val_trigger()

        assert.are.same(trigger, abbrev_map_value_trigger[value])
    end)

    it('adds newly defined abbreviations to the list', function()

        abbrs = helpers.create_abbr(abbrs, 'hi', 'hello')

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger)
    end)

    it('takes into account modified abbreviations', function()

        local old = { ['key'] = 'anth', ['value'] = 'anthropology'}

        abbrs = helpers.create_abbr(abbrs, 'anth', 'anthropology')

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger, 'regular abbrev created')

        abbrs[old.value] = nil -- remove from testing table
        abbrs = helpers.create_abbr(abbrs, 'anth', 'random')

        local map_value_trigger_updated = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger_updated, 'updated abbrev')
    end)

    it('handles prefixed abbreviations (eg, supports plugins like vim-abolish)', function()

        -- add to abbrs table, but wait for Abolish to actually create it
        abbrs = helpers.create_abbr(abbrs, 'op', 'operation')
        abbrs = helpers.create_abbr(abbrs, 'ops', 'operations')
        vim.cmd('unabbreviate op')
        vim.cmd('unabbreviate ops')

        vim.cmd('Abolish op{,s} operation{,s}')

        assert.are.same(abbrs['operations'], 'ops')
        assert.are.same(abbrs['operation'], 'op')

        abbrs = helpers.remove_abbr(abbrs, 'op', 'operation')
        abbrs = helpers.remove_abbr(abbrs, 'ops', 'operations')
        vim.cmd('Abolish -delete op{,s}')
    end)


    it('value consists of a single non-keyword char', function()

        local abbr = helpers.abbrs.containing_non_keyword.single_char[1]

        abbrs = helpers.create_abbr(abbrs, abbr.trigger, abbr.value)
        local abbrev_map_value_trigger = abbreinder._get_abbrevs_val_trigger()

        -- removing because if assertion fails, would break rest of tests
        abbrs = helpers.remove_abbr(abbrs, abbr.trigger, abbr.value)

        assert.are.same(abbr.trigger, abbrev_map_value_trigger[abbr.value])
    end)

    it('two non-keyword-containing values with same ending can coexist', function()

        local after_last_nk = 'view'
        local same_ending_abbrs = {
            [1] = {
                ['trigger'] = "pov",
                ['value'] = "point of" .. non_keyword .. after_last_nk
            },
            [2] = {
                ['trigger'] = "nv",
                ['value'] = "nice" .. non_keyword .. after_last_nk
            }
        }

        abbrs = helpers.create_abbr(abbrs, same_ending_abbrs[1].trigger, same_ending_abbrs[1].value)
        abbrs = helpers.create_abbr(abbrs, same_ending_abbrs[2].trigger, same_ending_abbrs[2].value)
        local abbrev_map_value_trigger = abbreinder._get_abbrevs_val_trigger()

        assert.are.same(same_ending_abbrs[1].trigger, abbrev_map_value_trigger[same_ending_abbrs[1].value])
        assert.are.same(same_ending_abbrs[2].trigger, abbrev_map_value_trigger[same_ending_abbrs[2].value])

        assert.contains_element(abbreinder._cache.abbrev_map_multiword[after_last_nk], same_ending_abbrs[1].value)
        assert.contains_element(abbreinder._cache.abbrev_map_multiword[after_last_nk], same_ending_abbrs[2].value)
    end)
end)

helpers.reset()
