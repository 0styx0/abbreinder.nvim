local api = vim.api;

local function open_window(text)

  local buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- get dimensions
  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  -- set some options
  local opts = {
    style = "minimal",
    relative = "editor",
    width = #text,
    height = 2,
    row = 7,
    col = 10
  }

  api.nvim_buf_set_lines(buf, 0, -1, false, {text})
  -- and finally create it with buffer attached
  local win = api.nvim_open_win(buf, true, opts)

  api.nvim_buf_add_highlight(buf, -1, 'BlueItalic', 0, 0, -1)
end


local function get_abbrevs()

  local abbrevs = api.nvim_exec('iabbrev', true) .. '\n'

  local abbrev_map = {}
  for key,val in abbrevs:gmatch("i%s%s(.-)%s%s*(.-)\n") do
    abbrev_map[key] = val
  end

  return abbrev_map
end

local abbrev_map = get_abbrevs()

local last_reminder = -1
function Check_for_abbrev()

  -- check current line for potential abbrevs, but prioritize most recently changed text
  -- nvim_get_current_line is a fallback, because . isn't updated as frequently
  local last_inserted_text = api.nvim_get_current_line() .. vim.fn['getreg']('.')

  local most_recent_possible_abbrev_index = -1
  local most_recent_possible_abbrev = {}

  for key,val in pairs(abbrev_map) do

    local last_match_idx = 0

     repeat

       local abbrev_index = last_inserted_text:find(val, last_match_idx)

       if abbrev_index ~= nil then
	 -- print(abbrev_index, val)
	 -- print(key, val)
	 most_recent_possible_abbrev_index = (abbrev_index > most_recent_possible_abbrev_index and abbrev_index) or most_recent_possible_abbrev_index
	 most_recent_possible_abbrev = (most_recent_possible_abbrev_index == abbrev_index and {key, val}) or most_recent_possible_abbrev

	 last_match_idx = abbrev_index + 1
       end

    until abbrev_index == nil

  end

  if (most_recent_possible_abbrev_index ~= -1 and last_reminder ~= most_recent_possible_abbrev_index)
    then

    print(last_reminder)
    last_reminder = most_recent_possible_abbrev_index

    api.nvim_echo({{'abbrev: "'..most_recent_possible_abbrev[1]..'"->'..'"'..most_recent_possible_abbrev[2]..'"'}}, {true}, {})

    -- open_window(most_recent_possible_abbrev[1])
  end
end



vim.cmd [[
augroup AbbrReminder
autocmd!
autocmd CursorMovedI,TextChanged * lua vim.api.nvim_buf_call(0, Check_for_abbrev)
augroup END
]]

