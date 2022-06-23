FROM ocaml/opam:debian-10-ocaml-4.12

RUN sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev \
        libpcre3-dev curl build-essential \
        liblapacke-dev libopenblas-dev libplplot-dev libshp-dev \
        zlib1g-dev libgtksourceview-3.0-dev

RUN opam remote add origin https://opam.ocaml.org --all-switches \
    && opam repository add opam-repo https://github.com/ocaml/opam-repository.git --all-switches \
    && opam repository add alpha git+https://github.com/kit-ty-kate/opam-alpha-repository --all-switches \
    && opam repository add dune-universe git+https://github.com/dune-universe/opam-overlays.git --all-switches --set-default \
    && opam update \
    && opam install -y dune \
    && eval $(opam env)

RUN mkdir ocaml-benching
WORKDIR ocaml-benching
COPY --chown=opam:opam . .
ARG OCAML_VERSION
ENV OCAML_VERSION=${OCAML_VERSION}
