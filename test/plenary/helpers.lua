
-- @Summary write `text` to current buffer, triggering all regular
-- insert functionality (including autocmds and abbrev expansion)
local function type_text(text_to_type)

    -- if call `feedkeys` on entire string, attach_buffer (@see abbreinder.start)
    -- doesn't get all of the characters
    -- I believe this is due to `:help feedkeys()`
    --  > The function does not wait for processing of keys contained in {string}
    text_to_type:gsub(".", function(char)
        vim.api.nvim_feedkeys('a' .. char, 'xt', false)
    end)
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
            },
            [3] = {
                trigger = 'hi',
                value = 'hello'
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
    -- note: technically space might not be keyword
    -- be sure to `value:gsub(' ', non_keyword_char)` when used
    containing_non_keyword = {
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
local function run_multi_category_tests(non_keyword, testFn)

    testFn('single', abbr_examples.single_word.generic[1])

    local contains_non_key = abbr_examples.containing_non_keyword.generic[1]
    local contains_nk_val = contains_non_key.value:gsub(' ', non_keyword)
    local nk_abbr = {trigger = contains_non_key.trigger, value = contains_nk_val}

    testFn('containing non_keyword chars', nk_abbr)
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
