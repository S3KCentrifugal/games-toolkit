# games-toolkit

Rebuilds my entire Godot development environment from a single clone.

```bash
git clone git@github.com:<you>/games-toolkit.git ~/games/toolkit
~/games/toolkit/bootstrap.sh
```

That installs Godot, restores every game repo, wires up `gd` and `new-game`,
and creates the directory tree. Re-running is a fast no-op, so it is also the
upgrade path.

## Layout

```
~/games/
├── toolkit/      this repo -- the only thing you need to clone
├── engine/       Godot versions, self-contained; `current` symlinks the default
├── projects/     one git repo per game (small: no caches, no authoring files)
├── library/      shared asset warehouse -- NOT in git
├── source/       .blend/.psd/.aseprite/masters, per game -- NOT in git
├── exports/      builds -- NOT in git
└── sandbox/      throwaway prototypes, no repo
```

Repos stay light because the three heavy categories live outside them:
`.godot/` (regenerable, often GBs), authoring files (a 40 MB `.psd` becomes a
200 KB `.png` in the project), and builds.

`library/` is the *unimported* warehouse. Copy what a game needs into that
game's `assets/` — do not symlink, because Godot's importer follows the link
and writes `.import` metadata that then disagrees across projects.

## Commands

| | |
|---|---|
| `./bootstrap.sh` | build or update this machine |
| `./bootstrap.sh --check` / `./doctor.sh` | report drift, change nothing |
| `./bootstrap.sh --no-templates` | skip the ~1 GB export templates |
| `./snapshot.sh` | regenerate `manifest/projects.tsv` from disk |
| `./sync.sh {pull,push}` | move `library/` and `source/` to/from a remote |
| `gd` | open the current project with its pinned Godot version |
| `gd --version-list` | installed engines |
| `new-game NAME` | scaffold a project, git repo, and manifest entry |

## Manifests

- `manifest/engine.conf` — Godot versions + sha512 checksums. To upgrade, add
  the version, set `GODOT_DEFAULT`, record its sum from the release's
  `SHA512-SUMS.txt`, commit, then pull and re-run bootstrap everywhere.
- `manifest/projects.tsv` — `name`, git remote, engine version. Regenerate with
  `./snapshot.sh`; never hand-edit except to add a repo not yet cloned.
- `manifest/structure.conf` — directories to guarantee.
- `machine.local.sh` — gitignored per-machine overrides. See
  `machine.local.sh.example`.

## Drift

The failure mode for a repo like this is creating a game, forgetting to record
it, and finding out six months later on a new machine. Two guards:
`bootstrap.sh` warns about any project on disk that is missing from the
manifest, and `snapshot.sh` rewrites the manifest from reality. `new-game`
handles it automatically.

## What bootstrap cannot restore

`library/` and `source/` are excluded from git on purpose — they are the
reason the repos stay small — so a fresh machine gets the tree and no content.
Set `SYNC_REMOTE` in `machine.local.sh` and use `./sync.sh pull`. Bootstrap
prints a reminder when those directories are empty.

`exports/` does not matter; rebuild it.

## Version pinning

Each project holds a `.godot-version`. `gd` reads it and launches that exact
engine, so opening a 4.7 project with 4.8 — which rewrites files
irreversibly — cannot happen by accident.

Engines run in Godot's self-contained mode (a `._sc_` file beside the binary),
so editor settings and export templates live in `engine/<version>/editor_data/`
rather than `~/.local/share/godot/`. Versions are fully isolated; uninstalling
is `rm -rf`.
