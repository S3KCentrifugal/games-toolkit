#!/usr/bin/env bash
# Move the content git deliberately does not carry: library/ and source/.
#
# Set SYNC_REMOTE in machine.local.sh to an rsync-reachable path, e.g.
#   SYNC_REMOTE="/mnt/backup/games"                  # external drive
#   SYNC_REMOTE="rob@nas.local:/volume1/games"       # NAS over ssh
# For cloud, set SYNC_CMD=rclone and SYNC_REMOTE="gdrive:games".
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_ROOT="${GAMES_ROOT:-$(dirname "$TOOLKIT_DIR")}"
source "$TOOLKIT_DIR/lib/util.sh"
[[ -f "$TOOLKIT_DIR/machine.local.sh" ]] && source "$TOOLKIT_DIR/machine.local.sh"

SYNC_DIRS=(library source)
SYNC_CMD="${SYNC_CMD:-rsync}"
DIRECTION="${1:-}"

[[ -n "${SYNC_REMOTE:-}" ]] || die "SYNC_REMOTE is not set -- add it to $TOOLKIT_DIR/machine.local.sh"

case "$DIRECTION" in
  pull|push) ;;
  *) echo "usage: sync.sh {pull|push} [--dry-run]"; exit 2 ;;
esac
shift || true

EXTRA=("$@")

for d in "${SYNC_DIRS[@]}"; do
  local_path="$GAMES_ROOT/$d/"
  remote_path="$SYNC_REMOTE/$d/"

  if [[ "$DIRECTION" == pull ]]; then src="$remote_path"; dst="$local_path"
  else                                src="$local_path";  dst="$remote_path"
  fi

  log_head "$DIRECTION $d"
  case "$SYNC_CMD" in
    rsync)  rsync -avh --partial --info=progress2 "${EXTRA[@]}" "$src" "$dst" ;;
    rclone) rclone sync --progress "${EXTRA[@]}" "$src" "$dst" ;;
    *)      die "unsupported SYNC_CMD: $SYNC_CMD" ;;
  esac
done

log_ok "$DIRECTION complete"
