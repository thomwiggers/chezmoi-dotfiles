# chezmoi → Home Manager migration

Status: **implemented on branch `hm-migration`; not yet activated anywhere.**
`nix flake check` passes, every role evaluates, the x86_64-linux roles build,
and `./verify.sh` reports `ok=33 explained=13 mismatch=0` on this machine.

The chezmoi sources are still in the repo, untouched (only `.chezmoiignore`
gained entries hiding the new files). Nothing has been deleted.

## Layout

| Path | What |
|---|---|
| `flake.nix` | nixpkgs (unstable) + home-manager (follows nixpkgs) + `thom-container` (devbox). `homeConfigurations."thom@<role>"`, `checks`, `packages.home-manager` (pinned CLI) |
| `home.nix` | shared entry point; imports `modules/*` |
| `hosts/<role>.nix` | per-role differences (`thom.container`, genericLinux) |
| `modules/options.nix` | `thom.container`, `thom.claude.defaultMode` |
| `modules/zsh.nix` | programs.zsh, programs.starship, session vars |
| `modules/git.nix` | programs.git, programs.gh, programs.gpg |
| `modules/tmux.nix` | programs.tmux |
| `modules/ssh.nix` | programs.ssh (+ Include of the encrypted part) |
| `modules/ghostty.nix` | programs.ghostty (darwin only) |
| `modules/packages.nix` | CLI tools (was the Homebrew list) |
| `modules/claude.nix` | Claude Code settings merges (activation) |
| `modules/secrets.nix` / `secret-files.nix` | age decryption at activation / which file goes where |
| `modules/scripts.nix` | former `run_` scripts and externals |
| `modules/files.nix` + `files/` | files deployed verbatim (nvim, zsh helpers, Claude md, latexmkrc) |
| `secrets/*.age` | the chezmoi ciphertexts, copied byte-for-byte |
| `bootstrap.sh` | fresh-machine setup (root or nix-user-chroot) |
| `verify.sh` | compares the build with chezmoi's rendering |

## Roles

Nothing in the chezmoi setup keyed on hostname; the real axes were OS, arch
and "inside a container". Configurations are therefore per role:

| Config | System | `thom.container` | Notes |
|---|---|---|---|
| `thom@darwin` | aarch64-darwin | false | Macs |
| `thom@linux` | x86_64-linux | true | e.g. `development` (Incus/LXC) |
| `thom@linux-arm` | aarch64-linux | true | devbox under Apple's container |
| `thom@chroot` | x86_64-linux | false | no root; Nix in `~/.nix` via nix-user-chroot |

`thom.container` replaces chezmoi's runtime detection (`$container`,
`/.dockerenv`, `/run/.containerenv`, `/run/systemd/container`) and only feeds
Claude Code's `sandbox.enableWeakerNestedSandbox`. Add a role (or override in a
host file) if a machine doesn't fit.

## Target-by-target mapping

Type key: **S** static · **T** template · **E** age-encrypted · **M** `modify_`
script · **R** `run_` script · **X** external · **L** symlink.

| Old target | chezmoi source | Type | Now |
|---|---|---|---|
| `~/.zshrc` | `dot_zshrc.tmpl` | T | `programs.zsh` (`setOptions`, `history`, `shellAliases`, `initContent` with `mkOrder` 500/550/1000/1450/1500, `completionInit = ""`) |
| `~/.zshenv` | `dot_zshenv.tmpl` | T | `home.sessionVariables` / `home.sessionPath` + `envExtra` |
| `~/.zprofile` | `dot_zprofile.tmpl` | T | `programs.zsh.profileExtra` |
| `~/.zsh/{functions.sh,key-bindings.zsh,completions/_package}` | `exact_dot_zsh/` | S | `home.file` from `files/zsh/` |
| `~/.zsh/zsh-defer/**` | `.chezmoiexternal.toml` | X | `pkgs.zsh-defer` (store path on `fpath`) |
| `~/.config/starship.toml` | `dot_config/starship.toml` | S | `programs.starship.settings` |
| `~/.gitconfig` | `dot_gitconfig.tmpl` | T | `programs.git.settings` → `~/.config/git/config` |
| `~/.gitignore` | `dot_gitignore` | S | `programs.git.ignores` → `~/.config/git/ignore` |
| `~/.gitattributes` | `dot_gitattributes` | S | `programs.git.attributes` → `~/.config/git/attributes` |
| `~/.config/gh/config.yml` | `dot_config/gh/private_config.yml` | S | `programs.gh.settings` (+ `gitCredentialHelper`) |
| `~/.gnupg/gpg.conf` | `private_dot_gnupg/gpg.conf` | S | `programs.gpg.settings` (`mkForce`, keyrings stay mutable) |
| `~/.tmux.conf` | `dot_tmux.conf` | S | `programs.tmux` → `~/.config/tmux/tmux.conf` |
| `~/.ssh/config` | `private_dot_ssh/encrypted_config.age` | E | `programs.ssh` writes `Include config.private`; the ciphertext decrypts to `~/.ssh/config.private` |
| `~/.ssh/sockets/` | `private_dot_ssh/private_sockets/.keep` | S | activation `mkdir` + `chmod 700` |
| `~/.config/ghostty/config.ghostty` | `dot_config/ghostty/config.ghostty` | S | `programs.ghostty.settings` → `~/.config/ghostty/config`, darwin only, `package = null` |
| `~/.config/ghostty/default.config` | same dir | S | `xdg.configFile`, darwin only |
| `~/.config/nvim/**` | `dot_config/exact_nvim/` | S | `xdg.configFile."nvim"` with `recursive = true` (dir stays writable for lazy.nvim) |
| `~/.config/halloy/config.toml`, `themes/catppucin light.toml` | `encrypted_*` | E | `thom.age.secrets` |
| `~/.config/senpai/senpai.scfg` | `encrypted_private_senpai.scfg.age` | E | `thom.age.secrets` |
| `~/.config/runitor/hc_key` | `encrypted_hc_key.age` | E | `thom.age.secrets` |
| `~/Library/Application Support/senpai/senpai.scfg` (darwin) | `symlink_senpai.scfg` | L | `mkOutOfStoreSymlink` |
| `~/.latexmkrc` | `dot_latexmkrc` | S | `home.file` |
| `~/.claude/CLAUDE.md`, `~/.claude/skills/using-ruff/SKILL.md` | `dot_claude/` | S | `home.file` |
| `~/.claude.json` | `modify_private_dot_claude.json.tmpl` | M | `home.activation.claudeSettings` (same jq merge) |
| `~/.claude/settings.json` | `dot_claude/modify_private_settings.json.tmpl` | M | same; container flag per role, `DARWIN_USER_TEMP_DIR` still resolved at activation |
| `~/.local/bin/devbox` (darwin) | `.chezmoiexternal.toml` | X | flake input `thom-container` |
| `~/.tmux/plugins/tpm` | `.chezmoiexternal.toml` (commented out) | X | dropped |
| — | `run_after_generate-ls-colors.sh` | R | `~/.cache/ls_colors` rendered at build time with vivid |
| — | `run_after_nvim_sync.sh` | R | `home.activation.nvimLazySync` |
| — | `run_onchange_after_setup-thom-container.sh.tmpl` | R | `home.activation.containerSystem` (darwin) |
| — | `run_onchange_before_install-packages-*.sh.tmpl` + `.chezmoidata.toml` | R | `home.packages` (`modules/packages.nix`); Homebrew dropped |
| — | `run_onchange_before_decrypt-private-key.sh.tmpl` | R | `bootstrap.sh` step 2 |

Template variables: `.chezmoi.os` → `pkgs.stdenv.hostPlatform.isDarwin`;
`.chezmoi.arch` (gh path) → `${pkgs.gh}`; `.chezmoi.osRelease.*` → gone (no
distro packages); `.claude.default_mode` → `thom.claude.defaultMode`;
`.packages.*` → `modules/packages.nix`; `.cpu.*` was unused and is dropped.

## Decisions

- **Secrets: age directly, not sops-nix/agenix.** The age identity is a
  post-quantum `mlkem768x25519` key (needs age ≥ 1.3; nixpkgs has 1.3.2).
  sops 3.13's support for it is unverified, and agenix's HM module decrypts
  through a systemd user service that nix-user-chroot and containers lack.
  `modules/secrets.nix` runs `age --decrypt` at activation into 0600 files.
  Ciphertext is in the Nix store; plaintext never is. The chezmoi ciphertexts
  are reused unchanged (same recipient), so **no re-encryption is needed**.
  New secret: `age -e -r <recipient> -a -o secrets/x.age`, then add an entry to
  `modules/secret-files.nix`. Identity moved to `~/.config/age/keys.txt`.
- **SSH:** everything in `programs.ssh` is world-readable in the store, so
  host blocks stay encrypted and are `Include`d. Move non-sensitive hosts into
  `programs.ssh.matchBlocks` when convenient.
- **Homebrew dropped** everywhere. Apple's `container` comes from nixpkgs.
  GUI apps (Ghostty) are installed outside Nix.
- **compinit** now rebuilds `.zcompdump` at most daily (`compinit -C`
  otherwise). It still runs last, as before. The module's slot (570) was
  tried and broke completion key bindings, because `key-bindings.zsh` runs
  `bindkey -e` afterwards.
- **tmux**: no plugins (all were commented out). Every option the module
  emits is pinned to tmux's built-in default, including `keyMode = "vi"`
  because tmux picks vi keys when `$EDITOR` contains "vi".
- **nix-user-chroot** (`thom@chroot`): HM's symlinks point into `/nix/store`,
  which only exists inside the chroot. `bootstrap.sh` installs a static
  nix-user-chroot (pinned 2.1.1, sha256-checked), puts single-user Nix in
  `~/.nix`, and appends a guarded block to `~/.bash_profile` that `exec`s
  `nix-user-chroot ~/.nix ~/.nix-profile/bin/zsh -l` for interactive logins.
  The host login shell must be bash. Non-interactive ssh commands run outside
  the chroot (`nix-user-chroot ~/.nix <cmd>` to get in).

## Verification

`./verify.sh [role]` builds the role and compares every chezmoi target on
the current machine. Run it on a Mac for `darwin`; this x86_64-linux box can
only *evaluate* the aarch64 roles, and `chezmoi cat` only renders for the
current OS.

Comparators: byte diff by default. Semantic comparison where a module
reformats:

| Target | Comparison |
|---|---|
| `.gitconfig` | sorted `git config --list` |
| `.tmux.conf` | `tmux show-options -g/-gw/-s` from a scratch server |
| `starship.toml` / `gh/config.yml` | parsed TOML / YAML |
| `gpg.conf` | option lines, comments stripped, sorted |
| `.zshrc` (+ `.zshenv`, `.zprofile`) | interactive login zsh in scratch HOMEs: `setopt`, `alias`, `bindkey`, `zstyle -L`, function names |
| `.claude.json`, `settings.json` | both jq merges applied to `{}` |
| encrypted | path only (never rendered) |

Known, explained differences (all deliberate):

1. `.config/git/config` vs `.gitconfig`: `core.excludesfile` and
   `core.attributesfile` are gone because git reads `~/.config/git/*` by
   default. The gh helper is a store path, not `gh`/`/opt/homebrew/bin/gh`.
   `off` is now `false`.
2. tmux: `set-environment PATH` swaps `/opt/homebrew/bin` for the Nix
   profile. Excluded from the comparator, along with session-specific
   `default-shell`/`default-command`/`update-environment`.
3. zsh: `HIST_FCNTL_LOCK` is added by the history module. zsh-defer and
   zsh-syntax-highlighting come from store paths. `zsh-completions` is now
   actually on `fpath`; brew installed it but never added it. Homebrew
   `PATH`/`fpath` tweaks are removed (gnu-tar, python libexec, rustup,
   site-functions); Nix's `gnutar` and `python3` (which ships `python`)
   cover the first two.
4. gh: blank `editor`/`pager`/`browser`/`http_unix_socket` are left unset;
   comments are lost.
5. Claude `settings.json`: the sandbox credential deny path is now
   `~/.config/age/keys.txt` (was `~/.config/chezmoi/key.txt`), and
   `~/.config/git` is readable. `allowRead/allowWrite` still name
   `~/.local/share/chezmoi` (`thom.claude.dotfilesDir`). Change it if the repo
   moves.
6. Ghostty: config only on darwin (no Linux desktops). The file is
   `~/.config/ghostty/config`, not `config.ghostty`.
7. devbox only updates on `nix flake update thom-container`, not every minute.
8. zsh-defer files are no longer copied into `~/.zsh/zsh-defer`.
9. `~/.ssh/config` is generated; the encrypted content is
   `~/.ssh/config.private`.

## Risks / unverified

- **Nothing has been activated.** No `home-manager switch` was run, and the
  secrets path was never exercised with the real key (deliberately not
  decrypted). The first switch is the real test of `decryptSecrets`.
- **darwin and aarch64-linux are evaluated only, not built.** Spot-checked
  values: `gls` alias, Docker PATH, SSH SK provider, Ghostty, devbox, senpai
  symlink, `container`/`gsed`/`gnutar`. Run `./verify.sh` on a Mac.
- **Apple `container` from nixpkgs** (1.5.0): unknown whether
  `container system start` works from a store path rather than the official
  `.pkg` install. Fallback: install the `.pkg` and drop it from
  `modules/packages.nix` (the activation step finds it on PATH then; adjust
  `containerSystem` accordingly).
- **`bootstrap.sh`** passes shellcheck and nix-user-chroot was confirmed to
  work on this box. The full Nix install inside it and the switch were not
  run.
- `gh config set …` and `gpg`'s own config edits now fail (read-only store
  files). Change those through Nix instead.

## Cut-over (manual)

On each existing chezmoi machine:

1. `git -C ~/.local/share/chezmoi switch hm-migration` (or merge it first).
2. `~/.local/share/chezmoi/bootstrap.sh <role>`. This reuses
   `~/.config/chezmoi/key.txt` as `~/.config/age/keys.txt`, installs Nix if
   needed, and runs `home-manager switch -b hm-bak`. Files chezmoi wrote that
   HM now owns are kept as `*.hm-bak`. `activation.retireChezmoiFiles` moves
   `~/.gitconfig`, `~/.tmux.conf` and `~/.config/ghostty/config.ghostty`
   aside (they would shadow or duplicate the new config).
3. Check a new shell, `git config -l --show-origin`, `ssh -G <host>`, tmux.
4. `chezmoi purge` (removes chezmoi's config/state/cache and source dir).
   **Move the repo out of `~/.local/share/chezmoi` first** if you want to keep
   the checkout, and update `thom.claude.dotfilesDir`. Afterwards delete the
   leftovers HM doesn't manage: `~/.gitignore`, `~/.gitattributes`,
   `~/.zsh/zsh-defer/`, `~/.config/chezmoi/` (after confirming
   `~/.config/age/keys.txt`).
5. Brew: `brew bundle dump` to check for anything not in
   `modules/packages.nix`, then uninstall Homebrew if desired.
6. Optionally make Nix's zsh the login shell (`/etc/shells` + `chsh`).

Fresh machines: clone the repo anywhere, run `./bootstrap.sh [role]`.

Once every machine is switched, the chezmoi sources (`dot_*`, `private_*`,
`exact_*`, `run_*`, `modify_*`, `.chezmoi*`, `key.txt.age` excepted) can be
deleted. Not done here; that's your call.
