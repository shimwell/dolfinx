# Copyright (C) 2017 Chris N. Richardson and Garth N. Wells
#
# This file is part of DOLFINx (https://www.fenicsproject.org)
#
# SPDX-License-Identifier:    LGPL-3.0-or-later
"""Main module for DOLFINx"""

# flake8: noqa

import sys
# Template placeholder for injecting Windows dll directories in CI
# WINDOWSDLL

import typing as _typing

import numpy as _np

default_scalar_type: type[_np.floating | _np.complexfloating]
default_real_type: type[_np.floating]


def _preload_petsc() -> None:
    """Open libpetsc from a pip-installed petsc package.

    A wheel does not vendor libpetsc, because petsc4py and DOLFINx have to
    share a single copy of it. The petsc package installs the library to
    site-packages/petsc/lib, a sibling of site-packages/dolfinx, and nothing
    puts that directory on the loader path, so importing the compiled modules
    fails with "libpetsc.so.3.25: cannot open shared object file". Opening the
    library here by absolute path puts it in the process before anything that
    needs it is loaded, and the loader then satisfies those dependencies from
    the library already in the link map.

    Does nothing when the petsc package is absent, which is every build that
    is not against a pip-installed PETSc.
    """
    if sys.platform == "win32":
        return

    import ctypes
    import glob
    import os

    try:
        import petsc
    except ImportError:
        return

    pattern = "libpetsc*.dylib" if sys.platform == "darwin" else "libpetsc.so*"
    for candidate in sorted(glob.glob(os.path.join(petsc.get_petsc_dir(), "lib", pattern))):
        try:
            ctypes.CDLL(candidate, mode=ctypes.RTLD_GLOBAL)
        except OSError:
            continue
        else:
            return


_preload_petsc()

try:
    from petsc4py import PETSc as _PETSc
except ImportError:
    default_scalar_type = _np.float64
    default_real_type = _np.float64
else:
    # Only the petsc4py import is guarded; a failure below is a broken install.

    # Additional sanity check that DOLFINx was built with petsc4py support.
    from dolfinx.common import has_petsc4py

    if not has_petsc4py:
        raise RuntimeError("DOLFINx has not been built with petsc4py support.")

    # petsc4py's stub types these as numpy.dtype instances rather than
    # the type objects they actually are at runtime.
    default_scalar_type = _typing.cast(
        "type[_np.floating | _np.complexfloating]", _PETSc.ScalarType
    )
    default_real_type = _typing.cast("type[_np.floating]", _PETSc.RealType)

del _np

from dolfinx import common
from dolfinx import cpp as _cpp
from dolfinx import fem, geometry, graph, io, jit, la, log, mesh, plot, typing

from dolfinx.common import (
    git_commit_hash,
    hardware_concurrency,
    has_adios2,
    has_complex_ufcx_kernels,
    has_debug,
    has_kahip,
    has_parmetis,
    has_petsc,
    has_petsc4py,
    has_ptscotch,
    has_slepc,
    has_superlu_dist,
    ufcx_signature,
)

from importlib.metadata import version

__version__ = version("fenics-dolfinx")

_cpp.common.init_logging(sys.argv)
del _cpp, sys


def get_include(user: bool = False) -> str:
    import os

    d = os.path.dirname(__file__)
    if os.path.exists(os.path.join(d, "wrappers")):
        # Package is installed
        return os.path.join(d, "wrappers")
    else:
        # Package is from a source directory
        return os.path.join(os.path.dirname(d), "src")


__all__ = [
    "fem",
    "common",
    "geometry",
    "graph",
    "io",
    "jit",
    "la",
    "log",
    "mesh",
    "plot",
    "typing",
    "git_commit_hash",
    "hardware_concurrency",
    "has_adios2",
    "has_complex_ufcx_kernels",
    "has_debug",
    "has_kahip",
    "has_parmetis",
    "has_petsc",
    "has_petsc4py",
    "has_ptscotch",
    "has_slepc",
    "ufcx_signature",
]
