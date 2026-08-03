# shellcheck shell=bash
# Godot engine install. Every version is fully self-contained under
# engine/<version>/ so upgrades cannot disturb an older project's setup and
# uninstalling is `rm -rf`.

godot_url()     { printf 'https://github.com/godotengine/godot/releases/download/%s-stable/Godot_v%s-stable_linux.x86_64.zip' "$1" "$1"; }
godot_tpz_url() { printf 'https://github.com/godotengine/godot/releases/download/%s-stable/Godot_v%s-stable_export_templates.tpz' "$1" "$1"; }

godot_sha()     { local k; k="$(ver_key "$1")"; local v="GODOT_SHA_$k";     printf '%s' "${!v-}"; }
godot_tpz_sha() { local k; k="$(ver_key "$1")"; local v="GODOT_TPZ_SHA_$k"; printf '%s' "${!v-}"; }

# Godot names its template directory with dots: 4.7.1.stable
tpl_dirname() { printf '%s.stable' "$1"; }

# Fetch into the engine cache, reusing ~/Downloads if the file is already there.
_acquire() {
  local name="$1" url="$2" sha="$3"
  local dest="$GAMES_ROOT/engine/.cache/$name"
  local cached
  if [[ -f "$dest" ]]; then
    log_note "using cached $name"
  elif cached="$(find_cached "$name")"; then
    log_note "found $name in $(dirname "$cached")"
    cp "$cached" "$dest"
  else
    fetch "$url" "$dest"
  fi
  verify_sha512 "$dest" "$sha"
  printf '%s' "$dest"
}

ensure_engine() {
  local v="$1"
  local dir="$GAMES_ROOT/engine/$v"
  local zip tmp bin

  if [[ -x "$dir/godot" ]]; then
    log_ok "engine $v"
  else
    if would "install Godot $v"; then
      return 0
    fi
    log_do "install Godot $v"
    ensure_dir "$dir"
    zip="$(_acquire "Godot_v${v}-stable_linux.x86_64.zip" "$(godot_url "$v")" "$(godot_sha "$v")")"

    tmp="$(mktemp -d)"
    unzip -q "$zip" -d "$tmp" || die "could not unzip $zip"
    bin="$(find "$tmp" -maxdepth 2 -type f -name 'Godot_v*_linux.x86_64' | head -1)"
    [[ -n "$bin" ]] || die "no Godot binary inside $zip"
    mv "$bin" "$dir/godot"
    chmod +x "$dir/godot"
    rm -rf "$tmp"

    # Self-contained mode: editor settings and export templates live in
    # engine/<v>/editor_data/ instead of ~/.local/share/godot/.
    touch "$dir/._sc_"
  fi

  ensure_export_templates "$v"
}

ensure_export_templates() {
  local v="$1"
  local dir="$GAMES_ROOT/engine/$v"
  local target="$dir/editor_data/export_templates/$(tpl_dirname "$v")"
  local tpz tmp

  if [[ "${INSTALL_EXPORT_TEMPLATES:-1}" != 1 ]]; then
    log_note "export templates disabled (INSTALL_EXPORT_TEMPLATES=0)"
    return 0
  fi
  if [[ -f "$target/linux_release.x86_64" ]]; then
    log_ok "export templates $v"
    return 0
  fi
  if [[ -z "$(godot_tpz_sha "$v")" ]]; then
    log_warn "no template checksum for $v -- skipping export templates"
    return 0
  fi
  would "install export templates $v (~1 GB)" && return 0

  log_do "install export templates $v"
  tpz="$(_acquire "Godot_v${v}-stable_export_templates.tpz" "$(godot_tpz_url "$v")" "$(godot_tpz_sha "$v")")"
  tmp="$(mktemp -d)"
  unzip -q "$tpz" -d "$tmp" || die "could not unzip $tpz"
  [[ -d "$tmp/templates" ]] || die "unexpected .tpz layout (no templates/ dir)"
  ensure_dir "$(dirname "$target")"
  rm -rf "$target"
  mv "$tmp/templates" "$target"
  rm -rf "$tmp"
}

ensure_current_symlink() {
  local v="$1" link="$GAMES_ROOT/engine/current"
  if [[ -L "$link" && "$(readlink "$link")" == "$v" ]]; then
    log_ok "engine/current -> $v"
    return 0
  fi
  would "point engine/current at $v" && return 0
  log_do "point engine/current at $v"
  ln -sfn "$v" "$link"
}

verify_engine() {
  local v="$1" out
  [[ "$DRY_RUN" == 1 ]] && return 0
  out="$("$GAMES_ROOT/engine/$v/godot" --headless --version 2>/dev/null | tail -1)"
  [[ "$out" == "$v"* ]] || { log_warn "engine $v reports version '$out'"; return 0; }
  log_ok "engine $v runs ($out)"
}
