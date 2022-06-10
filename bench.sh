#!/bin/sh

export NB_RUNS=1
BENCHMARK_FILE="$(realpath "${1}")"
export BENCHMARK_FILE
HERE=$(realpath "$(dirname "$0")")
export HERE

OCAML_VERSION="4.14.0"
OCAML_SWITCH="ocaml-benching"

binaries() {
  project=$1
  version=$2
  if [ "${project}" = "ocaml" ]; then
    project_dir="ocaml-base-compiler.${version}";
  else
    project_dir="${project}.${version}/_build/default/";
  fi
  build_dir="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${project_dir}"
  cd "${build_dir}" || exit
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
  LC_NUMERIC=POSIX awk -f "${HERE}/to_json.awk" < "$BENCHMARK_FILE"
  rm "$BENCHMARK_FILE"
}

bootstrap() {
  for i in $(seq 1 "$NB_RUNS"); do
    rm -f build.log
    opam switch remove "${OCAML_SWITCH}" --yes
    OCAMLPARAM=",_,timings=1" opam switch create -b -v "${OCAML_SWITCH}" "${OCAML_VERSION}" | tee -a build.log
    eval "$(opam env --switch=${OCAML_SWITCH} --set-switch)"
    ocaml --version
    opam switch list
    print_benchmark_stats "ocaml" "${OCAML_VERSION}"
  done
}

project_build() {
  project=$1
  version=$2
  for i in $(seq 1 "$NB_RUNS"); do
    rm -f build.log
    opam uninstall "${project}" -y
    OCAMLPARAM=",_,timings=1" opam install -b --verbose -y "${project}=${version}" | tee -a build.log | sed 's/^{/ {/'
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
