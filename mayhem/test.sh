#!/usr/bin/env bash
#
# mayhem/test.sh — RUN ImageMagick6's own validation suite and a set of known-answer probes against the
# normal-flags tools that mayhem/build.sh built into mayhem/build/test. Nothing is compiled here.
#
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


B="$SRC/mayhem/build/test"
U="$B/utilities"
for tool in "$U/convert" "$U/identify" "$U/compare" "$B/tests/validate"; do
  [ -x "$tool" ] || { echo "missing $tool (build.sh should have built it)" >&2; emit_ctrf "imagemagick6" 0 1; exit 1; }
done
export MAGICK_CONFIGURE_PATH="$SRC/config"
export MAGICK_TMPDIR="${TMPDIR:-/tmp}"
cd "$SRC/tests"

passed=0; failed=0

# kat <name> <expected> <actual>: assert an exact known answer.
kat() {
  if [ "$2" = "$3" ]; then passed=$((passed + 1)); echo "ok   kat $1"
  else failed=$((failed + 1)); echo "FAIL kat $1: expected [$2] got [$3]" >&2; fi
}

ROSE=rose.pnm
SIG_ROSE=a698f2fe0c6c31f83d19554a6ec02bac79c961dd9a87e7ed217752e75eb615d7

kat identify-rose "PPM 70 46 8 $SIG_ROSE" "$("$U/identify" -format '%m %w %h %z %#' $ROSE 2>/dev/null)"
kat identify-miff-256c "70x46 253" "$("$U/identify" -format '%wx%h %k' input_256c.miff 2>/dev/null)"
kat identify-miff-bilevel "70x46 2" "$("$U/identify" -format '%wx%h %k' input_bilevel.miff 2>/dev/null)"
kat identify-miff-gray "70x46 205" "$("$U/identify" -format '%wx%h %k' input_gray.miff 2>/dev/null)"
kat identify-miff-truecolor "70x46 3019" "$("$U/identify" -format '%wx%h %k' input_truecolor.miff 2>/dev/null)"
kat identify-sequence-frames "5 77x80" "$("$U/identify" -format '%n %wx%h\n' sequence.miff 2>/dev/null | head -1)"
kat pixel-red "srgb(255,0,0)" "$("$U/convert" xc:red -format '%[pixel:p{0,0}]' info: 2>/dev/null)"
kat png-roundtrip "PNG $SIG_ROSE" "$("$U/convert" $ROSE png:- 2>/dev/null | "$U/identify" -format '%m %#' - 2>/dev/null)"
kat bmp-roundtrip "BMP $SIG_ROSE" "$("$U/convert" $ROSE bmp:- 2>/dev/null | "$U/identify" -format '%m %#' - 2>/dev/null)"
kat tiff-roundtrip "TIFF $SIG_ROSE" "$("$U/convert" $ROSE tiff:- 2>/dev/null | "$U/identify" -format '%m %#' - 2>/dev/null)"
kat negate-signature "df6c6acc54fb1953bb0df11c3004c2c03e778962ec0ff555543d956358dd5f36" "$("$U/convert" $ROSE -negate -format '%#' info: 2>/dev/null)"
kat resize-geometry "35x23" "$("$U/convert" $ROSE -resize 50% -format '%wx%h' info: 2>/dev/null)"
kat crop-signature "10x7 f14c17473999cd8e36bbec3e69797749b0bcd7b82f39a473262b3b67f6e52b01" "$("$U/convert" $ROSE -crop 10x7+3+2 +repage -format '%wx%h %#' info: 2>/dev/null)"
kat gray-mean "101 Gray" "$("$U/convert" $ROSE -colorspace Gray -format '%[fx:int(255*mean+0.5)] %[colorspace]' info: 2>/dev/null)"
kat rgb-stats "105 58" "$("$U/convert" $ROSE -format '%[fx:int(255*mean)] %[fx:int(255*standard_deviation)]' info: 2>/dev/null)"
kat compare-identical "0 (0)" "$("$U/compare" -metric AE $ROSE $ROSE null: 2>&1)"
"$U/convert" $ROSE -negate "${TMPDIR:-/tmp}/rose-negated.pnm" 2>/dev/null
kat compare-negated-rmse "35855.1 (0.547114)" "$("$U/compare" -metric RMSE $ROSE "${TMPDIR:-/tmp}/rose-negated.pnm" null: 2>&1)"
rm -f "${TMPDIR:-/tmp}/rose-negated.pnm"

# The project's own validation programs; their summary line is parsed, so a neutered binary (no output) fails.
for suite in identify compare composite convert colorspace montage stream formats-memory; do
  out="$("$B/tests/validate" -validate "$suite" 2>&1)"
  line="$(printf '%s\n' "$out" | grep -E '^validation suite: [0-9]+ tests; [0-9]+ passed; [0-9]+ failed\.' | tail -1)"
  if [ -z "$line" ]; then
    failed=$((failed + 1)); echo "FAIL validate $suite: no summary line" >&2; continue
  fi
  p="$(printf '%s' "$line" | sed -E 's/.*; ([0-9]+) passed; ([0-9]+) failed\./\1/')"
  f="$(printf '%s' "$line" | sed -E 's/.*; ([0-9]+) passed; ([0-9]+) failed\./\2/')"
  [ "$p" -gt 0 ] || { failed=$((failed + 1)); echo "FAIL validate $suite: 0 passed" >&2; continue; }
  passed=$((passed + p)); failed=$((failed + f))
  echo "validate $suite: $line"
  [ "$f" -eq 0 ] || printf '%s\n' "$out" | grep -iE 'fail' >&2
done

emit_ctrf "imagemagick6-validate+kat" "$passed" "$failed"
