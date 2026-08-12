#!/bin/bash
# Build CppUnit 1.15.1 into $prefix/deps for libdap4 on CentOS 7.
# libdap4's cmake does `find_package(CppUnit REQUIRED)` and CentOS 7 has no
# cppunit package. Run after `source setup-giraffe-env.sh` (so $prefix is set).
set -e
: "${prefix:?source setup-giraffe-env.sh (or spath.sh) first so prefix is set}"

DEPS_TREE="${DEPS_TREE:-/home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0}"
CPPUNIT=cppunit-1.15.1

cd "$DEPS_TREE/downloads"
test -f "$CPPUNIT.tar.gz" || curl -sSLO "https://dev-www.libreoffice.org/src/$CPPUNIT.tar.gz"
cd "$DEPS_TREE/src"
rm -rf "$CPPUNIT"
tar xzf "../downloads/$CPPUNIT.tar.gz"
cd "$CPPUNIT"
./configure --prefix="$prefix/deps" --with-pic --disable-doxygen
make -j4
make install
PKG_CONFIG_PATH="$prefix/deps/lib/pkgconfig" pkg-config --modversion cppunit
