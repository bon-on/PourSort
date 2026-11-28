#!/usr/bin/env bash
# Builds the GamePix upload bundle: build/gamepix/ and
# build/pour-sort-gamepix.zip. The only third-party script is the GamePix SDK
# v3 (feature-gamepix-sdk): no other scripts, no external links, no other
# network access. See docs/gamepix.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/gamepix"
ZIP="$ROOT/build/pour-sort-gamepix.zip"

rm -rf "$OUT" "$ZIP"
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=GAMEPIX=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# GamePix serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"
# Drop the template's documentation comment (it contains an external URL).
perl -0pi -e 's#\s*<!--\s*If you are serving.*?-->##s' "$INDEX"
if grep -q -e 'games-nav-bar"' "$INDEX"; then echo "error: hub navigation bar still present in index.html" >&2; exit 1; fi
grep -q -e '--games-nav-height: 0px;' "$INDEX" || { echo "error: hub navigation height was not reset" >&2; exit 1; }

fail() { echo "error: $1" >&2; exit 1; }

# GamePix SDK with manual lifecycle, loaded in <head> before the Flutter
# bootstrap so localStorage sync is active from the game's first read.
SDK_URL="https://integration.gamepix.com/sdk/v3/gamepix.sdk.js"
SDK_TAG="<script src=\"$SDK_URL\"></script>"
CONFIG_TAG="<script>window.GamePixConfig = { lifecycle: 'manual' };</script>"
perl -pi -e "s#^(\\s*)</head>#\$1  $CONFIG_TAG\n\$1  $SDK_TAG\n\$1</head>#" "$INDEX"
if [ "$(grep -c -F "$SDK_TAG" "$INDEX")" != 1 ] || [ "$(grep -c -F "$CONFIG_TAG" "$INDEX")" != 1 ]; then
  fail "GamePix SDK script or manual lifecycle config missing or duplicated"
fi
config_line=$(grep -n -m1 -F "$CONFIG_TAG" "$INDEX" | cut -d: -f1 || true)
sdk_line=$(grep -n -m1 -F "$SDK_TAG" "$INDEX" | cut -d: -f1 || true)
boot_line=$(grep -n -m1 -F '<script src="flutter_bootstrap.js"' "$INDEX" | cut -d: -f1 || true)
if [[ -z "$config_line" || -z "$sdk_line" || -z "$boot_line" ]] \
  || ! { [ "$config_line" -lt "$sdk_line" ] && [ "$sdk_line" -lt "$boot_line" ]; }; then
  fail "GamePix config and SDK must precede the Flutter bootstrap"
fi
# Every other check sees the page without the SDK tag.
INDEX_NO_SDK="$(grep -v -F "$SDK_TAG" "$INDEX")"

# Glyphs Roboto lacks make Flutter fetch a fallback font from fonts.gstatic.com.
if find lib -name '*.dart' -print0 | xargs -0 perl -ne 'print "$ARGV:$.: $_" if /[^\x00-\x7F]/' | grep -q .; then
  fail "non-ASCII characters in lib/ may trigger external fallback font requests"
fi

grep -q '<base href="./">' "$INDEX" || fail "relative base href missing"
grep -q -e 'user-select: none' "$INDEX" || fail "user-select rule missing from index.html"
grep -q -e 'user-scalable=no' "$INDEX" || fail "viewport user-scalable=no missing"
grep -q -e 'touch-action: none' "$INDEX" || fail "touch-action rule missing"
if grep -q -i -e 'crazygames' -e 'bon-on.github.io' -e 'games-nav-bar"' <<<"$INDEX_NO_SDK"; then
  fail "portal SDK or hub navigation still present in index.html"
fi
# Only the local Flutter bootstrap may be loaded besides the GamePix SDK.
if grep -E '<script[^>]+src=' <<<"$INDEX_NO_SDK" | grep -v -F '<script src="flutter_bootstrap.js"' | grep -q .; then
  fail "index.html must not load scripts other than the GamePix SDK"
fi
if grep -Eq -e '(href|src|action)="(https?:)?//' <<<"$INDEX_NO_SDK"; then fail "external resource in index.html"; fi
grep -q '"family":"Roboto"' "$OUT/assets/FontManifest.json" || fail "Roboto missing from FontManifest.json"

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete

(cd "$OUT" && zip -qr "$ZIP" .)
zip_list=$(unzip -Z1 "$ZIP")
grep -qx 'index.html' <<<"$zip_list" || fail "index.html is not at the zip root"

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)
zip_kb=$(du -sk "$ZIP" | cut -f1)
cg_count=$({ grep -o -i 'crazygames' "$OUT/main.dart.js" || true; } | wc -l | tr -d ' ')
if [ "$cg_count" != 0 ]; then fail "CrazyGames strings found in the GamePix main.dart.js"; fi
echo "GamePix bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP (${zip_kb}KB)"
echo "crazygames strings in main.dart.js: $cg_count"
