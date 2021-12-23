local assert = require('luassert.assert')
local abbreinder = require('abbreinder')

-- @Summary creates new abbreviation and adds it to list
local function create_abbr(abbrs, trigger, value)

    local new_abbr = {[value] = trigger}
    vim.cmd('iabbrev ' .. trigger .. ' ' .. value)
    abbrs = vim.tbl_extend('keep', abbrs, new_abbr)

    return abbrs
end

local function remove_abbr(abbrs, trigger, value)

    abbrs[value] = nil
    vim.cmd('unabbreviate ' .. trigger)

    return abbrs
end


local abbrs = {}
local multi = {}

describe('get_abbrevs_val_trigger works correctly if', function()

    it('gets all created abbreviations', function()

        abbrs = create_abbr(abbrs, 'trigger', 'value')
        abbrs = create_abbr(abbrs, 'req', 'requirement')
        abbrs = create_abbr(abbrs, 'distro', 'distribution')

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger)
    end)

    it("can follow multiword abbreviations to the main abbreviation map", function()

        local multi_trigger = 'pov'
        local multi_val = 'point of view'
        multi['view'] = multi_val

        abbrs = create_abbr(abbrs, multi_trigger, multi_val)
        local abbrev_map_value_trigger, abbrev_map_multiword = abbreinder._get_abbrevs_val_trigger()
        local actual_multi_val = abbrev_map_multiword['view']

        assert.are.same(multi_val, actual_multi_val)
        assert.are.same(multi_trigger, abbrev_map_value_trigger[actual_multi_val])
    end)

    it('adds newly defined abbreviations to the list', function()

        abbrs = create_abbr(abbrs, 'hi', 'hello')

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger)
    end)

    it('takes into account modified abbreviations', function()

        local old = { ['key'] = 'anth', ['value'] = 'anthropology'}

        abbrs = create_abbr(abbrs, 'anth', 'anthropology')

        local map_value_trigger = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger, 'regular abbrev created')

        abbrs[old.value] = nil -- remove from testing table
        abbrs = create_abbr(abbrs, 'anth', 'random')

        local map_value_trigger_updated = abbreinder._get_abbrevs_val_trigger()
        assert.are.same(abbrs, map_value_trigger_updated, 'updated abbrev')
    end)

    it('handles prefixed abbreviations (eg, supports plugins like vim-abolish)', function()

        -- add to abbrs table, but wait for Abolish to actually create it
        abbrs = create_abbr(abbrs, 'op', 'operation')
        abbrs = create_abbr(abbrs, 'ops', 'operations')
        vim.cmd('unabbreviate op')
        vim.cmd('unabbreviate ops')

        vim.cmd('Abolish op{,s} operation{,s}')

        assert.are.same(abbrs['operations'], 'ops')
        assert.are.same(abbrs['operation'], 'op')

        abbrs = remove_abbr(abbrs, 'op', 'operation')
        abbrs = remove_abbr(abbrs, 'ops', 'operations')
        vim.cmd('Abolish -delete op{,s}')
    end)
end)
