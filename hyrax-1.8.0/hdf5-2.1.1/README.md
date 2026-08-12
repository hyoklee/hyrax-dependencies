# hdf5-2.1.1 — build fix on giraffe (CentOS 7.9)

## Failure

```
CMake Error: The source directory ".../src/hdf5-2.1.1/build" does not exist.
```

The hdf5 rule invokes `cmake -S . -B build ...`. The `-S`/`-B` out-of-source
flags were added in cmake 3.13; giraffe's cmake 2.8.12.2 does not understand
them, so it treats `build` as a (non-existent) source dir.

## Cause

cmake too old (2.8.12.2). hdf5 2.1.1's rule needs cmake ≥3.13.

## Fix

No source/Makefile change. Use cmake 3.26 on PATH (see top-level README and the
`openjpeg-2.5.3` dir for the symlink recipe), then:

```bash
source /opt/rh/devtoolset-8/enable   # modern compiler
source spath.sh
make hdf5
```

zlib-1.3.1 is fetched by hdf5's own cmake (`HDF5_ALLOW_EXTERNAL_SUPPORT=TGZ`,
`ZLIB_USE_LOCALCONTENT=OFF`) over the network. Installs `libhdf5.so`,
`libhdf5_hl.so` into `$prefix/deps/lib`.
