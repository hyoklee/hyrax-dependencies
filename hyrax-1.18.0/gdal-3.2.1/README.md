# gdal-3.2.1 — SKIPPED on giraffe

Per instruction, gdal was **not** built in this pass.

For the record, the observed failure was:

```
GNUmakefile:1: GDALmake.opt: No such file or directory
./config.status: Command not found
make[2]: *** [config.status] Error 127
```

i.e. gdal's autotools `configure` had never completed (no `GDALmake.opt`,
no `config.status`). gdal 3.2.1 uses autotools (not cmake) and depends on a
successfully installed **proj** plus a C++ compiler; it should be revisited
after proj is in place (proj now builds — see `../proj-9.5.1`).

No patch is provided here.
