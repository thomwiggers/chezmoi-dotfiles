# chezmoi → Home Manager migration

Status: **Step 1 (inventory) — awaiting review.** Nothing below is implemented yet.

Inventory sources: `chezmoi managed` (run on Linux host `development`, Debian 13),
`chezmoi data`, the source tree, and `.chezmoiignore` (which hides darwin-only
targets on Linux — those rows are added by hand below).

## 1. Managed targets

Type key: **S** static · **T** template · **E** age-encrypted · **M** `modify_`
script (merges into an app-owned file) · **R** `run_` script · **X** external ·
**L** symlink.

### Shell

| Target | Source | Type | Planned HM mechanism |
|---|---|---|---|
| `~/.zshenv` | `dot_zshenv.tmpl` | T (os) | `programs.zsh.envExtra` (+ `home.sessionVariables` where 1:1) |
| `~/.zprofile` | `dot_zprofile.tmpl` | T (os) | `programs.zsh.profileExtra` |
| `~/.zshrc` | `dot_zshrc.tmpl` | T (os) | `programs.zsh.initContent` with `lib.mkOrder`; `completionInit` set explicitly to reproduce the current bare `compinit` |
| `~/.zsh/functions.sh` | `exact_dot_zsh/functions.sh` | S | `home.file` (dir becomes HM-owned, so "exact" is implicit) |
| `~/.zsh/key-bindings.zsh` | `exact_dot_zsh/executable_key-bindings.zsh` | S (+x) | `home.file` with `executable = true` |
| `~/.zsh/completions/_package` | `exact_dot_zsh/completions/_package` | S | `home.file` |
| `~/.zsh/zsh-defer/**` | `.chezmoiexternal.toml` | X (archive, 500h refresh) | `pkgs.zsh-defer` (nixpkgs, 2022-06-13 = upstream HEAD); sourced from store path, `~/.zsh/zsh-defer` no longer created |
| `~/.config/starship.toml` | `dot_config/starship.toml` | S | `programs.starship.settings` (TOML → Nix attrset) or keep as `xdg.configFile` — see Q7 |

### Git / GPG / SSH

| Target | Source | Type | Planned HM mechanism |
|---|---|---|---|
| `~/.gitconfig` | `dot_gitconfig.tmpl` | T (os, arch → `gh` path) | `programs.git` (+ `programs.git.delta` / `programs.delta`); gh path → `"${pkgs.gh}/bin/gh"` on all hosts. HM writes `~/.config/git/config`, not `~/.gitconfig` — see notes |
| `~/.gitignore` | `dot_gitignore` | S | `programs.git.ignores` or `home.file` (path referenced by `core.excludesfile`) |
| `~/.gitattributes` | `dot_gitattributes` | S | `programs.git.attributes` or `home.file` |
| `~/.gnupg/gpg.conf` | `private_dot_gnupg/gpg.conf` | S (0700 dir) | `programs.gpg.settings` or `home.file`; HM's gpg module manages dir perms |
| `~/.ssh/config` | `private_dot_ssh/encrypted_config.age` | E | **Cannot become `programs.ssh` without decrypting** (ground rule). Plan: secret file → `~/.ssh/config` — see Q4 |
| `~/.ssh/sockets/` | `private_dot_ssh/private_sockets/.keep` | S (empty dir, 0700) | `home.activation` `mkdir -m700 -p` (HM can't own a writable empty dir via symlinks) |

### Terminal / editor / apps

| Target | Source | Type | Planned HM mechanism |
|---|---|---|---|
| `~/.tmux.conf` | `dot_tmux.conf` | S | `programs.tmux` with all module defaults pinned to current values, `extraConfig` for the rest. **No plugins** — every `@plugin` and TPM line is commented out today, and the TPM external is commented out too |
| `~/.config/ghostty/config.ghostty` | `dot_config/ghostty/config.ghostty` | S | `programs.ghostty.settings`, `package = null` on darwin (Linux: also `null`? see Q6) |
| `~/.config/ghostty/default.config` | `dot_config/ghostty/default.config` | S (4091-line default dump) | `xdg.configFile` unchanged (reference only) |
| `~/.config/nvim/**` (13 files) | `dot_config/exact_nvim/**` | S (exact) | `xdg.configFile."nvim".source` with `recursive = true` — lazy.nvim writes `lazy-lock.json`/`lazyvim.json` into this dir, so it must stay a real dir |
| `~/.config/gh/config.yml` | `dot_config/gh/private_config.yml` | S | `programs.gh.settings`. Note `gh config set` will fail on a store symlink — acceptable? |
| `~/.config/halloy/config.toml` | `dot_config/exact_halloy/encrypted_config.toml.age` | E | secret → path |
| `~/.config/halloy/themes/catppucin light.toml` | `…/exact_private_themes/encrypted_catppucin light.toml.age` | E | secret → path |
| `~/.config/senpai/senpai.scfg` | `dot_config/exact_senpai/encrypted_private_senpai.scfg.age` | E | secret → path |
| `~/.config/runitor/hc_key` | `dot_config/runitor/encrypted_hc_key.age` | E | secret → path |
| `~/Library/Application Support/senpai/senpai.scfg` *(darwin only)* | `private_Library/…/symlink_senpai.scfg` | L → `/Users/thom/.config/senpai/senpai.scfg` | `home.file.<>.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/senpai/senpai.scfg"`, darwin only |
| `~/.latexmkrc` | `dot_latexmkrc` | S (uses `open -a Skim.app` — mac-only behaviour, deployed everywhere today) | `home.file` |

### Claude Code

| Target | Source | Type | Planned HM mechanism |
|---|---|---|---|
| `~/.claude/CLAUDE.md` | `dot_claude/CLAUDE.md` | S | `home.file` |
| `~/.claude/skills/using-ruff/SKILL.md` | `dot_claude/skills/using-ruff/SKILL.md` | S | `home.file` |
| `~/.claude.json` | `modify_private_dot_claude.json.tmpl` | M (jq merge) | `home.activation` (after `writeBoundary`) running the same jq merge with `${pkgs.jq}`; **must not** be a store symlink — Claude Code writes this file constantly |
| `~/.claude/settings.json` | `dot_claude/modify_private_settings.json.tmpl` | M (jq merge; os + container detection + `DARWIN_USER_TEMP_DIR`) | same: `home.activation` jq merge; container detection and `getconf DARWIN_USER_TEMP_DIR` move into the activation script at run time (they can't be evaluated purely) — see Q5 |

### Externals

| Target | Source | Type | Planned HM mechanism |
|---|---|---|---|
| `~/.zsh/zsh-defer` | `.chezmoiexternal.toml` | X | `pkgs.zsh-defer` (above) |
| `~/.local/bin/devbox` *(darwin only)* | `.chezmoiexternal.toml` (raw file, `refreshPeriod = 1m`) | X | flake input `thom-container` (`flake = false`) → `home.file.".local/bin/devbox"`. **Behaviour change:** updates only on `nix flake update`, not every minute |
| `~/.tmux/plugins/tpm` | `.chezmoiexternal.toml` | X (commented out) | dropped (unused) |

### `run_` scripts

| Script | When | What it does | Planned HM mechanism |
|---|---|---|---|
| `run_onchange_before_decrypt-private-key.sh.tmpl` | first apply | passphrase-decrypts `key.txt.age` → `~/.config/chezmoi/key.txt` | **stays manual** (interactive passphrase). Documented in §5; key path moves to `~/.config/sops/age/keys.txt` (or keep path, configurable) |
| `run_onchange_before_install-packages-{darwin,debian,arch,amzn}.sh.tmpl` | on package-list change | sudo distro prereqs (build-essential, curl, git, bubblewrap, socat) + Homebrew + `brew bundle` | brew list → `home.packages` (see §3). **sudo prereqs can't move into HM** — `bubblewrap`/`socat` (for the Claude Code sandbox) come from nixpkgs on Linux instead; build toolchains stay manual |
| `run_after_generate-ls-colors.sh` | every apply | `vivid generate molokai > ~/.cache/ls_colors` | build-time: `runCommand` with `vivid` → `home.file.".cache/ls_colors".text` — or keep as activation. Pure render is preferable |
| `run_after_nvim_sync.sh` | every apply | `nvim --headless "+Lazy! sync"` | `home.activation` (after `writeBoundary`, `run` wrapper so `--dry-run` skips it) |
| `run_onchange_after_setup-thom-container.sh.tmpl` | darwin, on change | `container system start --enable-kernel-install` | `home.activation`, darwin only; `container` is in nixpkgs (`pkgs.container`) |

### Repo-only (not applied; `.chezmoiignore`)

`CLAUDE.md`, `.claude/MEMORY.md`, `.claude/feedback_chezmoi_template_verification.md`,
`.claude/worktrees/**`, `key.txt.age`, `.config/nvim/lazy-lock.json`, `.config/nvim/lazyvim.json`.
`.chezmoi.toml.tmpl` / `.chezmoidata.toml` / `.chezmoitemplates/*` are chezmoi
machinery and go away with it.

## 2. Template variables and divergence points

| Variable | Used in | Divergence |
|---|---|---|
| `.chezmoi.os` | zshenv, zprofile, zshrc (`gls` vs `ls`), settings.json (Keychains deny, tmp dir), install scripts, setup-thom-container, `.chezmoiignore` | darwin vs linux → `pkgs.stdenv.isDarwin` |
| `.chezmoi.arch` | gitconfig (`/opt/homebrew/bin/gh` vs `/usr/local/bin/gh`) | disappears: use `${pkgs.gh}` |
| `.chezmoi.osRelease.{id,idLike,versionID}` | install-packages-{debian,arch,amzn} | distro → not modelled in HM (sudo prereqs manual) |
| `.chezmoi.pathSeparator` | zshrc **comment only** (`parameter/command substitution`) | render literal `/` |
| `.chezmoi.args`, `.chezmoi.executable`, `.chezmoi.sourceDir` | decrypt-private-key | gone (manual step) |
| `.claude.default_mode` (`"auto"`) | settings.json | module option `thom.claude.defaultMode` |
| `.packages.brew`, `.packages.brew_darwin_extra` | brew-install | `home.packages` (+ darwin extras) |
| `.cpu.cores`, `.cpu.threads` | **nowhere** | dead data; dropped |
| `env "container"`, `stat /.dockerenv` etc. | settings.json | runtime container detection (Q5) |

**Nothing branches on hostname.** The real axes are: OS (darwin/linux), arch,
Linux distro (install scripts only), and "inside a container".

## 3. Package mapping (`.chezmoidata.toml`)

| brew | nixpkgs | note |
|---|---|---|
| bat, dust, gh, git, git-delta (`delta`), jq, neovim, ripgrep, starship, tmux, uv, vivid, wget, xz, zstd | same names (`delta` for git-delta) | several become `programs.*` |
| python | `python3` | zprofile adds `/opt/homebrew/opt/python/libexec/bin` (unversioned `python`) on darwin — needs replacement |
| zsh | `programs.zsh` | login shell change is manual (`chsh`; not possible without root on chroot hosts) |
| zsh-completions | `pkgs.zsh-completions` | |
| zsh-syntax-highlighting | `programs.zsh.syntaxHighlighting` **not used** (it loads eagerly); source `${pkgs.zsh-syntax-highlighting}/share/…` via `zsh-defer` instead |
| darwin: container, gnu-sed, gnu-tar | `container`, `gnused`, `gnutar` | `gls` alias needs `coreutils` (brew coreutils isn't in the list today — `gls` currently relies on it being installed some other way) |

Homebrew itself: drop on Linux. On darwin keep brew for casks/GUI apps? (Q3)

## 4. Known risks / expected verify.sh mismatches

1. **PQ age key vs sops.** The recipient is `age1pq1…` (post-quantum hybrid,
   age ≥ 1.3). nixpkgs has `age` 1.3.2 (supports it) but `sops` 3.13.3 — I could
   not confirm its vendored `filippo.io/age` handles `age1pq` recipients
   (inspecting the source was blocked). If it doesn't, alternatives:
   **agenix** (shells out to the `age` binary → PQ works), or a small
   `home.activation` step running `age -d -i <key>`. Needs a decision (Q2).
2. **Can't build darwin here.** This box is x86_64-linux with no darwin
   builder; `aarch64-darwin` configs can only be *evaluated*
   (`nix eval …activationPackage.drvPath`). Likewise `chezmoi cat` only renders
   for the current OS, so darwin verification = eval + manual inspection.
3. **verify.sh must never `chezmoi cat` encrypted targets** (that decrypts).
   Use `chezmoi managed --include=files --exclude=encrypted` for the file list;
   encrypted targets: path presence only.
4. **`modify_` targets** (`.claude.json`, `settings.json`) aren't in
   `result/home-files`. verify.sh instead runs the generated activation jq
   filter on `{}` and diffs against `chezmoi cat` (which runs the modify script
   on the current file — so compare with `echo '{}' | …` on both sides).
5. **Module-generated files will differ textually**: `.zshrc`/`.zshenv`
   (HM wrapper lines), `.gitconfig` (HM writes `~/.config/git/config` in its
   own INI layout — compare semantically via sorted `git config -f … --list`),
   `.tmux.conf` (HM prepends its own defaults; all will be pinned to current
   values), `gh/config.yml` (YAML re-serialised, comments lost),
   `gpg.conf` if moved to `programs.gpg`.
6. **zshrc semantic changes**: zsh-syntax-highlighting path switches from
   `$HOMEBREW_PREFIX/share/…` / `/usr/share/zsh/plugins/…` to a store path;
   `zsh-defer` loaded from store not `~/.zsh/zsh-defer`; `gls` from
   nix `coreutils`.
7. **Brief vs reality.** The task brief mentions "the custom compinit with
   glob qualifiers" and TPM plugins. Neither exists in the current source: the
   zshrc calls a plain `compinit` at the end, and every tmux plugin line is
   commented out. I'll reproduce what's actually there (plain `compinit`, no
   plugins) unless you want those added (Q8).
8. **devbox** loses the 1-minute auto-refresh (pinned flake input).

## 5. Left manual (will grow)

- Decrypt the age identity (`age -d key.txt.age > ~/.config/sops/age/keys.txt`,
  chmod 600) — interactive passphrase.
- Re-encrypt the five `encrypted_*` files into the chosen secrets format (TODO for Thom).
- Distro prerequisites needing sudo (build-essential/base-devel, Development Tools).
- `chsh` to the Nix zsh (root hosts only).
- First activation: `home-manager switch -b hm-bak --flake .#<cfg>`.
- After cut-over: `chezmoi purge`.

## 6. Open questions (blocking Step 2 / 6)

1. **Hosts.** No hostnames appear in chezmoi data. What should the
   `homeConfigurations` be? Proposal, keyed by role rather than hostname:
   `thom@darwin` (aarch64-darwin), `thom@linux` (x86_64-linux, this box
   `development`), `thom@linux-arm` (aarch64-linux, e.g. devbox containers on
   Apple Silicon), `thom@chroot` (x86_64-linux, nix-user-chroot). Or give me
   real hostnames.
2. **Secrets tool**: sops-nix as briefed (risk: PQ recipient support), or agenix?
3. **Homebrew on darwin**: drop entirely, or keep for casks/GUI apps (Ghostty
   etc.) outside HM?
4. **`.ssh/config`**: it's encrypted, and converting to `programs.ssh` requires
   reading the plaintext. Keep it as an opaque secret file (my proposal), or
   will you decrypt it yourself so I can port it?
5. **Claude settings container detection**: keep runtime detection inside the
   activation script (my proposal, matches current behaviour), or make it a
   per-host option?
6. **ghostty on Linux**: install `pkgs.ghostty` on Linux hosts, or config only
   (`package = null` everywhere — e.g. this box is headless)?
7. **starship**: port `starship.toml` to `programs.starship.settings`, or keep it
   as a verbatim file (byte-identical verify)?
8. Confirm: reproduce the current plain `compinit` and no tmux plugins (vs the
   brief's glob-qualifier compinit / `pkgs.tmuxPlugins`)?
9. **nix-user-chroot**: HM's `~/.zshrc` etc. are symlinks into `/nix/store`,
   which only resolves *inside* the chroot namespace. Outside it they dangle,
   so the host's login shell must not be zsh-with-HM-dotfiles. Plan: on
   `thom@chroot`, ship nothing at the login entry point and document a
   non-Nix shim (e.g. `~/.bash_profile`: `exec nix-user-chroot ~/.nix
   ~/.nix-profile/bin/zsh -l`) that you install by hand. How do you enter the
   chroot today — and is `~/.nix` the store root? HM also needs
   `targets.genericLinux.enable = true` on non-NixOS Linux.
