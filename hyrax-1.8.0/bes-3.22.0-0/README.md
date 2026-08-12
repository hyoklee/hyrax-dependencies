# bes-3.22.0-0 — build & install on giraffe (CentOS 7.9)

Builds BES 3.22.0 with **autotools** against the installed libdap (found via
`dap-config`) and the hyrax deps, installing to the same prefix
(`$prefix` = `/home/hyoklee/pkg/hyrax-1.8.0`).

No BES source files are patched — all fixes are configure flags plus two
environment provisions (a libbz2 dev symlink and a newer OpenSSL). The
important correctness dependency is that **libdap was built with the same
compiler/ABI (gcc 5.4)** — see `../libdap4-3.22.0`.

## Prerequisites

1. hyrax deps built and installed (`../README.md`, `setup-giraffe-env.sh`).
2. **libdap 3.22.0 installed with gcc 5.4 (new C++ ABI)** — see
   `../libdap4-3.22.0`. A devtoolset-8-built libdap (old ABI) will fail BES
   linking with `undefined reference to libdap::...(std::__cxx11::...)`.
3. `dap-config` on PATH (it is: `$prefix/bin`, via `spath.sh`).

### libbz2 dev symlink (one-time)

hdf4-linked tools (`build_dmrpp_h4`) link `-lbz2`, but CentOS 7 ships only
`libbz2.so.1` (no `-devel` symlink). Create it in the deps lib dir (on the
link path via `--with-dependencies`):

```bash
ln -sf /usr/lib64/libbz2.so.1.0.6 $prefix/deps/lib/libbz2.so
ln -sf /usr/lib64/libbz2.so.1.0.6 $prefix/deps/lib64/libbz2.so
```

## Build & install

See `build-bes.sh`. In short:

```bash
source /opt/rh/devtoolset-8/enable          # PATH still prefers gcc 5.4 (/home/tomcat/bin)
source /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0/spath.sh
export PKG_CONFIG_PATH=$prefix/deps/lib/pkgconfig:$prefix/deps/lib64/pkgconfig

# OpenSSL >= 1.1 for http/awsv4.cc (EVP_MD_CTX_new/free); CentOS 7 system is
# 1.0.2. Use the /usr/local OpenSSL (soname libcrypto.so.4, coexists with the
# system 1.0.2 that libcurl uses).
export CPPFLAGS="-I/usr/local/include $CPPFLAGS"
export LDFLAGS="-L/usr/local/lib64 -Wl,-rpath,/usr/local/lib64 $LDFLAGS"

cd /home/hyoklee/src/bes-3.22.0-0
autoreconf -fiv                              # no configure ships in the tarball
./configure --prefix=$prefix \
            --with-dependencies=$prefix/deps \
            --with-gdal=no                   # gdal was skipped in the deps build
make -j8
make install
```

## Configure notes

- `--with-gdal=no`: GDAL-dependent modules (gdal_handler, fileout_gdal) are
  skipped because gdal was intentionally not built in the deps. Configure also
  auto-skips them when `$prefix/deps/bin/gdal-config` is absent.
- fits handler (needs cfitsio) and NCML handler (needs ICU) auto-skip — those
  libs aren't present; they are optional.
- Optional features that DO build: s3_reader, stare, gridfields, hdf5,
  hdfeos2, hdf4, netcdf, AWS C++ SDK.

## Result (installed under `$prefix`)

```
bin/  besdaemon beslistener bescmdln besstandalone besctl bes-config
      build_dmrpp build_dmrpp_h4 get_dmrpp_h4 get_dmrpp_h5 merge_dmrpp ...
lib/  libbes_dispatch.so libbes_ppt.so libbes_xml_command.so
lib/bes/  22 module .so's (dap, dmrpp, nc, h4, h5, ascii, csv, s3, ...)
```

Verify:

```bash
export LD_LIBRARY_PATH=$prefix/lib:$prefix/deps/lib:$prefix/deps/lib64:/usr/local/lib64
bes-config --version          # -> bes 3.22.0
besstandalone --version       # runs
beslistener                   # prints usage (loads cleanly)
ldd $prefix/bin/beslistener | grep 'not found'   # (none)
```
