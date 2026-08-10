# ------------------------------------------------------------------------------
# Top level CMakeLists.txt for building the DOLFINx C++ library and the Python
# interface together, so that "pip install ." works from a source tree.
cmake_minimum_required(VERSION 3.26)

project(DolfinxFull VERSION "0.12.0.0" LANGUAGES CXX)

set(DOLFINX_FULL_SKBUILD TRUE)

add_subdirectory(cpp)
add_subdirectory(python)
