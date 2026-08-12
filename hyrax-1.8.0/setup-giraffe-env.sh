#!/bin/bash
#
# setup-giraffe-env.sh — one-shot toolchain bootstrap for building
# hyrax-dependencies (hyrax-1.18.0 tree) on giraffe (CentOS 7.9).
#
# CentOS 7's default cmake (2.8), git (1.8), gcc (4.8) and sqlite (3.7) are too
# old for openjpeg/proj/hdf5/aws-sdk-cpp. This script provisions modern tools
# and sets up the build environment. It is idempotent — safe to re-run.
#
# USAGE (must be sourced so it can modify your shell env):
#
#     cd /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0
#     source /home/hyoklee/src/hyrax-dependencies/hyrax-1.8.0/setup-giraffe-env.sh
#     make            # or: make hdf5 / make proj / make aws_cdk ...
#
# Override defaults via env vars before sourcing if paths differ:
#     BUILD_DIR   (default: /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0)
#     CMAKE_HOME  (default: /home/hyoklee/bin/cmake-3.26.0-linux-x86_64)
#     SQLITE_VER  (default: sqlite-autoconf-3450300)

# --- guard: must be sourced, not executed ----------------------------------
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "ERROR: source this script, don't execute it:" >&2
    echo "  source ${0}" >&2
    exit 1
fi

: "${BUILD_DIR:=/home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0}"
: "${CMAKE_HOME:=/home/hyoklee/bin/cmake-3.26.0-linux-x86_64}"
: "${SQLITE_VER:=sqlite-autoconf-3450300}"
: "${SQLITE_URL:=https://www.sqlite.org/2024/${SQLITE_VER}.tar.gz}"

_fail() { echo "setup-giraffe-env: $*" >&2; return 1; }

# --- 0. sanity -------------------------------------------------------------
if [ ! -f "$BUILD_DIR/Makefile" ] || [ ! -f "$BUILD_DIR/spath.sh" ]; then
    _fail "BUILD_DIR ($BUILD_DIR) is not a hyrax-dependencies tree" || return 1
fi

# --- 1. modern C++ compiler (gcc 8.3 via devtoolset-8) ---------------------
if [ -f /opt/rh/devtoolset-8/enable ]; then
    source /opt/rh/devtoolset-8/enable
    echo "setup-giraffe-env: devtoolset-8 enabled ($(gcc -dumpversion))"
else
    echo "setup-giraffe-env: WARNING devtoolset-8 not found; using $(gcc -dumpversion)"
fi

# --- 2. hyrax prefix / PATH / LD_LIBRARY_PATH (from the tree's spath.sh) ----
#     Sets and exports 'prefix'; prepends $prefix/bin:$prefix/deps/bin to PATH.
source "$BUILD_DIR/spath.sh" >/dev/null
echo "setup-giraffe-env: prefix=$prefix"

# --- 3. modern cmake 3.26 (openjpeg>=3.5, hdf5>=3.13 -S/-B, proj>=3.16) -----
if [ ! -x "$CMAKE_HOME/bin/cmake" ]; then
    _fail "cmake not found at $CMAKE_HOME/bin/cmake" || return 1
fi
# Symlink into $prefix/deps/bin (already early on PATH via spath.sh) so every
# cmake/ctest/cpack invocation in the Makefile resolves to 3.26, not /usr/bin.
mkdir -p "$prefix/deps/bin"
for t in cmake ctest cpack ccmake cmake-gui; do
    ln -sf "$CMAKE_HOME/bin/$t" "$prefix/deps/bin/$t"
done
# Also front-load it on PATH for this shell.
case ":$PATH:" in *":$CMAKE_HOME/bin:"*) ;; *) export PATH="$CMAKE_HOME/bin:$PATH";; esac
echo "setup-giraffe-env: cmake -> $(command -v cmake) ($(cmake --version | head -1 | awk '{print $3}'))"

# --- 4. SQLite3 >= 3.11 for proj-9.5.1 (CentOS 7 system sqlite is 3.7.17) ---
if [ -x "$prefix/deps/bin/sqlite3" ] && \
   "$prefix/deps/bin/sqlite3" --version | grep -qvE '^3\.([0-9]|10)\.'; then
    echo "setup-giraffe-env: sqlite -> $("$prefix/deps/bin/sqlite3" --version | awk '{print $1}') (already installed)"
else
    echo "setup-giraffe-env: building $SQLITE_VER into $prefix/deps ..."
    ( set -e
      cd "$BUILD_DIR/downloads"
      test -f "$SQLITE_VER.tar.gz" || curl -sSLO "$SQLITE_URL"
      cd "$BUILD_DIR/src"
      rm -rf "$SQLITE_VER"
      tar xzf "../downloads/$SQLITE_VER.tar.gz"
      cd "$SQLITE_VER"
      ./configure --prefix="$prefix/deps" --with-pic >/tmp/sqlite_cfg.log 2>&1
      make -j4 >/tmp/sqlite_make.log 2>&1
      make install >/tmp/sqlite_inst.log 2>&1
    ) && echo "setup-giraffe-env: sqlite -> $("$prefix/deps/bin/sqlite3" --version | awk '{print $1}') (built)" \
      || { _fail "sqlite build failed; see /tmp/sqlite_*.log"; return 1; }
fi

echo "setup-giraffe-env: ready. Now run 'make' (or 'make <pkg>') in $BUILD_DIR."
echo "                   NOTE: gdal is skipped in this configuration."
