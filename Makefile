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

## lint: run selene and stylua
.PHONY: lint
lint:
	selene --display-style quiet .
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

scripts/benchmark.nvim:
	git clone https://github.com/stevearc/benchmark.nvim scripts/benchmark.nvim

## clean: reset the repository to a clean state
.PHONY: clean
clean:
	rm -rf .testenv perf/tmp profile.json
