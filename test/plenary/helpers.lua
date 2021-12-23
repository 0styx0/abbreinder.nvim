local util = require "plenary.async.util"
-- local a = require "plenary.async.async"

-- @Summary write `text` to current buffer, triggering all regular
-- insert functionality (including autocmds and abbrev expansion)
-- @param trigger - bool. default, false
-- @param buf - buffer to run command in. default, create and switch to new buffer
-- side effect: switches to buffer `buf`
-- @return text actually typed (accounting for trigger), and buffer it was typed in
local function type_text(text, trigger, buf)

    local text_typed = text

    if (trigger) then text_typed = text_typed .. ' ' end
    if (not buf) then buf = vim.api.nvim_create_buf(false, true) end

    -- tried using `nvim_buf_call`, but then `nvim_get_current_line` was always empty
    vim.api.nvim_command('buffer ' .. buf)

    local pos = {}
    pos.before = vim.fn.getcurpos()

    -- -1 because functions like nvim_buf_add_highlight are zero indexed but pos is 1-indexed
    pos.before.line = pos.before[2] - 1
    pos.before.col = pos.before[3] - 1

    -- prob don't need <Esc>. revisit
    local keycodes = vim.api.nvim_replace_termcodes('a' .. text_typed .. '<Esc>', true, true, true)
    vim.api.nvim_feedkeys(keycodes, 'x', false)

    pos.after = vim.fn.getcurpos()
    pos.after.line = pos.after[2] - 1
    pos.after.col = pos.after[3] - 1

    local line = vim.api.nvim_buf_get_lines(buf, pos.before.line, pos.after.line + 1, false)
    pending('Line->'..line[1]..'<-')
    return text_typed, pos, buf
end

local abbr_examples = {
    generic = {
            [1] = {
                trigger = 'req',
                value = 'require'
            },
            [2] = {
                trigger = 'shep',
                value = 'shepherd'
            }
    },
    single_word = {
        generic = {
            [1] = {
                trigger = 'nvim',
                value = 'neovim'
            }
        },
        trig_matches_val = {
            [1] = {
                trigger = 'trig',
                value = 'trigger'
            }
        },
        trig_no_match_val = {
            [1] = {
                trigger = 'mt',
                value = 'mountain'
            }
        }
    },
    multi_word = {
        generic = {
            [1] = {
                trigger = 'api',
                value = 'application programming interface'
            }
        }
    }
}

-- @param abbr = { trigger, value }
-- todo: remove in favor of create_abbr
local function create_abbreviation(abbr)
    vim.cmd([[iabbrev ]] .. abbr.trigger .. [[ ]] .. abbr.value)
end


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

local old_iskeyword = nil

-- @Summary sets `iskeyword`
-- @return a keyword char and a non-keyword char
-- note: non-keyword = triggers abbreviation expansion
local function set_keyword()

    local keyword = '_'
    local non_keyword = '$'
    old_iskeyword = vim.api.nvim_get_option('iskeyword')
    vim.api.nvim_set_option('iskeyword', keyword)

    return keyword, non_keyword
end

-- @Summary sets `iskeyword` back to previous value and clears all abbreviations
local function reset()

    if old_iskeyword ~= nil then
        vim.api.nvim_set_option('iskeyword', old_iskeyword)
        old_iskeyword = nil
    end

    vim.cmd('iabclear')
end


-- @Summary runs test on multiple abbr categories (eg, value is single or multi word)
-- @param testFn - function(category: string, abbr)
--   and abbr will be {trigger: string, value: string}
local function run_multi_category_tests(testFn)
    -- note: maybe create_abbr here and remove after
    -- problem: might interfere if previously defined and now removing
    -- fix: track if previously defined
    -- todo: by refactor
    testFn('single', abbr_examples.single_word.generic[1])
    testFn('multi', abbr_examples.multi_word.generic[1])
end

return {
    type_text = type_text,
    abbrs = abbr_examples,
    create_abbreviation = create_abbreviation,
    create_abbr = create_abbr,
    remove_abbr = remove_abbr,
    set_keyword = set_keyword,
    reset = reset,
    run_multi_category_tests = run_multi_category_tests
}
