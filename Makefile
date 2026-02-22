## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## all: lint and run tests
.PHONY: all
all: lint test

## test: run tests
.PHONY: test
test:
	./run_tests.sh

## lint: run linters and LuaLS typechecking
.PHONY: lint
lint: scripts/nvim-typecheck-action
	./scripts/nvim-typecheck-action/typecheck.sh --workdir scripts/nvim-typecheck-action lua
	luacheck lua tests --formatter plain
	stylua --check lua tests

## profile: use LuaJIT profiler to profile the plugin
.PHONY: profile
profile: scripts/benchmark.nvim
	nvim --clean -u perf/bootstrap.lua -c 'lua jit_profile()'

## flame_profile: create a trace in the chrome profiler format
.PHONY: flame_profile
flame_profile: scripts/benchmark.nvim
	nvim --clean -u perf/bootstrap.lua -c 'lua flame_profile()'

## benchmark: benchmark performance opening directory with many files
.PHONY: benchmark
benchmark: scripts/benchmark.nvim
	nvim --clean -u perf/bootstrap.lua -c 'lua benchmark()'
	@cat perf/tmp/benchmark.txt

scripts/nvim-typecheck-action:
	git clone https://github.com/stevearc/nvim-typecheck-action scripts/nvim-typecheck-action

scripts/benchmark.nvim:
	git clone https://github.com/stevearc/benchmark.nvim scripts/benchmark.nvim

## clean: reset the repository to a clean state
.PHONY: clean
clean:
	rm -rf scripts/nvim-typecheck-action venv .testenv perf/tmp profile.json
