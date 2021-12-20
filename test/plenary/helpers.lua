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

local abbrs = {
    single_word = {
        generic = {
            [0] = {
                trigger = 'nvim',
                value = 'neovim'
            }
        },
        trig_matches_val = {
            [0] = {
                trigger = 'trig',
                value = 'trigger'
            }
        },
        trig_no_match_val = {
            [0] = {
                trigger = 'mt',
                value = 'mountain'
            }
        }
    },
    multi_word = {
        generic = {
            [0] = {
                trigger = 'api',
                value = 'application programming interface'
            }
        }
    }
}

-- @param abbr = { trigger, value }
local function create_abbreviation(abbr)
    vim.cmd([[iabbrev ]] .. abbr.trigger .. [[ ]] .. abbr.value)
end


return {
    type_text = type_text,
    abbrs = abbrs,
    create_abbreviation = create_abbreviation,
}
