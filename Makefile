tests:
	nvim --headless -i NONE --noplugin -u test/minimal_init.vim -c "PlenaryBustedDirectory test/plenary/ {minimal_init = 'test/minimal_init.vim'}"

testfile:
	nvim --headless -i NONE --noplugin -u test/minimal_init.vim -c "PlenaryBustedFile $(FILE)"
