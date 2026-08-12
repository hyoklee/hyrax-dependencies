# proj-9.5.1 — build fix on giraffe (CentOS 7.9)

## Failures (in order encountered)

1. `CMake 3.16 or higher is required. You are running version 2.8.12.2`
2. `SQLite3 >= 3.11 required!` (CentOS 7 system sqlite is 3.7.17)
3. proj 9.5.1 needs a C++17 compiler (giraffe default gcc is 4.8.5)

## Cause

- cmake too old (2.8.12.2) — proj needs ≥3.16.
- sqlite too old — proj 9.5.1 needs SQLite3 ≥3.11. The hyrax Makefile
  deliberately stopped building sqlite ("Removed sqlite3 since it's part of
  OSX and Linux. jhrg 10/20/25"), which is true on Rocky/macOS but **not** on
  CentOS 7 where the system sqlite is 3.7.17.
- gcc 4.8.5 does not support C++17.

## Fix

No proj source/Makefile change. Supply the three missing tools:

### 1. cmake 3.26 on PATH (see top-level README / openjpeg dir).

### 2. Build SQLite3 ≥3.11 into `$prefix/deps` (see `build-sqlite.sh`):

```bash
cd downloads
curl -sSLO https://www.sqlite.org/2024/sqlite-autoconf-3450300.tar.gz
cd ../src && tar xzf ../downloads/sqlite-autoconf-3450300.tar.gz
cd sqlite-autoconf-3450300
./configure --prefix=$prefix/deps --with-pic
make -j4 && make install
```

proj's cmake finds it via `-DCMAKE_PREFIX_PATH=$prefix/deps` (already in the
proj rule). Verify: `sqlite3 --version` → 3.45.3.

### 3. Modern C++ compiler:

```bash
source /opt/rh/devtoolset-8/enable   # or gcc 5.4 from /home/tomcat/bin
```

Then:

```bash
source spath.sh
make proj
```

Installs `libproj.so.25` into `$prefix/deps/proj/lib64`. GTest is fetched by
proj's cmake over the network (tests are configured but not required to run).
