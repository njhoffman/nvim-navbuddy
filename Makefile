DEPS_DIR := deps

.PHONY: deps test test-unit test-integration clean

deps:
	@mkdir -p $(DEPS_DIR)
	@test -d $(DEPS_DIR)/plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(DEPS_DIR)/plenary.nvim
	@test -d $(DEPS_DIR)/nvim-navic || git clone --depth 1 https://github.com/SmiteshP/nvim-navic $(DEPS_DIR)/nvim-navic
	@test -d $(DEPS_DIR)/nui.nvim || git clone --depth 1 https://github.com/MunifTanjim/nui.nvim $(DEPS_DIR)/nui.nvim

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

test-unit: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/unit/ {minimal_init = 'tests/minimal_init.lua'}"

test-integration: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration/ {minimal_init = 'tests/minimal_init.lua'}"

clean:
	rm -rf $(DEPS_DIR)
