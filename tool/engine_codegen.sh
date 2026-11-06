#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/rust"
flutter_rust_bridge_codegen generate
cd "$ROOT/tool/no_comments"
dart pub get >/dev/null
dart run bin/no_comments.dart "$ROOT/rust/src/frb_generated.rs" "$ROOT/packages/warpgate_core/lib/src/engine"
cd "$ROOT/rust" && cargo fmt
dart format "$ROOT/packages/warpgate_core/lib/src/engine" >/dev/null
