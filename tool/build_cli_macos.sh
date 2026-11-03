#!/bin/sh
set -e
ROOT="$SRCROOT/.."
OUT="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/MacOS/warpgate-cli"
DART="$FLUTTER_ROOT/bin/dart"
cd "$ROOT/packages/warpgate_cli"
"$DART" pub get
"$DART" compile exe bin/warpgate.dart -o "$OUT"
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
  codesign -f -s - "$OUT"
  exit 0
fi
ENTITLEMENTS="$SRCROOT/Runner/WarpgateCli.entitlements"
if [ -n "$WARPGATE_KEYCHAIN_GROUP" ] && [ -f "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/embedded.provisionprofile" ]; then
  ENTITLEMENTS="$DERIVED_FILE_DIR/WarpgateCli.xcent"
  sed "s/\$(AppIdentifierPrefix)/$DEVELOPMENT_TEAM./" "$SRCROOT/Runner/WarpgateCli.Signed.entitlements" > "$ENTITLEMENTS"
fi
TIMESTAMP="--timestamp=none"
if [ "$CONFIGURATION" = "Release" ]; then
  TIMESTAMP="--timestamp"
fi
codesign -f -s "$IDENTITY" --options runtime "$TIMESTAMP" --entitlements "$ENTITLEMENTS" "$OUT"
