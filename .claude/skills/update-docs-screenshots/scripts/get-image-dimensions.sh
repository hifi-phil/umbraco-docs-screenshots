#!/usr/bin/env bash
# Print an image's pixel dimensions, cross-platform (Steps 6 and 8).
#
# Usage: get-image-dimensions.sh <path-to-image>
# Prints: "<width> <height>" on stdout.
#
# The docs use PNG for ~88% of images (verified by counting the real repo: 3862 of 4376 under
# 17+18/umbraco-cms), but a meaningful tail is JPG/JPEG (418), GIF (46), SVG (42), and WebP (8) —
# this is not PNG-only, so a single-format script would silently break on ~12% of real originals.
#
# PNG: read straight from the IHDR chunk (fixed byte offset — width at 16, height at 20, both
# big-endian uint32). A Node one-liner, since Node's already a hard dependency here; no external
# tool needed, and it's the cross-platform replacement for macOS-only `sips` (verified matches it
# exactly on a real file).
#
# JPEG/JPG/GIF/BMP/etc.: fall back to `file <path>`, which reports real pixel dimensions in its
# output on both macOS and Linux (verified against a real JPEG and a real GIF). IMPORTANT: for
# JPEG, `file`'s output can contain an earlier, unrelated "NxN"-shaped match from the DPI/Exif
# resolution segment (e.g. "72x72") BEFORE the real pixel dimensions later in the same line (e.g.
# "2876x1542") — verified this trap is real. Take the LAST WxH-shaped match on the line, never the
# first.
#
# NOT supported:
#   - SVG: vector, no fixed pixel size (viewBox/percentage units aren't comparable to a raster
#     original) — this skill only ever recaptures raster backoffice screenshots anyway.
#   - WebP: verified `file` on this system reports no dimensions for it at all ("RIFF (little-endian)
#     data, Web/P image" — nothing to parse). Rather than hand-write a RIFF/VP8 parser for ~0.2% of
#     images, this fails with a clear message; measure it manually if you ever hit this case.
#
# Exit codes: 0 success; 1 bad usage; 2 SVG (unsupported by design); 3 dimensions not determined.

set -u

IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "Usage: get-image-dimensions.sh <path-to-image>" >&2
  exit 1
fi

case "$IMG" in
  *.[Pp][Nn][Gg])
    node -e "
      const buf = require('fs').readFileSync(process.argv[1]);
      console.log(buf.readUInt32BE(16), buf.readUInt32BE(20));
    " "$IMG"
    ;;
  *.[Ss][Vv][Gg])
    echo "SVG has no fixed pixel size (viewBox/percentage units) — not supported. This skill only recaptures raster screenshots, so an SVG original shouldn't come up in practice." >&2
    exit 2
    ;;
  *)
    DIMS="$(file "$IMG" | grep -oE '[0-9]+ ?x ?[0-9]+' | tail -1 | tr -d ' ')"
    if [ -z "$DIMS" ]; then
      echo "Could not determine dimensions for $IMG — 'file' reported no size (a known gap for WebP on some systems; verified). Measure it manually." >&2
      exit 3
    fi
    echo "${DIMS%%x*} ${DIMS##*x}"
    ;;
esac
