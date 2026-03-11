#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/.build/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Debug"
EXTRACTOR="$PRODUCTS_DIR/PokeExtractCLI"
APP_BUNDLE="$PRODUCTS_DIR/PokeMac.app"
CONTENT_ROOT="$ROOT/Content"
CONTENT_VARIANT_ROOT="$CONTENT_ROOT/Red"
CONTENT_MANIFEST="$CONTENT_VARIANT_ROOT/game_manifest.json"
TRACE_ROOT="${POKESWIFT_TRACE_DIR:-$HOME/Library/Caches/PokeSwift/Traces/pokemac}"
SAVE_ROOT="${POKESWIFT_SAVE_ROOT:-$HOME/Library/Application Support/PokeSwift/Saves}"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/PokeMac"

timestamp() {
  date '+%H:%M:%S'
}

section() {
  printf '\n[%s] %s\n' "$(timestamp)" "$1"
}

detail() {
  printf '  - %s\n' "$1"
}

require_executable() {
  local path="$1"
  local label="$2"
  if [[ ! -x "$path" ]]; then
    printf '[%s] Missing %s at %s\n' "$(timestamp)" "$label" "$path" >&2
    exit 1
  fi
}

manifest_source_commit() {
  sed -n 's/.*"sourceCommit" : "\(.*\)",/\1/p' "$CONTENT_MANIFEST" | head -n 1
}

should_refresh_content() {
  if [[ ! -f "$CONTENT_MANIFEST" ]]; then
    return 0
  fi

  local source_commit
  source_commit="$(manifest_source_commit)"
  if [[ -z "$source_commit" ]]; then
    return 0
  fi

  if ! git rev-parse -q --verify "${source_commit}^{commit}" >/dev/null 2>&1; then
    return 0
  fi

  local -a source_paths
  source_paths=("${(@f)$(sed -n 's/.*"path" : "\(.*\)",/\1/p' "$CONTENT_MANIFEST")}")
  if (( ${#source_paths[@]} == 0 )); then
    return 0
  fi

  if ! git diff --quiet "${source_commit}..HEAD" -- "${source_paths[@]}"; then
    return 0
  fi

  if ! git diff --quiet -- "${source_paths[@]}"; then
    return 0
  fi

  if ! git diff --cached --quiet -- "${source_paths[@]}"; then
    return 0
  fi

  return 1
}

trap 'printf "\n[%s] Launch pipeline failed.\n" "$(timestamp)" >&2' ERR

cd "$ROOT"

section "PokeSwift launch pipeline"
detail "Repo root: $ROOT"
detail "Derived data: $DERIVED_DATA"
detail "App bundle: $APP_BUNDLE"
detail "App executable: $APP_EXECUTABLE"
detail "Content root: $CONTENT_VARIANT_ROOT"
detail "Trace root: $TRACE_ROOT"
detail "Save root: $SAVE_ROOT"

section "1/4 Generate workspace and build debug targets"
detail "Building schemes: PokeExtractCLI, PokeMac"
./scripts/build_app.sh

require_executable "$EXTRACTOR" "PokeExtractCLI"
if [[ ! -d "$APP_BUNDLE" ]]; then
  printf '[%s] Missing PokeMac.app at %s\n' "$(timestamp)" "$APP_BUNDLE" >&2
  exit 1
fi
require_executable "$APP_EXECUTABLE" "PokeMac executable"

section "2/4 Extract Red content"
if should_refresh_content; then
  detail "Refreshing extracted runtime assets under $CONTENT_VARIANT_ROOT"
  "$EXTRACTOR" extract --game red --repo-root "$ROOT" --output-root "$CONTENT_ROOT"
else
  detail "Skipping extract; tracked content source inputs are unchanged"
fi

section "3/4 Verify extracted Red content"
detail "Checking extracted manifests and asset availability"
"$EXTRACTOR" verify --game red --repo-root "$ROOT" --output-root "$CONTENT_ROOT"

section "4/4 Launch macOS app"
detail "Launching PokeMac executable with explicit runtime roots"
(
  cd "$ROOT"
  POKESWIFT_CONTENT_ROOT="$CONTENT_ROOT" \
  POKESWIFT_TRACE_DIR="$TRACE_ROOT" \
  POKESWIFT_SAVE_ROOT="$SAVE_ROOT" \
  "$APP_EXECUTABLE" >/dev/null 2>&1 &
) >/dev/null 2>&1

section "Launch request sent"
detail "App bundle: $APP_BUNDLE"
