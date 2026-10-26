#!/usr/bin/env bash
#
# mayhem/build.sh — build ImageMagick6's fuzz harnesses (sanitized, out-of-tree) and, separately, the
# project's normal-flags utilities + validation programs that mayhem/test.sh runs.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
BUILD="$SRC/mayhem/build"          # gitignored (mayhem/.gitignore)
mkdir -p "$BUILD/san" "$BUILD/test"

# Delegate libraries come from the image (apt); everything else is switched off so the build is
# self-contained and offline. Coders then run in-process: no external delegate programs, no X, no fonts.
CONFIGURE_OPTS=(--disable-shared --enable-static --disable-openmp --disable-opencl --disable-docs
  --disable-installed --without-modules --without-magick-plus-plus --without-perl --without-x
  --without-freetype --without-fontconfig --without-xml --without-djvu --without-rsvg --without-gvc
  --without-lqr --without-openexr --without-pango --without-wmf --without-fftw --without-gslib
  --without-dps --without-fpx --without-jbig --without-heic --without-raw --without-zstd
  --without-autotrace --without-webp --without-openjp2 --without-flif)

# 1) Sanitized + SanCov library for the fuzz targets. -fsanitize=fuzzer-no-link instruments the library
#    itself (the engine only instruments the harness TU). pointer-overflow is relaxed: the pixel-cache
#    code does NULL/bump-pointer arithmetic that halts every input otherwise.
FUZZ_CFLAGS="-O1 $SANITIZER_FLAGS -fno-sanitize=pointer-overflow $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
( cd "$BUILD/san"
  [ -f config.status ] || "$SRC/configure" CC="$CC" CFLAGS="$FUZZ_CFLAGS" LDFLAGS="$SANITIZER_FLAGS" "${CONFIGURE_OPTS[@]}" >configure.log 2>&1 \
    || { tail -40 configure.log; exit 1; }
  make -j"$MAYHEM_JOBS" magick/libMagickCore-6.Q16.la >make.log 2>&1 || { tail -40 make.log; exit 1; } )

LIBS_SAN="$BUILD/san/magick/.libs/libMagickCore-6.Q16.a"
SYSLIBS="-ljpeg -lpng16 -ltiff -llcms2 -lbz2 -llzma -lz -lm -lpthread"
INC="-I$BUILD/san -I$SRC -DMAGICKCORE_QUANTUM_DEPTH=16 -DMAGICKCORE_HDRI_ENABLE=0"

# 2) Harnesses: libFuzzer binary + standalone run-once reproducer each, with LSan switched off at build time.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.c" -o "$BUILD/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$BUILD/standalone_main.o"
for h in fuzz_decode fuzz_format fuzz_encode fuzz_ops; do
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $INC "$SRC/mayhem/$h.c" "$BUILD/lsan_off.o" \
      $LIBS_SAN $SYSLIBS -o "$SRC/$h"
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS $INC "$SRC/mayhem/$h.c" "$BUILD/standalone_main.o" "$BUILD/lsan_off.o" \
      $LIBS_SAN $SYSLIBS -o "$SRC/$h-standalone"
done

# 3) The project's own tools + validation programs, normal flags (no sanitizers, no -gdwarf-3), for test.sh.
TEST_CFLAGS="-O1 -g $COVERAGE_FLAGS"
( cd "$BUILD/test"
  [ -f config.status ] || env -u CFLAGS -u LDFLAGS "$SRC/configure" CC="$CC" CFLAGS="$TEST_CFLAGS" LDFLAGS="$COVERAGE_FLAGS" "${CONFIGURE_OPTS[@]}" >configure.log 2>&1 \
    || { tail -40 configure.log; exit 1; }
  make -j"$MAYHEM_JOBS" >make.log 2>&1 || { tail -40 make.log; exit 1; }
  make -j"$MAYHEM_JOBS" tests/validate tests/drawtest tests/wandtest >>make.log 2>&1 || { tail -40 make.log; exit 1; } )
