FROM ocaml/opam:debian-10-ocaml-4.12

RUN sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev \
        libpcre3-dev curl build-essential \
        liblapacke-dev libopenblas-dev libplplot-dev libshp-dev \
        zlib1g-dev libgtksourceview-3.0-dev \
        libexpat1-dev libgnomecanvas2-dev libgtk2.0-dev

RUN sudo rm /usr/bin/opam && sudo ln -s /usr/bin/opam-2.1 /usr/bin/opam

RUN opam remote add origin https://opam.ocaml.org --all-switches \
    && opam repository add opam-repo https://github.com/ocaml/opam-repository.git --all-switches \
    && opam repository add alpha git+https://github.com/kit-ty-kate/opam-alpha-repository --all-switches \
    && opam repository add dune-universe git+https://github.com/dune-universe/opam-overlays.git --all-switches --set-default \
    && opam update \
    && opam install -y dune \
    && eval $(opam env)

RUN git clone 'https://github.com/art-w/deque/'

RUN git clone 'https://github.com/ocaml/dune'

RUN git clone 'https://github.com/c-cube/ocaml-containers'

RUN git clone 'https://gitlab.inria.fr/fpottier/menhir.git'

RUN git clone 'https://github.com/ocaml/zarith'

RUN git clone 'https://github.com/mirage/decompress'

RUN git clone 'https://github.com/ocaml/opam'

RUN git clone 'https://github.com/coq/coq'

RUN git clone 'https://github.com/mirage/irmin'

# monorepo issue: functoria requires rresult>=0.7.0 which is not available in dune-universe
# RUN git clone 'https://github.com/mirage/mirage/' \
#     && cd mirage && opam monorepo lock && opam monorepo pull && cd ..

RUN git clone 'https://github.com/backtracking/ocamlgraph.git'

# RUN git clone 'https://github.com/owlbarn/owl.git'

# RUN git clone 'https://github.com/ocsigen/lwt'

# RUN git clone 'https://github.com/emillon/js-monorepo' \
#     && cd js-monorepo && opam monorepo pull && cd ..

RUN git clone 'https://github.com/ocaml/ocaml'

RUN mkdir ocaml-benching
WORKDIR ocaml-benching
COPY --chown=opam:opam . .
