# FITS image re-encoded: `-inf` converted to `unsigned long` in the quantizer (UBSan)

- Reproducer: `crash` (first byte selects the writer, the rest is a FITS file; found by `fuzz_encode` within 60 s from the starter seeds).
- Where: `magick/quantize.c:1932` — `runtime error: -inf is outside the range of representable values of type 'unsigned long'`.
- Impact: undefined float-to-integer conversion on a non-finite value coming from the image data.
- Fix idea: clamp/reject non-finite values before the cast.
- Replay: `/mayhem/fuzz_encode-standalone mayhem/fuzz_encode/known-findings/fits-quantize-inf-to-unsigned/crash`
