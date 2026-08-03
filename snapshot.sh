#!/usr/bin/env bash
# Regenerate manifest/projects.tsv from what is actually on disk.
#
# This is the drift guard: run it before committing the toolkit so a project
# you created by hand cannot silently fail to restore on the next machine.
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(dirname "$TOOLKIT_DIR")}"
source "$TOOLKIT_DIR/lib/util.sh"
source "$TOOLKIT_DIR/manifest/engine.conf"
[[ -f "$TOOLKIT_DIR/machine.local.sh" ]] && source "$TOOLKIT_DIR/machine.local.sh"

OUT="$TOOLKIT_DIR/manifest/projects.tsv"
TMP="$(mktemp)"

cat > "$TMP" <<'EOF'
# Games restored by bootstrap.sh. Regenerate with ./snapshot.sh -- do not
# hand-edit unless you are adding a project that is not cloned yet.
#
# name<TAB>git remote<TAB>godot version
EOF

found=0
for dir in "$GAMES_ROOT"/projects/*/; do
  [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"

  if [[ ! -d "$dir/.git" ]]; then
    log_warn "$name is not a git repo -- skipped"
    continue
  fi

  remote="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$remote" ]]; then
    log_warn "$name has no 'origin' remote -- skipped (push it first)"
    continue
  fi

  ver="$GODOT_DEFAULT"
  [[ -f "$dir/.godot-version" ]] && ver="$(tr -d '[:space:]' < "$dir/.godot-version")"

  printf '%s\t%s\t%s\n' "$name" "$remote" "$ver" >> "$TMP"
  log_ok "$name  ->  $remote  ($ver)"
  found=$((found + 1))
done

if diff -q "$TMP" "$OUT" >/dev/null 2>&1; then
  log_ok "manifest already current ($found project(s))"
  rm -f "$TMP"
else
  mv "$TMP" "$OUT"
  log_do "manifest updated ($found project(s))"
  log_note "commit manifest/projects.tsv to persist this"
fi
