.PHONY: bench
bench:
	$(eval BENCHMARK_FILE=$(shell mktemp bench.XXX.tsv))
	$(eval export BENCHMARK_FILE=$(shell realpath $(BENCHMARK_FILE)))
	$(shell ./bench.sh "$(BENCHMARK_FILE)" 1>&2)

.PHONY: version
version/%:
	$(eval OCAML_VERSION = $*)
	@sed -i 's/OCAML_VERSION="[0-9.]\+"/OCAML_VERSION="${OCAML_VERSION}"/g' bench.sh
	@git add bench.sh
	@git commit -m "WIP: Run benchmarks for OCaml ${OCAML_VERSION}"
