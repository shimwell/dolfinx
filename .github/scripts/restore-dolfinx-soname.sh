#!/bin/bash
# Restore libdolfinx's real soname inside the wheel.
#
# auditwheel vendors libdolfinx into fenics_dolfinx.libs under a
# build-specific name, libdolfinx-<hash>.so.<version>, and rewrites the soname
# to match. Nothing outside that one build can link against it, because the
# hash changes every time the wheels are rebuilt. That blocks any downstream
# package with compiled DOLFINx bindings, scifem for example, which asks the
# loader for libdolfinx.so.0.12 and gets "cannot open shared object file".
#
# basix does not have this problem: its wheel keeps libbasix.so.0 inside the
# package under its real name. Do the same here.
#
# This runs after auditwheel rather than excluding libdolfinx from it, because
# auditwheel finds HDF5, SCOTCH, Boost, spdlog and pugixml by walking
# libdolfinx's dependencies. Excluding it would leave all of those unvendored.
set -eo pipefail

root="$1"   # unpacked wheel directory
mangled=$(find "$root/fenics_dolfinx.libs" -name 'libdolfinx-*.so.*' -type f 2>/dev/null | head -1)
if [ -z "$mangled" ]; then
    echo "no vendored libdolfinx found in $root, nothing to do"
    exit 0
fi

# libdolfinx-<hash>.so.0.12.0.0 -> 0.12
full=${mangled##*.so.}
soname="libdolfinx.so.$(echo "$full" | cut -d. -f1,2)"

mkdir -p "$root/dolfinx/lib"
mv "$mangled" "$root/dolfinx/lib/$soname"
patchelf --set-soname "$soname" "$root/dolfinx/lib/$soname"
# its own vendored dependencies stay where auditwheel put them, and petsc
# comes from the petsc wheel
patchelf --set-rpath '$ORIGIN/../../fenics_dolfinx.libs:$ORIGIN/../../petsc/lib' \
    "$root/dolfinx/lib/$soname"

# Point everything that referenced the mangled name at the real one.
# Note: do not pipe patchelf into "grep -q" here. grep -q exits on the first
# match, patchelf then dies of SIGPIPE, and under pipefail the whole condition
# reads as false even when the name does match.
mangled_name=$(basename "$mangled")
while read -r f; do
    needed=$(patchelf --print-needed "$f")
    case "$needed" in
        *"$mangled_name"*)
            patchelf --replace-needed "$mangled_name" "$soname" "$f"
            patchelf --add-rpath '$ORIGIN/lib' "$f"
            ;;
    esac
done < <(find "$root" -name "*.so" -type f)

echo "libdolfinx now ships as dolfinx/lib/$soname"
