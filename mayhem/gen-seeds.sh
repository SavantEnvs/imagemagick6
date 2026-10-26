#!/usr/bin/env bash
# Regenerates the committed starter seeds (mayhem/<target>/testsuite/) from the project's own `convert`
# (built by build.sh into mayhem/build/test). Seeds are format-valid tiny images; for the selector-byte
# targets the first byte(s) are derived from the line number in the *_formats.h tables.
# Usage (inside the commit image, from /mayhem):  bash mayhem/gen-seeds.sh
set -euo pipefail
cd "${SRC:-/mayhem}"
CONVERT=mayhem/build/test/utilities/convert
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
$CONVERT rose: -resize 24x16! -depth 8 "$T/base.miff"

mkfile() { # <format> <out>   (best effort: not every writer accepts every image)
  rm -f "$2"; $CONVERT "$T/base.miff" "$1:$2" 2>/dev/null && [ -s "$2" ]
}
sel() { printf "\\x$(printf %02x "$1")"; }
idx() { # <header> <name> -> 0-based table index
  grep -n "^  \"$2\"," "mayhem/$1" | head -1 | cut -d: -f1 | awk '{print $1-2-1}'
}

D=mayhem/fuzz_decode/testsuite; F=mayhem/fuzz_format/testsuite; E=mayhem/fuzz_encode/testsuite; O=mayhem/fuzz_ops/testsuite
rm -rf "$D" "$F" "$E" "$O"; mkdir -p "$D" "$F" "$E" "$O"

sniff=()
for fmt in $(grep -o '^  "[A-Za-z0-9]*"' mayhem/decode_formats.h | tr -d ' "'); do
  mkfile "$fmt" "$T/f.$fmt" || continue
  [ "$(wc -c < "$T/f.$fmt")" -lt 20000 ] || continue   # PCD/HRZ have fixed large geometry
  n=$(idx decode_formats.h "$fmt")
  { sel "$n"; cat "$T/f.$fmt"; } > "$F/$fmt"
  if [ "$(wc -c < "$T/f.$fmt")" -lt 6000 ] && $CONVERT "$T/f.$fmt" /dev/null 2>/dev/null; then
    cp "$T/f.$fmt" "$D/$fmt"; sniff+=("$T/f.$fmt")
  fi
done
[ "${#sniff[@]}" -gt 0 ]

i=0
for fmt in $(grep -o '^  "[A-Za-z0-9]*"' mayhem/encode_formats.h | tr -d ' "'); do
  src=${sniff[$((i % ${#sniff[@]}))]}; i=$((i+1))
  { sel "$(idx encode_formats.h "$fmt")"; cat "$src"; } > "$E/$fmt"
done

for op in $(seq 0 39); do
  src=${sniff[$(( (op * 7) % ${#sniff[@]} ))]}
  { sel "$op"; sel $(( (op * 37 + 11) % 256 )); cat "$src"; } > "$O/op$op"
done
echo "seeds: decode=$(ls $D | wc -l) format=$(ls $F | wc -l) encode=$(ls $E | wc -l) ops=$(ls $O | wc -l)"
