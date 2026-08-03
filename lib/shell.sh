# shellcheck shell=bash
# PATH wiring and the `gd` launcher symlink.

ensure_shell_env() {
  local body rc
  body="export GAMES_ROOT=\"$GAMES_ROOT\"
export PATH=\"\$GAMES_ROOT/toolkit/bin:\$PATH\""

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    guarded_append "$rc" "games-toolkit" "$body"
  done
}

ensure_launcher_link() {
  local bindir="$HOME/.local/bin" link="$HOME/.local/bin/gd" target="$TOOLKIT_DIR/bin/gd"
  ensure_dir "$bindir"
  if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
    log_ok "~/.local/bin/gd"
    return 0
  fi
  would "link ~/.local/bin/gd" && return 0
  log_do "link ~/.local/bin/gd"
  ln -sfn "$target" "$link"
}

# A brand new machine usually has no git identity, which turns into a confusing
# failure at the first commit rather than at setup time.
ensure_git_identity() {
  local name email
  name="$(git config --global user.name  2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"

  if [[ -n "$name" && -n "$email" ]]; then
    log_ok "git identity ($name <$email>)"
    return 0
  fi

  if [[ -n "${GIT_USER_NAME:-}" && -n "${GIT_USER_EMAIL:-}" ]]; then
    would "set git identity to $GIT_USER_NAME <$GIT_USER_EMAIL>" && return 0
    log_do "set git identity to $GIT_USER_NAME <$GIT_USER_EMAIL>"
    git config --global user.name  "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    return 0
  fi

  log_warn "git has no global identity -- commits will fail"
  log_note "set GIT_USER_NAME / GIT_USER_EMAIL in manifest/git.conf, or run:"
  log_note "  git config --global user.name  \"Your Name\""
  log_note "  git config --global user.email \"you@example.com\""
}

check_optional_tools() {
  command -v git-lfs >/dev/null 2>&1 \
    && log_ok "git-lfs" \
    || log_note "git-lfs not installed (only needed if you version large binaries)"
}
