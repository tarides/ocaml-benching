#!/bin/sh

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

binaries() {
  project=$1
  version=$2
  if [ "${BUILDING_TRUNK}" = "1" ] && [ "${project}" = "ocaml" ] ; then
      build_dir="$(pwd)"
  else
      if [ "${project}" = "ocaml" ]; then
          project_dir="ocaml-base-compiler.${version}";
      else
          project_dir="${project}.${version}/_build/default/";
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
    | awk "{sum[\$2] += \$1} END{for (i in sum) print \"binaries\\t$project/\" i \"\\t\" sum[i] \"\tkb\"}" \
    >> "$BENCHMARK_FILE"
  cd "${HERE}" || exit
}

timings() {
  project=$1
  sed 's/^-  / /g' build.log \
    | grep '^\s\s[0-9]\+\.[0-9]\+s ' \
    | awk "{sum[\$2] += \$1} END{for (i in sum) print \"projects\\t$project/\" i \"\\t\" sum[i] \"\tsecs\"}" \
    >> "$BENCHMARK_FILE"
}

print_benchmark_stats() {
  project=$1
  version=$2
  timings "${project}"
  binaries "${project}" "${version}"
  LC_NUMERIC=POSIX awk -f "${HERE}/to_json.awk" -v TARGET_PROJECT_VERSION="${version}" < "$BENCHMARK_FILE"
  rm "$BENCHMARK_FILE"
}

create_switch_by_version() {
    rm -f build.log
    OCAMLPARAM=",_,timings=1" opam switch create -b -v "${OCAML_SWITCH}" "${OCAML_VERSION}" 2>&1 | tee -a build.log
    eval "$(opam env --switch=${OCAML_SWITCH} --set-switch)"
}

create_switch_latest() {
    OCAMLPARAM=",_,timings=1" opam switch create --empty -b -v "${OCAML_SWITCH}"
    eval "$(opam env --switch=${OCAML_SWITCH} --set-switch)"
    OCAML_DIR="${HERE}/../ocaml"
    if [ ! -d "${OCAML_DIR}" ]; then
        git clone https://github.com/ocaml/ocaml "${OCAML_DIR}"
    fi
    cd "${OCAML_DIR}" || exit
    opam install . --yes
    make clean
    rm -f build.log
    ./configure
    OCAMLPARAM=",_,timings=1" make world.opt 2>&1 | tee -a build.log
    OCAML_VERSION=$(git rev-parse HEAD)
}

bootstrap() {
  for _ in $(seq 1 "$NB_RUNS"); do
    opam switch remove "${OCAML_SWITCH}" --yes
    if [ "${BUILDING_TRUNK}" = "1" ]
    then
        create_switch_latest
    else
        create_switch_by_version
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
    OCAMLPARAM=",_,timings=1" opam install -b --verbose -y "${project}=${version}" 2>&1 | tee -a build.log | sed 's/^{/ {/'
    print_benchmark_stats "${1}" "${2}"
  done
}

bootstrap
project_build dune 3.2.0
project_build decompress 1.4.2
project_build ocamlgraph 2.0.0
# FIXME: Also installs menhirLib & menhirSdk (previously '--only-packages=menhir')
project_build menhir 20220210
# FIXME: Not on opam repo
# project_build ocaml-containers
# project_build deque
