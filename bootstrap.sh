#!/usr/bin/env bash
# Rebuild the whole games environment from nothing.
#
#   git clone <remote> ~/games/toolkit && ~/games/toolkit/bootstrap.sh
#
# Idempotent: safe to re-run any time. Doubles as the upgrade path -- bump a
# version in manifest/engine.conf, commit, then pull and re-run on each machine.
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The toolkit's own location anchors everything. No guessing, no relocation.
GAMES_ROOT="${GAMES_ROOT:-$(dirname "$TOOLKIT_DIR")}"

usage() {
  cat <<'EOF'
usage: bootstrap.sh [options]

  --check        report what would change, touch nothing (same as doctor.sh)
  --no-templates skip the ~1 GB export templates download
  --engine-only  install engines, skip projects and shell wiring
  -h, --help     this text
EOF
}

ENGINE_ONLY=0
SKIP_TEMPLATES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)         DRY_RUN=1 ;;
    --no-templates)  SKIP_TEMPLATES=1 ;;
    --engine-only)   ENGINE_ONLY=1 ;;
    -h|--help)       usage; exit 0 ;;
    *)               usage; exit 2 ;;
  esac
  shift
done

# shellcheck source=lib/util.sh
source "$TOOLKIT_DIR/lib/util.sh"

need_cmd curl; need_cmd git; need_cmd unzip; need_cmd sha512sum

# Config load order: manifests, then per-machine overrides last so they win.
# shellcheck source=manifest/structure.conf
source "$TOOLKIT_DIR/manifest/structure.conf"
# shellcheck source=manifest/engine.conf
source "$TOOLKIT_DIR/manifest/engine.conf"
# shellcheck source=manifest/git.conf
source "$TOOLKIT_DIR/manifest/git.conf"
[[ -f "$TOOLKIT_DIR/machine.local.sh" ]] && source "$TOOLKIT_DIR/machine.local.sh"

(( SKIP_TEMPLATES )) && INSTALL_EXPORT_TEMPLATES=0

# shellcheck source=lib/engine.sh
source "$TOOLKIT_DIR/lib/engine.sh"
# shellcheck source=lib/projects.sh
source "$TOOLKIT_DIR/lib/projects.sh"
# shellcheck source=lib/shell.sh
source "$TOOLKIT_DIR/lib/shell.sh"

[[ "$DRY_RUN" == 1 ]] && log_note "check mode -- nothing will be modified"
log_note "root: $GAMES_ROOT"

log_head "structure"
for d in "${STRUCTURE_DIRS[@]}"; do ensure_dir "$GAMES_ROOT/$d"; done
[[ "$DRY_RUN" == 1 ]] || log_ok "${#STRUCTURE_DIRS[@]} directories"

log_head "engine"
for v in "${GODOT_VERSIONS[@]}"; do
  ensure_engine "$v"
  verify_engine "$v"
done
ensure_current_symlink "$GODOT_DEFAULT"

if (( ! ENGINE_ONLY )); then
  log_head "projects"
  restore_projects
  check_drift

  log_head "shell"
  ensure_launcher_link
  ensure_shell_env
  ensure_git_identity
  check_optional_tools
fi

log_head "summary"
if [[ "$DRY_RUN" == 1 ]]; then
  if (( CHANGES == 0 && PROBLEMS == 0 )); then
    log_ok "machine is in sync"
  else
    log_note "$CHANGES change(s) pending, $PROBLEMS warning(s) -- run without --check to apply"
  fi
else
  log_ok "bootstrap complete ($CHANGES change(s), $PROBLEMS warning(s))"
  log_note "open a new shell, or: source ~/.bashrc"
  log_note "then: gd            # project manager"
  log_note "      new-game NAME # scaffold a project"
fi

# Unmanaged content cannot come from git -- say so rather than leaving empty dirs.
for d in library source; do
  if [[ -d "$GAMES_ROOT/$d" ]] && [[ -z "$(find "$GAMES_ROOT/$d" -mindepth 1 -type f -print -quit 2>/dev/null)" ]]; then
    log_note "$d/ is empty -- restore it with ./sync.sh pull (not tracked in git)"
  fi
done
