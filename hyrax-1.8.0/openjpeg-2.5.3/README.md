# openjpeg-2.5.3 — build fix on giraffe (CentOS 7.9)

## Failure

```
CMake Error at CMakeLists.txt:10 (cmake_minimum_required):
  CMake 3.5 or higher is required.  You are running version 2.8.12.2
```

## Cause

giraffe's default `/usr/bin/cmake` is 2.8.12.2; openjpeg 2.5.3 requires ≥3.5.

## Fix

No source/Makefile change. Put cmake 3.26 ahead of the system cmake on PATH.
cmake 3.26 is already staged at
`/home/hyoklee/bin/cmake-3.26.0-linux-x86_64/`. It is made to resolve early
by symlinking into the build's `$prefix/deps/bin` (which `spath.sh` puts on
PATH before `/usr/bin`):

```bash
ln -sf /home/hyoklee/bin/cmake-3.26.0-linux-x86_64/bin/{cmake,ctest,cpack,ccmake,cmake-gui} \
       /home/hyoklee/pkg/hyrax-1.8.0/deps/bin/
```

Then:

```bash
source spath.sh
make openjpeg
```

Installs `libopenjp2.so` into `$prefix/deps/lib64`.
