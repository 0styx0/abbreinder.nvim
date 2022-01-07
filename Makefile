prepare:
	@git submodule update --depth 1 --init

test: prepare
	@nvim \
			--headless \
			--noplugin \
			-u test/minimal_init.vim \
			-c "PlenaryBustedDirectory test/ { minimal_init = 'test/minimal_init.vim' }"
