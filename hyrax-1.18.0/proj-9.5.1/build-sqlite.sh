#!/bin/bash
# Build SQLite3 >= 3.11 into $prefix/deps for proj-9.5.1 on CentOS 7.
# CentOS 7's system sqlite (3.7.17) is too old; the hyrax Makefile no longer
# builds sqlite. Run after `source spath.sh` (so $prefix is set).
set -e
: "${prefix:?source spath.sh first so prefix is set}"

cd "$(dirname "$0")/../.."   # repo root (…/hyrax-dependencies-hyrax-1.18.0)
SQLITE=sqlite-autoconf-3450300

cd downloads
test -f $SQLITE.tar.gz || curl -sSLO https://www.sqlite.org/2024/$SQLITE.tar.gz
cd ../src
rm -rf $SQLITE
tar xzf ../downloads/$SQLITE.tar.gz
cd $SQLITE
./configure --prefix="$prefix/deps" --with-pic
make -j4
make install
"$prefix/deps/bin/sqlite3" --version
