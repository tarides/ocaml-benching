#!/bin/bash

# The script bootstraps an OCaml switch using a specified OCaml version, and
# runs benchmarks by building a fixed set of projects at specific versions.

# OCAML_VERSION environment variable can be used to specify a specific version
# of OCaml to use to run the benchmarks. If the env var is not set, the latest
# trunk of ocaml/ocaml is used.

OCAML_VERSION="${OCAML_VERSION:-latest}"
echo "OCAML_VERSION=${OCAML_VERSION}"

if [ "${OCAML_VERSION}" = "latest" ];
then
    export BUILDING_TRUNK=1
else
    export BUILDING_TRUNK=0
fi

export NB_RUNS=1
BENCHMARK_FILE="$(realpath "${1:-sample.tsv}")"
export BENCHMARK_FILE
HERE=$(realpath "$(dirname "$0")")
export HERE

OCAML_SWITCH="ocaml-benching"

building_from_git() {
    if [ "${BUILDING_TRUNK}" = "1" ] || [[ "${OCAML_VERSION}" =~ 4.(09|10|11|12|13).* ]]
    then
        return 0
    else
        return 1
    fi
}

binaries() {
  project=$1
  version=$2
  bench_name=$project
  if building_from_git && [ "${project}" = "ocaml" ] ; then
      build_dir="$(pwd)"
  else
      if [ "${project}" = "ocaml" ] && [[ "${version}" == *+* ]]; then
          project_dir="ocaml-variants.${version}";
      elif [ "${project}" = "ocaml" ]; then
          project_dir="ocaml-base-compiler.${version}";
      else
          project_dir="${project}.${version}/_build/default/";
          bench_name="${project}-${version}"
      fi
      build_dir="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${project_dir}"
      cd "${build_dir}" || exit
  fi
  find . -type f \
    | grep -ve '\.git' -ve '_opam' -ve '.aliases' -ve '.merlin' \
    | xargs -n1 file -i \
    | grep 'binary$' \
    | cut -f1 -d: \
    | xargs -n1 du -s \
    | sed -E 's;\..*/(.*);\1;g' \
    | grep -ve '\s\..*' \
    | sed -E 's;([0-9]+).*\.(.*);\1\t\2;g' \
    | awk "{sum[\$2] += \$1} END{for (i in sum) print \"binaries\\t$bench_name/\" i \"\\t\" sum[i] \"\tkb\"}" \
    >> "$BENCHMARK_FILE"
  cd "${HERE}" || exit
}

timings() {
  project=$1
  version=$2
  bench_name=$project
  if [ "${project}" = "ocaml" ]; then
      bench_name="${project}"
  else
      bench_name="${project}-${version}"
  fi
  sed 's/^-  / /g' build.log \
    | grep '^\s\s[0-9]\+\.[0-9]\+s ' \
    | awk "{sum[\$2] += \$1} END{for (i in sum) print \"projects\\t$bench_name/\" i \"\\t\" sum[i] \"\tsecs\"}" \
    >> "$BENCHMARK_FILE"
}

timings_old_ocaml() {
  project=$1
  sed 's/^- //g' build.log \
      | grep -P '^.+\(.+\):' \
      | sed 's/(.*)://g' \
      | sed 's/s$//g' \
      | awk "{sum[\$1] += \$2} END{for (i in sum) print \"projects\\t$project/\" i \"\\t\" sum[i] \"\tsecs\"}" \
    >> "$BENCHMARK_FILE"
}

print_benchmark_stats() {
  project=$1
  version=$2
  if [[ "${OCAML_VERSION}" = 4.05* ]] && ! [[ "${project}" =~ dune ]];
  then
      timings_old_ocaml "${project}"
  else
      timings "${project}" "${version}"
  fi
  binaries "${project}" "${version}"
  LC_NUMERIC=POSIX awk -f "${HERE}/to_json.awk" -v TARGET_PROJECT_VERSION="${version}" < "$BENCHMARK_FILE"
  rm "$BENCHMARK_FILE"
}

fix_makefile_opcodes_target() {
  # Work around issue with generating opcodes with timing information turned on
  sed -i 's/$(CAMLC) -i $< > $@/OCAMLPARAM=",_,timings=0" $(CAMLC) -i $< > $@/g' Makefile
}

create_switch_from_opam_version() {
    echo "Using OCaml from opam ..."
    rm -f build.log
    OCAMLPARAM="_,timings=1" opam switch create -b -v "${OCAML_SWITCH}" "${OCAML_VERSION}" 2>&1 | tee -a build.log
    eval "$(opam env --switch=${OCAML_SWITCH} --set-switch)"
}

create_switch_from_git_version() {
    echo "Using OCaml from git ..."
    OCAMLPARAM="_,timings=1" opam switch create --empty -b -v "${OCAML_SWITCH}"
    eval "$(opam env --switch=${OCAML_SWITCH} --set-switch)"
    if [ -f "${HERE}/../VERSION" ]; then
        OCAML_DIR="${HERE}/../"
    else
        OCAML_DIR="${HERE}/../ocaml"
    fi
    if [ ! -d "${OCAML_DIR}" ]; then
        git clone https://github.com/ocaml/ocaml "${OCAML_DIR}"
    fi
    cd "${OCAML_DIR}" || exit
    if ! [ "${BUILDING_TRUNK}" = "1" ];
    then
        git reset --hard "${OCAML_VERSION}"
        fix_makefile_opcodes_target
    else
        git reset --hard trunk
    fi
    opam install . --yes
    make clean
    rm -f build.log
    ./configure
    OCAMLPARAM="_,timings=1" make world.opt 2>&1 | tee -a build.log
    if [ "${BUILDING_TRUNK}" = "1" ];
    then
        OCAML_VERSION=$(git rev-parse HEAD)
    fi
    # Set invariant to prevent OCaml version changes
    INVARIANT_VERSION=$(opam list -i ocaml --columns=version --short)
    opam switch set-invariant ocaml="${INVARIANT_VERSION}"
}

bootstrap() {
  opam repository add ocaml-beta --set-default git+https://github.com/ocaml/ocaml-beta-repository.git
  for _ in $(seq 1 "$NB_RUNS"); do
    opam switch remove "${OCAML_SWITCH}" --yes
    if building_from_git
    then
        create_switch_from_git_version
    else
        create_switch_from_opam_version
    fi
    ocaml --version
    opam switch list
    print_benchmark_stats "ocaml" "${OCAML_VERSION}"
  done
}


project_build() {
  project=$1
  version=$2
  for _ in $(seq 1 "$NB_RUNS"); do
    rm -f build.log
    opam uninstall "${project}" -y
    OCAMLPARAM="_,timings=1" opam install -b --verbose -y "${project}=${version}" 2>&1 | tee -a build.log | sed 's/^{/ {/'
    print_benchmark_stats "${1}" "${2}"
  done
}

setup_requirements() {
    sudo apt-get update && sudo apt-get install -qq -yy --no-install-recommends file
}

setup_requirements
bootstrap
# NOTE: When adding a new project, test building with OCAML_VERSION=4.05.0 and
# use the timings_old_ocaml parser for it, if required.
project_build dune 3.4.1
project_build ocamlgraph 2.0.0
project_build menhir 20230608
project_build ppxlib 0.27.0
