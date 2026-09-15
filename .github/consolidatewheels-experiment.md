# `consolidatewheels` experiment

This branch applies `consolidatewheels==0.5` to the repaired Linux DOLFINx and
scifem wheels. It is an isolated downstream experiment and does not change the
CMake proposal in FEniCS/dolfinx#4528.

## Expected supported case

On Linux, the tool discovers auditwheel libraries matching
`*.libs/*.so`. For example, it maps `libexample-deadbeef.so` back to
`libexample.so` and rewrites matching `DT_NEEDED` entries in all supplied
wheels.

## DOLFINx case

DOLFINx gives `libdolfinx` a versioned SONAME. Auditwheel consequently embeds
it as `libdolfinx-<hash>.so.0.12.0.0`, while a separately built scifem wheel
requires the ABI SONAME `libdolfinx.so.0.12`.

Version 0.5 only discovers files ending exactly in `.so`, so it does not add
the embedded DOLFINx library to its mangling map. The command still exits
successfully, but scifem's dependency is unchanged and a clean direct
`import scifem` fails.

The workflow records the actual bundled filename and scifem `DT_NEEDED` entry
in the GitHub Actions job summary, then confirms the import failure in a clean
Python container. This demonstrates that the approach works for unversioned
Linux shared libraries but needs versioned-SONAME support for DOLFINx.