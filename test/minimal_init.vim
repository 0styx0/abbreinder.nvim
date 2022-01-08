set rtp+=.
set rtp+=vendor/plenary/
runtime plugin/plenary.vim
set noswapfile

" note: if shada error, `rm ~/.local/share/nvim/shada/main.shada`

" this line is important. in helpers.lua#type_text, for some reason
" abbriender.start's nvim_buf_attach on_bytes does not trigger except on the
" last character passed in to nvim_feedkeys. this means that
" abbreinder._keylogger is not properly updated and tests do not work as they
" should. adding an InsertCharPre autocmd that appears to do nothing fixes the
" issue and successfully triggers on_bytes as intended (possibly by
" jumstarting the event queue on each insertion, idk). took me a while to solve.
" although since I still couldn't get it working, I'm pretty sure this is a
" piece of the solution but I'm giving up.
" moved to using ./test/plenary/integration_manual_tests.lua
" autocmd InsertCharPre * :lua require('abbreinder')._keylogger = require('abbreinder')._keylogger:sub(1, -2)

