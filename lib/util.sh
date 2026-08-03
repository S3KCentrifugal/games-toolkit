# shellcheck shell=bash
# Shared helpers. Sourced by bootstrap.sh, doctor.sh, snapshot.sh.

# NOTE: bash expands every word on a `local` line before the builtin assigns
# any of them, so `local a="$1" b="$a"` explodes under `set -u`. Declare on
# separate lines whenever one variable references another.

DRY_RUN="${DRY_RUN:-0}"
CHANGES=0
PROBLEMS=0

if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_DO=$'\033[36m'; C_WARN=$'\033[33m'
  C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=; C_DO=; C_WARN=; C_ERR=; C_DIM=; C_OFF=
fi

# All logging goes to stderr so helpers can return values on stdout via $(...)
# without their own progress output being captured as part of the value.
log_ok()   { printf '%s  ok  %s %s\n'   "$C_OK"   "$C_OFF" "$*" >&2; }
log_do()   { printf '%s ---> %s %s\n'   "$C_DO"   "$C_OFF" "$*" >&2; CHANGES=$((CHANGES + 1)); }
log_warn() { printf '%s warn %s %s\n'   "$C_WARN" "$C_OFF" "$*" >&2; PROBLEMS=$((PROBLEMS + 1)); }
log_err()  { printf '%s FAIL %s %s\n'   "$C_ERR"  "$C_OFF" "$*" >&2; PROBLEMS=$((PROBLEMS + 1)); }
log_note() { printf '%s      %s%s\n'    "$C_DIM"  "$*" "$C_OFF" >&2; }
log_head() { printf '\n%s== %s ==%s\n'  "$C_DIM"  "$*" "$C_OFF" >&2; }

die() { log_err "$*"; exit 1; }

# In check mode we announce intent but never touch the filesystem.
would() {
  if [[ "$DRY_RUN" == 1 ]]; then
    log_do "would $*"
    return 0   # caller skips the real work
  fi
  return 1
}

ensure_dir() {
  local d="$1"
  [[ -d "$d" ]] && return 0
  would "create $d" && return 0
  log_do "create $d"
  mkdir -p "$d"
}

# Look for an already-downloaded copy before hitting the network.
find_cached() {
  local name="$1" dir
  for dir in "${CACHE_DIRS[@]}"; do
    [[ -f "$dir/$name" ]] && { printf '%s' "$dir/$name"; return 0; }
  done
  return 1
}

fetch() {
  local url="$1" dest="$2"
  log_note "GET $url"
  curl -fL --progress-bar --retry 3 --retry-delay 2 -o "$dest" "$url" \
    || die "download failed: $url"
}

verify_sha512() {
  local file="$1" want="$2" got
  [[ -n "$want" ]] || { log_warn "no checksum recorded for $(basename "$file") -- skipping verify"; return 0; }
  got="$(sha512sum "$file" | cut -d' ' -f1)"
  [[ "$got" == "$want" ]] || die "checksum mismatch for $(basename "$file")
  expected $want
  got      $got"
  log_note "sha512 verified"
}

# Idempotent block insert into a shell rc file. Rewrites cleanly on every run.
guarded_append() {
  local file="$1" tag="$2" body="$3" open close tmp
  open="# >>> $tag >>>"
  close="# <<< $tag <<<"

  if [[ -f "$file" ]] && grep -qF "$open" "$file"; then
    # Already present and byte-identical? nothing to do.
    if diff -q <(sed -n "/$(sed 's/[][\.*^$/]/\\&/g' <<<"$open")/,/$(sed 's/[][\.*^$/]/\\&/g' <<<"$close")/p" "$file") \
               <(printf '%s\n%s\n%s\n' "$open" "$body" "$close") >/dev/null 2>&1; then
      log_ok "$(basename "$file") block '$tag'"
      return 0
    fi
  fi

  would "update block '$tag' in $file" && return 0
  log_do "update block '$tag' in $file"
  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    sed "/$(sed 's/[][\.*^$/]/\\&/g' <<<"$open")/,/$(sed 's/[][\.*^$/]/\\&/g' <<<"$close")/d" "$file" > "$tmp"
  fi
  printf '%s\n%s\n%s\n' "$open" "$body" "$close" >> "$tmp"
  mv "$tmp" "$file"
}

# Turn 4.7.1 into the shell-variable-safe form used in engine.conf.
ver_key() { printf '%s' "${1//./_}"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
