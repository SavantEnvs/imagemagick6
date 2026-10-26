# GIF with an ICC/ICM profile: `memcpy` of a NULL source (UBSan)

- Reproducer: `crash` (a GIF; first input of `fuzz_decode`, found within 60 s from the starter seeds).
- Where: `magick/profile.c:1817` — `error: null pointer passed as argument 2, which is declared to never be null`.
- Impact: undefined behaviour (null passed to `memcpy` with a zero length); no memory corruption seen.
- Fix idea: guard the `memcpy` on a non-NULL, non-empty profile buffer.
- Replay: `/mayhem/fuzz_decode-standalone mayhem/fuzz_decode/known-findings/gif-icc-profile-memcpy-null/crash`
