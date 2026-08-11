# Installing DOLFINx with pip

These are instructions for testing the `pip-installable` branch, which lets
DOLFINx be installed with a single `pip install` from a git URL. On the `main`
branch this is not possible: the Python interface requires the C++ library to be
configured, built and installed first, so installing means a clone and several
cmake invocations before pip is involved at all.

This branch adds a top level `CMakeLists.txt` and `pyproject.toml` that build
`cpp/` and `python/` together, following the layout Basix already uses.

pip cannot supply the C++ dependencies, so the apt step below is still needed.

## Prerequisites

```bash
sudo apt install -y build-essential cmake ninja-build pkg-config git \
  python3-dev python3-venv \
  libopenmpi-dev libhdf5-openmpi-dev libopenblas-dev \
  libboost-dev libpugixml-dev libspdlog-dev libptscotch-dev
```

## Install

Run the whole block. The order matters, see the note underneath.

```bash
sudo apt install -y build-essential cmake ninja-build pkg-config git \
  python3-dev python3-venv \
  libopenmpi-dev libhdf5-openmpi-dev libopenblas-dev \
  libboost-dev libpugixml-dev libspdlog-dev libptscotch-dev

python3 -m venv .venv
source .venv/bin/activate

# Build tools, plus Basix, FFCx and UFL from git. DOLFINx main requires versions
# of those three that are not released yet, so PyPI will not do.
pip install mpi4py numpy cffi scikit-build-core "nanobind>=2.9.2" ninja \
  "fenics-ufl@git+https://github.com/FEniCS/ufl.git" \
  "fenics-basix@git+https://github.com/FEniCS/basix.git" \
  "fenics-ffcx@git+https://github.com/FEniCS/ffcx.git"

# Optional, and slow: PETSc compiles from source, typically ten minutes or more.
# Skip these two if you do not need dolfinx.fem.petsc, but see the note below,
# they cannot be added afterwards without reinstalling DOLFINx.
pip install petsc petsc4py

pip install --no-build-isolation \
  "git+https://github.com/shimwell/dolfinx.git@pip-installable"
```

The last command uses `--no-build-isolation`, which means pip will not fetch the
build backend for you. Everything it builds against has to be installed already,
which is why it comes last. Running it on its own in a fresh environment fails
with:

```
BackendUnavailable: Cannot import 'scikit_build_core.build'
```

## Things that catch people out

**`--no-build-isolation` is required.** DOLFINx compiles against the mpi4py and
petsc4py already in your environment. With build isolation pip builds against
different copies, and petsc4py is not visible at all, in which case the PETSc
bindings are quietly compiled out and `dolfinx.fem.petsc` will be missing at
runtime. The build still succeeds, so this failure is silent.

**Install PETSc before DOLFINx.** Whether `dolfinx.fem.petsc` exists is decided
when DOLFINx is compiled. Installing petsc4py afterwards does not add it, you
have to reinstall DOLFINx.

**A serial HDF5 can shadow the parallel one.** DOLFINx requires an MPI enabled
HDF5. If configure stops with `Found serial HDF5, MPI HDF5 build required`, point
it at the right one:

```bash
pip install --no-build-isolation \
  -Ccmake.define.HDF5_ROOT=/usr/lib/x86_64-linux-gnu/hdf5/openmpi \
  "git+https://github.com/shimwell/dolfinx.git@pip-installable"
```

**PETSc no longer needs `PETSC_DIR`.** This branch also teaches the build to ask
the interpreter where a pip installed PETSc lives, so exporting `PETSC_DIR` by
hand is no longer necessary. An explicit `PETSC_DIR` still takes precedence if
you set one.

## Checking it worked

```bash
python -c "import dolfinx; print(dolfinx.__version__)"
python -c "from dolfinx.fem.petsc import LinearProblem; print('petsc bindings ok')"
```

The second command is the one that tells you whether the PETSc bindings were
built. If it raises `ModuleNotFoundError`, petsc4py was not present when DOLFINx
was compiled.
