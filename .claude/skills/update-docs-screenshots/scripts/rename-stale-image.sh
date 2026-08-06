#!/usr/bin/env bash
# Compute a cleaned-up filename for an image whose current name carries a stale version marker
# (Step 9). Pure string transform — doesn't touch the filesystem or git.
#
# Usage: rename-stale-image.sh <basename.png>
#
# Strips a trailing old-version marker (v1-v13, as a `-v9`/`_v9`/`v9` suffix immediately before the
# extension — the pattern found in ~90% of old-marked filenames when this was surveyed, e.g.
# cropping-images-v9.png, Content-Picker2-DataType-v10.png, allow-variance_v10.png). The version
# folder (17/, 18/) already disambiguates, so a leftover "-v9" on a freshly-captured current-UI
# screenshot is just misleading, not meaningful.
#
# Known limitation: a version marker as a PREFIX (v9-media-types-upload-media.png,
# v8-miniprofiler-write.png — a real but less common pattern, ~10% of samples) is NOT recognized —
# prints the name unchanged rather than guessing wrong on a less-confident pattern. Renaming those
# is a manual call.
#
# Prints the (possibly unchanged) new basename on stdout. Never fails.

set -u

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "Usage: rename-stale-image.sh <basename.png>" >&2
  exit 1
fi

echo "$NAME" | sed -E 's/[-_]?[vV](1[0-3]|[1-9])(\.[^.]+)$/\2/'
