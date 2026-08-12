# hyrax-dependencies (hyrax-1.18.0 tree) build fixes for giraffe (CentOS 7.9)

These patches fix `make` failures for the hyrax-dependencies build in
`/home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0` on **giraffe**
(CentOS Linux 7.9.2009).

## Root cause

giraffe ships an ancient default toolchain that the modern dependency
versions no longer accept:

| tool  | giraffe default | required by deps |
|-------|-----------------|------------------|
| cmake | 2.8.12.2        | openjpeg ≥3.5, hdf5 ≥3.13 (`-S/-B`), proj ≥3.16 |
| git   | 1.8.3.1         | aws-sdk-cpp uses `git clone --shallow-submodules` (git ≥2.9) |
| gcc   | 4.8.5           | proj 9 / aws-sdk-cpp need C++17 |
| sqlite| 3.7.17          | proj 9.5.1 needs SQLite3 ≥3.11 |

The upstream CI builds on macOS (brew) and Rocky 8/9 containers, which
provide modern cmake/git/gcc/sqlite natively — so these problems never
surface there. On giraffe they must be supplied by hand.

## Toolchain used to build (source these before `make`)

```bash
# modern cmake (already staged on giraffe)
export PATH=/home/hyoklee/bin/cmake-3.26.0-linux-x86_64/bin:$PATH
# symlinks into $prefix/deps/bin also make cmake/ctest/cpack resolve early:
#   ln -sf /home/hyoklee/bin/cmake-3.26.0-linux-x86_64/bin/{cmake,ctest,cpack,ccmake,cmake-gui} \
#          /home/hyoklee/pkg/hyrax-1.8.0/deps/bin/

# modern C++ compiler (gcc 5.4 via /home/tomcat/bin, or devtoolset-8)
source /opt/rh/devtoolset-8/enable   # or ensure /home/tomcat/bin gcc is on PATH

# hyrax prefix + PATH/LD_LIBRARY_PATH
source spath.sh
```

## Per-package fixes

- **openjpeg-2.5.3** — no source change; needs cmake ≥3.5 (use 3.26). See its dir.
- **proj-9.5.1** — no source change; needs cmake ≥3.16, C++17, and **SQLite3 ≥3.11**.
  CentOS 7's sqlite (3.7.17) is too old and the Makefile intentionally no longer
  builds sqlite ("part of OSX and Linux"), so sqlite-3.45.3 was built into
  `$prefix/deps`. See its dir for the build recipe.
- **hdf5-2.1.1** — no source change; the rule uses `cmake -S . -B build`, which
  needs cmake ≥3.13 (use 3.26).
- **aws_sdk_cpp-1.11.665** — `Makefile.patch`: drop `--shallow-submodules`
  (unsupported by git 1.8.3) and add `-DUSE_OPENSSL=OFF -DENABLE_TESTING=OFF`
  to the cmake configure. See its dir.
- **gdal-3.2.1** — SKIPPED per instruction (not built).

## Result

`make list-built` after the fixes:

```
aws_cdk, bison, gridfields, hdf4, hdf5, hdfeos, jpeg, netcdf4,
openjpeg, proj, stare   → built and installed
gdal                    → skipped (intentional)
```

## Downstream components

Build order: deps → **libdap4** → **bes**. The whole stack must use one C++
compiler/ABI — build everything with `g++` = gcc 5.4 (`/home/tomcat/bin`, new
`_GLIBCXX_USE_CXX11_ABI=1`). Do not let cmake auto-pick devtoolset-8's `c++`
(old ABI) for libdap, or BES will fail to link against it.

- **libdap4-3.22.0** — built with cmake against these deps and installed to
  `$prefix` (not `$prefix/deps`). Needs a CppUnit built into `$prefix/deps`
  (`build-cppunit.sh`), two CentOS 7 source patches, and **must be built with
  gcc 5.4** for ABI consistency. See its dir.
- **bes-3.22.0-0** — built with autotools against the installed libdap
  (`dap-config`) and the deps, installed to `$prefix`. No BES source patches;
  needs a libbz2 dev symlink and OpenSSL >= 1.1 (`/usr/local`). See its dir.
