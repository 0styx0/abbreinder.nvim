-- so can look at output
local config = require('abbreinder.config')
local abbreinder = require('abbreinder')

config.output.msg.highlight_time = -1

local abbr_examples = {
    generic = {
        [1] = {
            trigger = 'req',
            value = 'require',
        },
        [2] = {
            trigger = 'shep',
            value = 'shepherd',
        },
        [3] = {
            trigger = 'hi',
            value = 'hello',
        },
    },
    single_word = {
        generic = {
            [1] = {
                trigger = 'nvim',
                value = 'neovim',
            },
        },
        trig_matches_val = {
            [1] = {
                trigger = 'trig',
                value = 'trigger',
            },
        },
        trig_no_match_val = {
            [1] = {
                trigger = 'mt',
                value = 'mountain',
            },
        },
    },
    -- note: technically space might not be keyword
    -- be sure to `value:gsub(' ', non_keyword_char)` when used
    containing_non_keyword = {
        generic = {
            [1] = {
                trigger = 'api',
                value = 'application programming interface',
            },
        },
        single_char = {
            [1] = {
                trigger = 'un',
                value = '∪',
            },
        },
    },
}

-- @param abbr = { trigger, value }
-- todo: remove in favor of create_abbr
local function create_abbreviation(abbr)
    vim.cmd([[iabbrev ]] .. abbr.trigger .. [[ ]] .. abbr.value)
end

function Write(test_name, str, want_reminder)
    local description = '### ' .. test_name

    local forgotten_callback = function(abbr_data)
        print(vim.inspect(abbr_data))
        vim.api.nvim_buf_add_highlight(0, -1, 'Special', abbr_data.row, abbr_data.col + 1, abbr_data.col_end - 1)
        return false
    end
    local remembered_callback = function(abbr_data)
        vim.api.nvim_buf_add_highlight(0, -1, 'DiffText', abbr_data.row, abbr_data.col + 1, abbr_data.col_end + 1)
        return false
    end
    abbreinder.on_abbr_forgotten(forgotten_callback)
    abbreinder.on_abbr_remembered(remembered_callback)

    local expected = 'expected: '
    if want_reminder then
        expected = expected .. 'YES reminder'
    else
        expected = expected .. '_NO_ reminder'
    end

    vim.api.nvim_feedkeys('a\n' .. description, 'xn', true)
    vim.api.nvim_feedkeys('a\n' .. expected, 'xn', true)

    local escaped = vim.api.nvim_replace_termcodes(str, true, true, true)
    vim.api.nvim_feedkeys('a\n' .. escaped, 'tx', true)

    local ending = vim.api.nvim_replace_termcodes('<Esc>o' .. '\n\n', true, true, true)
    vim.api.nvim_feedkeys(ending, 'tn', true)
end

Abbreinder = {}
Abbreinder.tests = {}

function Abbreinder.tests.single_reminds(name)
    local abbr = abbr_examples.single_word.generic[1]
    create_abbreviation(abbr)
    Write(name, abbr.value .. ' ', true)
end

function Abbreinder.tests.nk_in_val_reminds(name)
    local abbr = abbr_examples.containing_non_keyword.generic[1]
    create_abbreviation(abbr)
    Write(name, abbr.value .. ' ', true)
end

function Abbreinder.tests.if_bs_in_value_reminds(name)
    local abbr = { trigger = 'hello', value = 'goodbye' }
    create_abbreviation(abbr)
    Write(name, 'good<BS>dbye ', true)
end

-- NOTE: for some reason during test it shows as no reminder
-- but in practice, this does work. check manually to be sure
function Abbreinder.tests.normal_mode_modifies_value_reminds(name)
    local abbr = { trigger = 'req', value = 'require' }

    create_abbreviation(abbr)
    Write(name, 'rqe<Esc>hxpauire ', true)
end

function Abbreinder.tests.expanded_not_reminded(name)
    local abbr = abbr_examples.generic[1]

    create_abbreviation(abbr)
    Write(name, abbr.trigger .. ' ', false)
end

function Abbreinder.tests.expanded_midline_not_reminded(name)
    local abbr = abbr_examples.generic[1]
    create_abbreviation(abbr)

    local last_word = 'line'
    local go_back = string.rep('<Left>', #last_word + 1)
    Write(name, 'something on line ' .. go_back .. abbr.trigger .. ' ', false)
end

function Abbreinder.tests.go_back_to_value_from_elsewhere_no_remind(name)
    local abbr = abbr_examples.generic[1]
    create_abbreviation(abbr)

    Write(name, abbr.trigger .. ' ' .. '<Left>' .. ' ', false)
end

function Abbreinder.tests.nonexistent_abbr_no_remind(name)
    local abbr = { trigger = 'nothing', value = 'here' }
    -- since abbr doesn't exist, would throw error
    pcall(vim.cmd, 'unabbreviate ' .. abbr.trigger)

    Write(name, abbr.trigger .. ' ', false)
end

function Abbreinder.tests.does_nothing_on_normal_mode(name)
    Write(name, '<Esc>dd', nil)
end

function Run_tests()
    -- vim.cmd('edit test/plenary/integration_test_output.md')
    -- vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

    for key, value in pairs(Abbreinder.tests) do
        Abbreinder.tests[key](key)
    end
end

