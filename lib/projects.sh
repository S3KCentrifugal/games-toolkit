# shellcheck shell=bash
# Restore game repos from manifest/projects.tsv. The toolkit holds pointers,
# never game content, so this repo stays small no matter how many games exist.

read_manifest() {
  # Emits: name<TAB>remote<TAB>version  (comments and blank lines stripped)
  local f="$TOOLKIT_DIR/manifest/projects.tsv"
  [[ -f "$f" ]] || return 0
  grep -vE '^\s*(#|$)' "$f" || true
}

ensure_project() {
  local name="$1" remote="$2" ver="$3"
  local dir="$GAMES_ROOT/projects/$name"

  if [[ -d "$dir/.git" ]]; then
    log_ok "project $name"
  elif [[ -d "$dir" ]]; then
    log_warn "project $name exists but is not a git repo -- left untouched"
    return 0
  else
    would "clone $name from $remote" && return 0
    log_do "clone $name"
    git clone --quiet "$remote" "$dir" || { log_err "clone failed: $remote"; return 0; }

    # A clone can exit 0 and still check out nothing (e.g. remote HEAD points at
    # a branch that does not exist). Catch it here rather than at `gd` time.
    if [[ ! -f "$dir/project.godot" ]]; then
      local branch
      branch="$(git -C "$dir" branch -r --format='%(refname:lstrip=3)' | grep -Ex 'main|master' | head -1)"
      if [[ -n "$branch" ]]; then
        log_warn "$name: remote HEAD is unset, checking out $branch"
        git -C "$dir" checkout --quiet "$branch"
      fi
      [[ -f "$dir/project.godot" ]] || log_warn "$name: no project.godot after clone -- check the remote"
    fi
  fi

  # The version marker is what bin/gd reads to pick an engine.
  if [[ -n "$ver" && ! -f "$dir/.godot-version" ]]; then
    would "write $name/.godot-version" && return 0
    log_do "write $name/.godot-version"
    printf '%s\n' "$ver" > "$dir/.godot-version"
  fi

  ensure_dir "$GAMES_ROOT/source/$name"
  ensure_dir "$GAMES_ROOT/exports/$name"
}

restore_projects() {
  local n=0 name remote ver
  while IFS=$'\t' read -r name remote ver; do
    [[ -n "$name" ]] || continue
    ensure_project "$name" "$remote" "$ver"
    n=$((n + 1))
  done < <(read_manifest)
  [[ "$n" == 0 ]] && log_note "no projects in manifest yet -- use bin/new-game to create one"
  return 0
}

# Warn about anything on disk that the manifest does not know about, so a
# forgotten project cannot silently fail to restore on the next machine.
check_drift() {
  local dir name known
  known="$(read_manifest | cut -f1)"
  for dir in "$GAMES_ROOT"/projects/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    if ! grep -qxF "$name" <<<"$known"; then
      log_warn "project '$name' is on disk but not in manifest -- run ./snapshot.sh"
    fi
  done
}
