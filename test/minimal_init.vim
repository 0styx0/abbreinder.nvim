set rtp+=.
set rtp+=./plenary.nvim
set noswapfile
runtime plugin/plenary.vim


" possible add runtime plugin/abolish.vim

" set termguicolors " maybe needed for highlight testing?

lua << EOF
require'abbreinder'.setup()
EOF


