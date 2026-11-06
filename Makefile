DEPS_DIR := deps

PLENARY_REF := b9fd5226c2f76c951fc8ed5923d85e4de065e509
NAVIC_REF := f5eba192f39b453675d115351808bd51276d9de5
NUI_REF := de740991c12411b663994b2860f1a4fd0937c130

# $(call clone_dep,name,url,ref)
clone_dep = test -d $(DEPS_DIR)/$(1) || (git clone --quiet --filter=blob:none $(2) $(DEPS_DIR)/$(1) && git -C $(DEPS_DIR)/$(1) checkout --quiet $(3))

.PHONY: deps test test-unit test-integration clean

deps:
	@mkdir -p $(DEPS_DIR)
	@$(call clone_dep,plenary.nvim,https://github.com/nvim-lua/plenary.nvim,$(PLENARY_REF))
	@$(call clone_dep,nvim-navic,https://github.com/SmiteshP/nvim-navic,$(NAVIC_REF))
	@$(call clone_dep,nui.nvim,https://github.com/MunifTanjim/nui.nvim,$(NUI_REF))

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

test-unit: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/unit/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

test-integration: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

clean:
	rm -rf $(DEPS_DIR)
