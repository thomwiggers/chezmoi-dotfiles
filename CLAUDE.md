# CLAUDE.md

Thom's dotfiles: a Nix flake with standalone Home Manager, checked out at
`~/.config/home-manager` (where `home-manager` looks; `bootstrap.sh` clones
it there). The chezmoi sources (`dot_*`, `private_*`, `exact_*`, `run_*`,
`modify_*`, `.chezmoi*`) remain for machines not yet migrated; see
`MIGRATION.md`.

## Git

Commit directly to `main`; stage specific files.

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | `roles` (darwin, linux, linux-arm, chroot) × `users` (thom, thomwiggers) → `homeConfigurations."<user>@<role>"`; `machines/` adds `<user>@<hostname>` aliases |
| `home.nix`, `hosts/<role>.nix` | module imports; per-role settings (`thom.container`) |
| `modules/*.nix` | one module per program |
| `files/` | static files, linked by `modules/files.nix` |
| `secrets/*.age` | age-encrypted files; targets in `modules/secret-files.nix`, decrypted at activation by `modules/secrets.nix` |
| `machines/<hostname -s>` | the machine's role; written and committed by `bootstrap.sh` |
| `bootstrap.sh [role]` | Nix (or nix-user-chroot for `chroot`), age key, clone to `~/.config/home-manager`, switch, register machine, login shell |
| `verify.sh [role]` | compares chezmoi's output with the Home Manager build; expect `mismatch=0` |

## Commands

- `nix build '.#homeConfigurations."thom@linux".activationPackage'` - build without activating (never `switch` from a session)
- `nix flake check` - builds every role native to this machine
- `nix fmt` - format with nixfmt-tree
- `./verify.sh linux` - parity check against chezmoi
- Add `--extra-experimental-features 'nix-command flakes'` if Nix complains; nix needs the daemon socket, so run it outside the Bash sandbox if blocked
- Quote flake refs in zsh: `'.#thom@darwin'` (EXTENDED_GLOB makes `#` a glob)

## Gotchas

- Flakes only see git-tracked files: `git add` new files before building.
- The repo is public and the Nix store world-readable: secrets go in
  `secrets/*.age` (`age -a -r <age1pq1… recipient from .chezmoi.toml.tmpl>`),
  never in Nix. Don't decrypt secrets in a session.
- SSH: only generic settings are in `programs.ssh`; host blocks live in
  `secrets/ssh_config_private.age` (Included). Home Manager writes `Host *` last.
- New top-level dirs must go in `.chezmoiignore`, or chezmoi applies them to `~`.
- Until chezmoi is retired, keep shared behaviour in step in its templates
  (e.g. `dot_zshrc.tmpl`, `dot_claude/modify_private_settings.json.tmpl`);
  `verify.sh` catches drift.
- `chroot` role: `/nix` exists only inside nix-user-chroot.
