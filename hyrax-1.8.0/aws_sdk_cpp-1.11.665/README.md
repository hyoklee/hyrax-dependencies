# aws_sdk_cpp-1.11.665 — build fix on giraffe (CentOS 7.9)

Apply `Makefile.patch` to the top-level `Makefile` of the hyrax-dependencies
tree (`hyrax-dependencies-hyrax-1.18.0/Makefile`):

```bash
cd /home/hyoklee/src/hyrax-dependencies-hyrax-1.18.0
patch -p1 < aws_sdk_cpp-1.11.665/Makefile.patch
```

## Failures and fixes

### 1. `git clone --shallow-submodules` unsupported

```
error: unknown option `shallow-submodules'
make: *** [src/aws_sdk_cpp-1.11.665-stamp] Error 129
```

giraffe's git is 1.8.3.1; `--shallow-submodules` needs git ≥2.9. The flag is
removed from the clone command. git 1.8.3 still handles
`--depth 1 --recurse-submodules` and clones the full nested submodule tree
(aws-crt-cpp, aws-lc, s2n, …) successfully — it just clones submodules at full
depth instead of shallow.

### 2. s2n fails to compile against `/usr/local` OpenSSL 4.0.0

```
s2n_certificate.c:230: error: dereferencing pointer to incomplete type
'ASN1_IA5STRING {aka struct asn1_string_st}'
```

The build auto-detected a bleeding-edge **OpenSSL 4.0.0** installed under
`/usr/local` (`/usr/local/lib64/libcrypto.so.4`). s2n (commit a786223) cannot
parse that version's numbering and falls back to a pre-1.1 code path that
dereferences now-opaque ASN1 structs → compile error.

Fix: add `-DUSE_OPENSSL=OFF` so aws-crt-cpp builds and uses its **bundled
aws-lc** (a self-consistent BoringSSL fork) instead of the system OpenSSL.
After this, `S2N_LIBCRYPTO_SUPPORTS_*` detect correctly and s2n compiles.

### 3. `s3-gen-tests` fails to compile with gcc 5.4

```
S3EndpointProviderTests.cpp:76: error: no matching function for call to
'Aws::UniquePtrSafeDeleted<...>::UniquePtrSafeDeleted()'
```

Only the generated **test** target fails (the s3/core libraries build fine);
gcc 5.4 chokes on a C++ template default-construction in the tests. Add
`-DENABLE_TESTING=OFF` so tests are not built. (`-DAUTORUN_UNIT_TESTS=OFF`
only skips running them, not building them.)

## Build

```bash
source /opt/rh/devtoolset-8/enable
source spath.sh
make aws_cdk
```

Installs `libaws-cpp-sdk-core.so` and `libaws-cpp-sdk-s3.so` into
`$prefix/deps/lib64`.

## Note

If `src/aws_sdk_cpp-1.11.665` already exists, the Makefile's stamp rule reuses
it ("Using existing AWS SDK git clone") and skips cloning.
