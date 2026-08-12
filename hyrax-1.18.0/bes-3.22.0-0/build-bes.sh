#!/bin/bash
# Build & install BES 3.22.0 on giraffe (CentOS 7.9) against installed libdap
# and the hyrax deps. Installs to $prefix. Run after the deps and libdap are
# installed (libdap MUST be built with gcc 5.4 / new ABI — see ../libdap4-3.22.0).
set -e

BES_SRC="${BES_SRC:-/home/hyoklee/src/bes-3.22.0-0}"

# Toolchain + prefix. devtoolset-8 is sourced for a modern toolchain, but PATH
# still resolves gcc/g++ to /home/tomcat/bin (gcc 5.4, new C++ ABI) via spath.sh
# — the same ABI as libdap and the deps.
source /opt/rh/devtoolset-8/enable 2>/dev/null || true
source /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0/spath.sh >/dev/null
: "${prefix:?spath.sh did not set prefix}"

export PKG_CONFIG_PATH="$prefix/deps/lib/pkgconfig:$prefix/deps/lib64/pkgconfig"

# OpenSSL >= 1.1 for http/awsv4.cc (EVP_MD_CTX_new/free). CentOS 7 system libcrypto
# is 1.0.2; use the /usr/local OpenSSL (soname libcrypto.so.4).
export CPPFLAGS="-I/usr/local/include $CPPFLAGS"
export LDFLAGS="-L/usr/local/lib64 -Wl,-rpath,/usr/local/lib64 $LDFLAGS"

# One-time: libbz2 dev symlink for hdf4-linked tools (CentOS 7 lacks -devel).
ln -sf /usr/lib64/libbz2.so.1.0.6 "$prefix/deps/lib/libbz2.so"
ln -sf /usr/lib64/libbz2.so.1.0.6 "$prefix/deps/lib64/libbz2.so" 2>/dev/null || true

cd "$BES_SRC"
test -x configure || autoreconf -fiv
./configure --prefix="$prefix" \
            --with-dependencies="$prefix/deps" \
            --with-gdal=no
make -j8
make install

echo "=== bes-config ==="
"$prefix/bin/bes-config" --version
