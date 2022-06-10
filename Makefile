.PHONY: bench
bench:
	$(eval BENCHMARK_FILE=$(shell mktemp bench.XXX.tsv))
	$(eval export BENCHMARK_FILE=$(shell realpath $(BENCHMARK_FILE)))
	$(shell ./bench.sh "$(BENCHMARK_FILE)" 1>&2)
