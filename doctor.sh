#!/usr/bin/env bash
# Report whether this machine matches the manifests. Changes nothing.
# Exactly the same code path as bootstrap.sh, with writes disabled.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap.sh" --check "$@"
