.PHONY: default help compile test geth env run remsh remsherl shell dialyzer cover credo perf

default: compile

help:        ## show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

compile:     ## compile
	mix compile

test:        ## run tests
test: compile
	mix test --no-start --include requires_geth

geth:        ## `geth --dev` with personal api enabled
geth:
	geth --dev --dev.period 2 --rpc --rpcapi personal,web3,eth

env:         ## deploy contract, fund authority address and write dev.exs file
	mix run --no-start -e 'OmiseGO.Eth.DevHelpers.prepare_dev_env()'

run:         ## run the node in dev mode; see also `geth`, `env` and `eth_block` targets
run: compile
	iex --sname main -S mix

remsh:       ## iex shell to running node
remsh:
	iex --sname shell --remsh 'main@$(hostname -f)' -S mix run --no-start

remsherl:    ## erl shell to running node
remsherl:
	erl --sname shell --remsh 'main@$(hostname -f)'

shell:       ## iex with all code loaded
shell:
	iex -S mix run --no-start

dialyzer:    ## dialyze
dialyzer: compile
	mix dialyzer

cover:       ## check coverage
cover:
	mix coveralls.html --umbrella --no-start --include integration

credo:       ## run linter
credo:
	mix credo

perf:        ## run performance test
perf:
	echo "iex --sname main -S mix run apps/honted_integration/scripts/performance.exs --nstreams 100 --fill-in 0 --duration 120"
