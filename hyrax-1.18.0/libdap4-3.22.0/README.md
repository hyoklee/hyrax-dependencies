# libdap4-3.22.0 — build & install on giraffe (CentOS 7.9)

Builds libdap4 3.22.0 with cmake against the hyrax dependencies and installs
to the hyrax prefix (`$prefix` = `/home/hyoklee/pkg/hyrax-1.18.0`), same tree the
deps use (deps live under `$prefix/deps`).

## Prerequisites

Source the giraffe toolchain env first (cmake 3.26, gcc, sqlite, `prefix`):

```bash
cd /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0
source /home/hyoklee/src/hyrax-dependencies/hyrax-1.18.0/setup-giraffe-env.sh
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
patch -p1 < .../libdap4-3.22.0/tests_CMakeLists.txt.patch
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

### 2. `CMakeLists.txt.patch` (three changes)

**a) Guard the unit tests with `BUILD_TESTING`.** The unit-test executables link
`libcppunit.so` (built with gcc 5.4, needs `GLIBCXX_3.4.21`) against the older
system libstdc++ (4.8.5) →
`undefined reference to std::runtime_error::runtime_error@GLIBCXX_3.4.21`.
Those subdirectories were added unconditionally. The patch wraps the
`unit-tests` / `d4_ce/unit-tests` / `http_dap/unit-tests` `add_subdirectory`
calls and the `unit-test` / `integration-test` / `check` custom targets in
`if(BUILD_TESTING) ... endif()`, so `-DBUILD_TESTING=OFF` skips them cleanly.

**b) Install the Test* factory headers.** libdap's cmake install omits the
`tests/*.h` headers (`TestTypeFactory.h`, `D4TestTypeFactory.h`, `TestByte.h`,
`TestCommon.h`, …). BES's `dapreader` module includes them from the installed
tree as `<test/TestTypeFactory.h>` and fails with
`fatal error: test/TestTypeFactory.h: No such file or directory`. The patch
adds an `install(FILES tests/*.h DESTINATION include/libdap/test)` rule, so the
installed tree has `include/libdap/test/*.h` (27 headers).

**c) Build/install `test-types` even with `BUILD_TESTING=OFF`.**
`add_subdirectory(tests)` is moved OUT of the `BUILD_TESTING` guard (only the
unit-tests dirs stay guarded). `tests/` builds the **`test-types`** static
library (the `Test*`/`D4Test*` factory classes) and installs it to `lib`. BES's
`dapreader` module links `-ltest-types`; without it, the linker silently falls
back to a **stale, ABI-incompatible copy elsewhere on the box** (e.g.
`/home/tomcat/lib/libtest-types.a` from an old libdap 3.21), producing
`undefined symbol: ...D4Group...transform_to_dap2...` /
`...BaseTypeFactory...NewSequence...` at BES module load.

### 3. `tests_CMakeLists.txt.patch`

Complements 2(c): inside `tests/CMakeLists.txt`, wraps only the test
**executables** (`das-test`, `dds-test`, `expr-test`, `dmr-test`) and the
autotest driver generation / `add_test` calls in `if(BUILD_TESTING) ... endif()`.
The `test-types` library and its `install(TARGETS test-types …)` rule stay
unconditional, so `-DBUILD_TESTING=OFF` installs `lib/libtest-types.a` without
building the executables that don't link on CentOS 7.

> Must be built with the same compiler/ABI as libdap and BES — i.e. gcc 5.4
> (`/home/tomcat/bin/g++`, new `__cxx11` ABI). devtoolset-8's g++ defaults to
> the OLD ABI and yields `undefined symbol: ...NewSequence...RKSs`.

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
lib/libtest-types.a       (Test* factory lib, required by BES dapreader)
bin/dap-config  bin/getdap  bin/getdap4
include/libdap/*.h        (102 headers)
include/libdap/test/*.h   (27 Test* factory headers, for BES dapreader)
lib/cmake/libdap4/        (CMake package config)
```

`ldd bin/getdap4` and `ldd lib/libdap.so` resolve all shared libraries.
