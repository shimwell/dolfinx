#!/bin/bash
# Restore libdolfinx's stable SONAME after auditwheel has vendored it under a
# build-specific, hash-containing name.
set -eo pipefail

root="$1"
mapfile -t mangled_libraries < <(
    find "$root/fenics_dolfinx.libs" -name 'libdolfinx-*.so.*' -type f 2>/dev/null
)

if [ "${#mangled_libraries[@]}" -eq 0 ]; then
    echo "no vendored libdolfinx found in $root, nothing to do"
    exit 0
fi
if [ "${#mangled_libraries[@]}" -ne 1 ]; then
    echo "expected one vendored libdolfinx, found ${#mangled_libraries[@]}" >&2
    exit 1
fi

mangled="${mangled_libraries[0]}"
mangled_name=$(basename "$mangled")

# libdolfinx-<hash>.so.0.12.0.0 -> libdolfinx.so.0.12
full_version=${mangled##*.so.}
soname="libdolfinx.so.$(echo "$full_version" | cut -d. -f1,2)"
stable_library="$root/dolfinx/lib/$soname"

mkdir -p "$root/dolfinx/lib"
mv "$mangled" "$stable_library"
patchelf --set-soname "$soname" "$stable_library"
# libdolfinx's vendored dependencies remain where auditwheel placed them.
patchelf --set-rpath "\$ORIGIN/../../fenics_dolfinx.libs" "$stable_library"

# Point each ELF object that referenced the mangled name at the stable one.
while read -r library; do
    needed=$(patchelf --print-needed "$library" 2>/dev/null || true)
    case "$needed" in
        *"$mangled_name"*)
            patchelf --replace-needed "$mangled_name" "$soname" "$library"
            relative_lib_dir=$(realpath --relative-to="$(dirname "$library")" \
                "$root/dolfinx/lib")
            patchelf --add-rpath "\$ORIGIN/$relative_lib_dir" "$library"
            ;;
    esac
done < <(find "$root" -type f \( -name '*.so' -o -name '*.so.*' \))

if [ "$(patchelf --print-soname "$stable_library")" != "$soname" ]; then
    echo "failed to restore libdolfinx SONAME" >&2
    exit 1
fi

echo "libdolfinx now ships as dolfinx/lib/$soname"
