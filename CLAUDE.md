# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A [chezmoi](https://www.chezmoi.io/) dotfiles repository managing shell configuration, git settings, and SSH/GPG keys for Thom's machines (primarily macOS).

## Chezmoi File Naming Conventions

- `dot_foo` → `~/.foo` (dotfile)
- `exact_dot_foo/` → `~/.foo/` (directory where extra files are removed)
- `foo.tmpl` → file is a Go template, rendered by chezmoi
- `run_onchange_before_foo.sh.tmpl` → script run when its content changes (before applying)
- `private_dot_foo` → `~/.foo` (managed with restricted permissions)

## Templates

Files ending in `.tmpl` use Go template syntax with chezmoi variables. Common variables used here:

- `{{ .chezmoi.os }}` — `"darwin"` on macOS, `"linux"` on Linux
- `{{ .chezmoi.pathSeparator }}` — `/` on Unix
- `{{ include "file" | sha256sum }}` — used in `run_onchange_before_` scripts to trigger re-runs when a file changes

## Git Workflow

Commit directly to `main` — no feature branches or PRs for this repo. Chezmoi also autocommits changes to `main` by default.

## Applying Changes

```sh
chezmoi apply          # apply changes to the home directory
chezmoi diff           # preview what would change
chezmoi status         # show managed files with pending changes
```

## Encrypted Files

`key.txt.age` is an age-encrypted private key. The `run_onchange_before_decrypt-private-key.sh.tmpl` script decrypts it to `~/.config/chezmoi/key.txt` on first apply. Do not edit or commit changes to `key.txt.age` without understanding the encryption setup.

## Package Management

Homebrew packages are declared in `.chezmoidata.toml` (`packages.brew`, plus `packages.brew_darwin_extra` for macOS-only formulae). Add new packages there.

The per-OS `run_onchange_before_install-packages-*.sh.tmpl` scripts install the platform build prerequisites, then include the shared `.chezmoitemplates/brew-install.sh` block, which installs Homebrew if missing and runs `brew bundle`. Editing either the data file or the shared template changes the rendered script, so `chezmoi apply` re-runs it.

### Scripts that depend on brew-installed tools (e.g. `jq`)

Each `run_onchange_*`/`modify_*` script chezmoi runs is its own subprocess. On
a fresh machine, the `run_onchange_before_install-packages-*` script installs
Homebrew and does `eval "$(brew shellenv)"` to put it on `PATH` — but that
`PATH` update dies with that subprocess and never reaches later scripts
(e.g. `modify_private_dot_claude.json.tmpl`, `dot_claude/modify_private_settings.json.tmpl`),
which still see the original pre-Homebrew `PATH` from whatever invoked
`chezmoi init --apply`.

Any script/template that shells out to a brew-installed tool must locate
`brew` itself first — source the shared `.chezmoitemplates/brew-shellenv.sh`
template at the top of the script (`{{ template "brew-shellenv.sh" . }}`)
before relying on that tool being on `PATH`.

## Structure Overview

| File                    | Target                                          |
| ----------------------- | ----------------------------------------------- |
| `dot_zshrc.tmpl`        | `~/.zshrc` — aliases, completion, prompt        |
| `dot_zshenv.tmpl`       | `~/.zshenv` — PATH, env vars, Homebrew setup (all shells) |
| `dot_zprofile.tmpl`     | `~/.zprofile` — empty stub (login shells only)  |
| `exact_dot_zsh/`        | `~/.zsh/` — key bindings                        |
| `dot_gitconfig`         | `~/.gitconfig`                                  |
| `dot_gitignore`         | `~/.gitignore`                                  |
| `dot_tmux.conf`         | `~/.tmux.conf`                                  |
| `private_dot_gnupg/`    | `~/.gnupg/`                                     |
| `private_dot_ssh/`      | `~/.ssh/`                                       |
| `.chezmoiexternal.toml` | External archives/repos (e.g. tmux plugins)     |

## .chezmoiignore

`CLAUDE.md` and `key.txt.age` are ignored by chezmoi (listed in `.chezmoiignore`) — they live in the source directory but are never applied to the home directory.

When creating Claude memories, add any external memory files to `.chezmoiignore`.
