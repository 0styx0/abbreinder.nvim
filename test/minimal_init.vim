set rtp+=.
set rtp+=./plenary.nvim
set noswapfile
runtime plugin/plenary.vim
runtime plugin/abolish.vim


" note: if shada error, `rm ~/.local/share/nvim/shada/main.shada`

lua << EOF
require'abbreinder'.setup()
EOF


