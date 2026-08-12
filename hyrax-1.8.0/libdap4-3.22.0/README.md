# libdap4-3.22.0 — build & install on giraffe (CentOS 7.9)

Builds libdap4 3.22.0 with cmake against the hyrax dependencies and installs
to the hyrax prefix (`$prefix` = `/home/hyoklee/pkg/hyrax-1.8.0`), same tree the
deps use (deps live under `$prefix/deps`).

## Prerequisites

Source the giraffe toolchain env first (cmake 3.26, gcc, sqlite, `prefix`):

```bash
cd /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0
source /home/hyoklee/src/hyrax-dependencies/hyrax-1.8.0/setup-giraffe-env.sh
```

libdap4's cmake (`cmake_minimum_required 3.20`) requires: CppUnit, LibXml2,
CURL, Threads, BISON, FLEX (TIRPC optional).

- LibXml2 (2.9.1), CURL (7.29), FLEX, libuuid: system packages — OK.
- BISON: from `$prefix/deps/bin` (built by hyrax-dependencies).
- **CppUnit: NOT present on CentOS 7** and `find_package(CppUnit REQUIRED)`,
  so build it into `$prefix/deps` first — see `build-cppunit.sh`.
- TIRPC: not installed, and not needed — CentOS 7 glibc provides Sun RPC
  (`/usr/include/rpc/xdr.h`), so xdr links from glibc (see patch #1).

## Patches (apply from the libdap4 source root)

```bash
cd /home/hyoklee/src/libdap4-3.22.0
patch -p1 < .../libdap4-3.22.0/xdr-datatypes-static.h.patch
patch -p1 < .../libdap4-3.22.0/CMakeLists.txt.patch
```

### 1. `xdr-datatypes-static.h.patch`

```
error: 'xdr_u_int16_t' was not declared in this scope   (xdr-datatypes.h)
error: 'xdr_u_int32_t' was not declared in this scope
```

The static header hardcodes the TIRPC spellings `xdr_u_int16_t` /
`xdr_u_int32_t`. CentOS 7 glibc spells them `xdr_uint16_t` / `xdr_uint32_t`
(confirmed present in `libc.so.6`). The patch selects the glibc spelling under
`__GLIBC__` (and non-WIN32), leaving the TIRPC/BSD path unchanged for other
platforms.

### 2. `CMakeLists.txt.patch`

The unit-test executables link `libcppunit.so` (built with gcc 5.4, needs
`GLIBCXX_3.4.21`) against the older system libstdc++ (4.8.5) →
`undefined reference to std::runtime_error::runtime_error@GLIBCXX_3.4.21`.
The tests are auxiliary and not part of the install, but their subdirectories
were added unconditionally. The patch wraps the four test `add_subdirectory`
calls and the `unit-test` / `integration-test` / `check` custom targets in
`if(BUILD_TESTING) ... endif()`, so `-DBUILD_TESTING=OFF` skips them cleanly.

## Configure, build, install

```bash
cd /home/hyoklee/src/libdap4-3.22.0
rm -rf build && mkdir build && cd build
export PKG_CONFIG_PATH=$prefix/deps/lib/pkgconfig:$prefix/deps/lib64/pkgconfig
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$prefix \
  -DCMAKE_PREFIX_PATH=$prefix/deps \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF
cmake --build . --parallel 8
cmake --install .
```

## Result (installed under `$prefix`)

```
lib/libdap.so  lib/libdapclient.so  lib/libdapserver.so
bin/dap-config  bin/getdap  bin/getdap4
include/libdap/*.h   (102 headers)
lib/cmake/libdap4/    (CMake package config)
```

`ldd bin/getdap4` and `ldd lib/libdap.so` resolve all shared libraries.
