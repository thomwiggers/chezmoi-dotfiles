# chezmoi → Home Manager migration

Status: the chezmoi sources and `verify.sh` have been deleted; only the
cut-over path for machines still on chezmoi remains. Last parity result
before deletion: `ok=38 explained=13 mismatch=0` (`linux`, `chroot`). The
old sources and script are in the repository history (before the commit
that removed them).

## Layout

| Path | What |
|---|---|
| `flake.nix` | nixpkgs (unstable) + home-manager (follows nixpkgs) + `thom-container` (devbox). `homeConfigurations."<user>@<role>"` for `thom` and `thomwiggers`, `checks`, `packages.home-manager` (pinned CLI) |
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

## Roles

Nothing in the chezmoi setup keyed on hostname; the real axes were OS, arch
and "inside a container". Configurations are therefore per role:

| Config | System | `thom.container` | Notes |
|---|---|---|---|
| `<user>@darwin` | aarch64-darwin | false | Macs |
| `<user>@linux` | x86_64-linux | true | e.g. `development` (Incus/LXC) |
| `<user>@linux-arm` | aarch64-linux | true | devbox under Apple's container |
| `<user>@chroot` | x86_64-linux | false | no root; Nix in `~/.nix` via nix-user-chroot |

`thom.container` replaces chezmoi's runtime detection (`$container`,
`/.dockerenv`, `/run/.containerenv`, `/run/systemd/container`) and only feeds
Claude Code's `sandbox.enableWeakerNestedSandbox`. Add a role (or override in a
host file) if a machine doesn't fit.

## Decisions

- **Secrets: age directly, not sops-nix/agenix.** The age identity is a
  post-quantum `mlkem768x25519` key (needs age ≥ 1.3; nixpkgs has 1.3.2).
  sops 3.13's support for it is unverified, and agenix's HM module decrypts
  through a systemd user service that nix-user-chroot and containers lack.
  `modules/secrets.nix` runs `age --decrypt` at activation into 0600 files.
  Ciphertext is in the Nix store; plaintext never is. The chezmoi ciphertexts
  are reused unchanged (same recipient), so **no re-encryption is needed**,
  except the SSH host blocks (see below).
  New secret: `age -e -r <recipient> -a -o secrets/x.age`, then add an entry to
  `modules/secret-files.nix`. Identity moved to `~/.config/age/keys.txt`.
- **SSH:** split. The repo is public and the store world-readable, so only
  the generic part is native (`programs.ssh`: canonicalisation,
  `HashKnownHosts`, `Host *`, `github.com`, the `*.incus`/`*.ts.net` block).
  Host blocks with addresses, ports and users (pqsh bastion/gitlab, cocytus,
  eprint) are re-encrypted alone in `secrets/ssh_config_private.age` and
  `Include`d. `ssh -G` for every host, with canonicalisation on and off,
  matched the original config exactly, except for one deliberate fix: the
  old `Host github.com` block came after `Host *` and so never took effect
  (ssh takes the first value). It now comes first, so GitHub connections
  are no longer multiplexed or kept open. The chezmoi copy still has the old
  order.
- **Homebrew no longer manages packages**; they come from Nix. Apple's
  `container` comes from nixpkgs. GUI apps (Ghostty) are installed outside
  Nix. On macOS Homebrew stays usable: `/opt/homebrew/bin` and `sbin` are
  appended to PATH (after Nix, so Nix's tools win), its `site-functions`
  are appended to `fpath`, and `HOMEBREW_NO_ENV_HINTS`/`HOMEBREW_BAT` are
  still set. Nothing installs or updates Homebrew any more.
- **compinit** now does its full check (including the `compaudit` security
  scan) when `~/.zcompdump` is missing or over a day old, and `compinit -C`
  otherwise; the dump's mtime is bumped after a full run. It still runs last, as before. The module's slot (570) was
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

## Risks / unverified

- **Accounts**: every role exists for `thom` and `thomwiggers`
  (`users` in `flake.nix`), with home `/home/<user>` or `/Users/<user>`.
  Home Manager refuses to activate otherwise; `bootstrap.sh` picks
  `$(id -un)@<role>` and checks this up front. A host with a non-standard
  home directory needs a tweak to `mkHome`.
- **Nix inside Claude Code's sandbox** (also changed in the chezmoi
  template): the nix-daemon socket is allowed (only that path on macOS; on
  Linux the seccomp filter is all-or-nothing, so `allowAllUnixSockets`
  opens every Unix socket, e.g. a Docker socket if present), plus writes to
  `~/.cache/nix` and `/nix` (effective only for single-user installs). Not
  yet exercised: fetching through the sandbox's TLS-terminating proxy may
  need its CA in `NIX_SSL_CERT_FILE`.
- **Nothing has been activated.** No `home-manager switch` was run, and the
  secrets path was never exercised with the real key (deliberately not
  decrypted). The first switch is the real test of `decryptSecrets`.
- **darwin and aarch64-linux are evaluated only, not built.** Spot-checked
  values: `gls` alias, Docker PATH, SSH SK provider, Ghostty, devbox, senpai
  symlink, `container`/`gsed`/`gnutar`..
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

## Open: provisioning without secrets (cloud-init)

chezmoi supports unattended, secret-less provisioning via
`chezmoi init --apply --exclude encrypted`
(`run_onchange_before_decrypt-private-key.sh.tmpl` checks for it). The Nix
setup has no equivalent yet:

- `home-manager switch` itself already copes: with no
  `~/.config/age/keys.txt`, `decryptSecrets` warns and skips, and ssh ignores
  the missing `Include config.private`.
- `bootstrap.sh` does not: with no chezmoi key it prompts for the
  `key.txt.age` passphrase, which blocks cloud-init.

To do: a non-interactive no-secrets mode for `bootstrap.sh` (e.g.
`--no-secrets` / `THOM_NO_SECRETS=1`) that skips the identity step, and
optionally a `thom.age.enable` option so such hosts don't even warn. Also
check that bootstrap works as a cloud-init `runcmd` (non-login shell, run as
the target user via `su -l`, no TTY for `sudo`).

## Cut-over (manual)

On each existing chezmoi machine:

1. `git -C ~/.local/share/chezmoi pull`.
2. `~/.local/share/chezmoi/bootstrap.sh [role]` (the role defaults to
   darwin/linux/linux-arm by platform; `chroot` must be given). It first
   clones the repo to `~/.config/home-manager`, where `home-manager` looks
   for its flake, and continues from that checkout. This reuses
   `~/.config/chezmoi/key.txt` as `~/.config/age/keys.txt`, installs Nix if
   needed, and runs `home-manager switch -b hm-bak`. Files chezmoi wrote that
   HM now owns are kept as `*.hm-bak`. `activation.retireChezmoiFiles` moves
   `~/.gitconfig`, `~/.tmux.conf` and `~/.config/ghostty/config.ghostty`
   aside (they would shadow or duplicate the new config). If the login
   shell isn't a zsh (bash on fresh Linux hosts), it is changed to
   `~/.nix-profile/bin/zsh` via `sudo` (`/etc/shells` + `chsh`); an existing
   zsh, e.g. macOS's `/bin/zsh`, is kept, since HM's `~/.zshenv`/`~/.zprofile`
   put Nix on PATH for it too. It registers the machine as
   `machines/<hostname -s>` (containing the role) and commits that file, so
   plain `home-manager switch` / `home-manager news` find
   `<user>@<hostname>`; push the commit. Run from a terminal, bootstrap then
   `exec`s a login zsh, so the new setup is live immediately.
3. Check a new shell, `git config -l --show-origin`, `ssh -G <host>`, tmux.
4. `chezmoi purge` (removes chezmoi's config/state/cache and the old
   `~/.local/share/chezmoi` checkout; push anything committed there first).
   Afterwards delete the
   leftovers HM doesn't manage: `~/.gitignore`, `~/.gitattributes`,
   `~/.zsh/zsh-defer/`, `~/.config/chezmoi/` (after confirming
   `~/.config/age/keys.txt`).
5. Brew: `brew bundle dump` to check for anything not in
   `modules/packages.nix`. Formulae duplicated in Nix can be uninstalled;
   Homebrew itself stays on PATH (after Nix).

Fresh machines: clone the repo anywhere and run `./bootstrap.sh [role]`;
it moves itself to `~/.config/home-manager`. Afterwards, update with
`git -C ~/.config/home-manager pull && home-manager switch`. Machines that
aren't registered (or whose hostname changed) need
`home-manager switch --flake '~/.config/home-manager#<user>@<role>'`;
re-running `bootstrap.sh` registers them.

Once every machine is switched, `key.txt.age` and the `~/.config/chezmoi/key.txt`
reuse in `bootstrap.sh` step 2 can go too (and the `retireChezmoiFiles`
activation in `modules/scripts.nix`), along with this file.
