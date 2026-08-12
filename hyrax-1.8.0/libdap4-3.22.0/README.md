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

## CRITICAL: C++ ABI must match the rest of the stack (gcc 5.4)

The hyrax deps (aws-sdk, cppunit) and downstream **BES** are built with
`g++` = gcc 5.4 from `/home/tomcat/bin`, whose default is the **new** libstdc++
string ABI (`_GLIBCXX_USE_CXX11_ABI=1`). If you let cmake auto-detect the
compiler it picks `c++` = **devtoolset-8**, whose default is the **old** ABI
(`_GLIBCXX_USE_CXX11_ABI=0`). That produces a libdap that exports
`std::string` (old `Ss`) symbols, and BES — compiled with the new `__cxx11`
ABI — fails to link with
`undefined reference to libdap::D4Attributes::find(std::__cxx11::...)`.

**Always force gcc 5.4 for libdap** so it matches the deps and BES:

```
-DCMAKE_C_COMPILER=/home/tomcat/bin/gcc
-DCMAKE_CXX_COMPILER=/home/tomcat/bin/g++
```

(Do NOT source devtoolset-8 for the libdap build, or if you do, still pass the
two compiler flags above.)

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

### 2. `CMakeLists.txt.patch` (two changes)

**a) Guard the tests with `BUILD_TESTING`.** The unit-test executables link
`libcppunit.so` (built with gcc 5.4, needs `GLIBCXX_3.4.21`) against the older
system libstdc++ (4.8.5) →
`undefined reference to std::runtime_error::runtime_error@GLIBCXX_3.4.21`.
The tests are auxiliary and not part of the install, but their subdirectories
were added unconditionally. The patch wraps the four test `add_subdirectory`
calls and the `unit-test` / `integration-test` / `check` custom targets in
`if(BUILD_TESTING) ... endif()`, so `-DBUILD_TESTING=OFF` skips them cleanly.

**b) Install the Test* factory headers.** libdap's cmake install omits the
`tests/*.h` headers (`TestTypeFactory.h`, `D4TestTypeFactory.h`, `TestByte.h`,
`TestCommon.h`, …). BES's `dapreader` module includes them from the installed
tree as `<test/TestTypeFactory.h>` and fails with
`fatal error: test/TestTypeFactory.h: No such file or directory`. The patch
adds an `install(FILES tests/*.h DESTINATION include/libdap/test)` rule, so the
installed tree has `include/libdap/test/*.h` (27 headers).

## Configure, build, install

```bash
cd /home/hyoklee/src/libdap4-3.22.0
rm -rf build && mkdir build && cd build
export PKG_CONFIG_PATH=$prefix/deps/lib/pkgconfig:$prefix/deps/lib64/pkgconfig
cmake .. \
  -DCMAKE_C_COMPILER=/home/tomcat/bin/gcc \
  -DCMAKE_CXX_COMPILER=/home/tomcat/bin/g++ \
  -DCMAKE_INSTALL_PREFIX=$prefix \
  -DCMAKE_PREFIX_PATH=$prefix/deps \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF
cmake --build . --parallel 8
cmake --install .
```

Confirm the ABI is correct (must be the `__cxx11` form, not `Ss`):

```bash
nm -D $prefix/lib/libdap.so | grep D4Attributes4find
# want: ..._ZN6libdap12D4Attributes4findERKNSt7__cxx11...   (new ABI)
```

## Result (installed under `$prefix`)

```
lib/libdap.so  lib/libdapclient.so  lib/libdapserver.so
bin/dap-config  bin/getdap  bin/getdap4
include/libdap/*.h        (102 headers)
include/libdap/test/*.h   (27 Test* factory headers, for BES dapreader)
lib/cmake/libdap4/        (CMake package config)
```

`ldd bin/getdap4` and `ldd lib/libdap.so` resolve all shared libraries.
