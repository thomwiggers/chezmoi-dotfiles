#!/usr/bin/env bash
# Set up a machine from scratch: install Nix, put the age identity in place
# and activate the Home Manager configuration from this repository.
#
#   ./bootstrap.sh [role]
#
# Roles (see flake.nix): darwin, linux, linux-arm, chroot. Default: darwin on
# macOS, linux/linux-arm by architecture on Linux. Use `chroot` on Linux hosts
# without root: Nix then lives in ~/.nix and runs inside nix-user-chroot.
#
# Safe to re-run; every step is skipped when already done. Written for the
# bash 3.2 that ships with macOS.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)

NIX_USER_CHROOT_VERSION=2.1.1
nix_user_chroot_sha256() {
	case "$1" in
	x86_64) echo e6daa6a036e00b939531e5c11e6dcd891140813a09964fd12a64112de500fc15 ;;
	aarch64) echo 9aeaa70f4fb645afb343b0417e494b0271457a8cb465c4ac82b6c3b19040d397 ;;
	esac
}
nix_user_chroot="$HOME/.local/bin/nix-user-chroot"
age_identity="${XDG_CONFIG_HOME:-$HOME/.config}/age/keys.txt"

say() { printf '\033[1m==> %s\033[0m\n' "$*" >&2; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required${2:+ ($2)}"; }

os=$(uname -s)
arch=$(uname -m)
case "$os/$arch" in
Darwin/arm64) default_role=darwin ;;
Linux/x86_64) default_role=linux ;;
Linux/aarch64) default_role=linux-arm ;;
*) die "unsupported platform $os/$arch" ;;
esac
role=${1:-$default_role}
case "$role" in
darwin | linux | linux-arm | chroot) ;;
*) die "unknown role '$role' (darwin, linux, linux-arm, chroot)" ;;
esac
[[ $role == chroot && $os != Linux ]] && die "the chroot role is Linux-only"

need curl
[[ $os == Linux ]] && need xz "the Nix installer tarball is xz-compressed"

# Run a command with Nix available: directly, or inside nix-user-chroot.
in_nix() {
	if [[ $role == chroot ]]; then
		# shellcheck disable=SC2016 # expanded by the inner bash
		"$nix_user_chroot" "$HOME/.nix" bash -c '. "$HOME/.nix-profile/etc/profile.d/nix.sh" && exec "$@"' bash "$@"
	else
		"$@"
	fi
}

export NIX_CONFIG="experimental-features = nix-command flakes"

# --- 1. Nix -------------------------------------------------------------------

install_nix_rootless() {
	if [[ ! -x $nix_user_chroot ]]; then
		say "Installing nix-user-chroot $NIX_USER_CHROOT_VERSION"
		local url tmp
		url="https://github.com/nix-community/nix-user-chroot/releases/download/$NIX_USER_CHROOT_VERSION/nix-user-chroot-bin-$NIX_USER_CHROOT_VERSION-$arch-unknown-linux-musl"
		mkdir -p "$(dirname "$nix_user_chroot")"
		tmp=$(mktemp "$nix_user_chroot.XXXXXX")
		curl -fsSL -o "$tmp" "$url"
		echo "$(nix_user_chroot_sha256 "$arch")  $tmp" | sha256sum -c --quiet - ||
			die "checksum mismatch for $url"
		chmod 755 "$tmp"
		mv "$tmp" "$nix_user_chroot"
	fi

	"$nix_user_chroot" "$HOME/.nix" true 2>/dev/null ||
		die "nix-user-chroot can't create a user namespace here (kernel.unprivileged_userns_clone / user.max_user_namespaces?)"

	if [[ ! -e $HOME/.nix-profile/etc/profile.d/nix.sh ]]; then
		say "Installing single-user Nix into ~/.nix (inside nix-user-chroot)"
		[[ -d $HOME/.nix ]] || mkdir -m 0755 "$HOME/.nix"
		"$nix_user_chroot" "$HOME/.nix" bash -c \
			'curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --no-modify-profile'
	fi
}

install_nix_rooted() {
	if command -v nix >/dev/null 2>&1 || [[ -e /nix/var/nix/profiles/default/bin/nix ]]; then
		return
	fi
	if [[ $os == Darwin || -d /run/systemd/system ]]; then
		say "Installing multi-user Nix (needs sudo)"
		sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
	else
		# Containers without systemd can't run nix-daemon.
		say "Installing single-user Nix into /nix (needs sudo once for /nix)"
		sudo install -d -m 0755 -o "$(id -u)" -g "$(id -g)" /nix
		sh <(curl -fsSL https://nixos.org/nix/install) --no-daemon
	fi
}

if [[ $role == chroot ]]; then
	install_nix_rootless
else
	install_nix_rooted
	for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
		# shellcheck disable=SC1090
		[[ -e $f ]] && . "$f" && break
	done
	need nix
fi

# --- 2. age identity ------------------------------------------------------------

if [[ ! -s $age_identity ]]; then
	(
		umask 077
		mkdir -p "$(dirname "$age_identity")"
		if [[ -s $HOME/.config/chezmoi/key.txt ]]; then
			say "Reusing the age identity chezmoi decrypted"
			cp "$HOME/.config/chezmoi/key.txt" "$age_identity"
		else
			say "Decrypting the age identity (enter its passphrase)"
			in_nix nix run --inputs-from "$repo" nixpkgs#age -- \
				--decrypt --output "$age_identity" "$repo/key.txt.age"
		fi
	)
	chmod 600 "$age_identity"
fi

# --- 3. Home Manager ------------------------------------------------------------

say "Activating thom@$role"
# -b: files Home Manager would overwrite (e.g. chezmoi-written dotfiles) are
# kept as <file>.hm-bak.
in_nix nix run "$repo#home-manager" -- switch -b hm-bak --flake "$repo#thom@$role"

# --- 4. Entering the chroot -------------------------------------------------------

if [[ $role == chroot ]]; then
	# Everything Home Manager links points into /nix/store, which only exists
	# inside the chroot. The host's login shell (bash) hands interactive
	# sessions over to the Nix zsh inside nix-user-chroot.
	marker="# nix-user-chroot (dotfiles bootstrap.sh)"
	if ! grep -qF "$marker" "$HOME/.bash_profile" 2>/dev/null; then
		say "Adding the nix-user-chroot hand-off to ~/.bash_profile"
		cat >>"$HOME/.bash_profile" <<EOF

$marker
if [ -z "\${NIX_USER_CHROOT:-}" ] && [ -x "$nix_user_chroot" ] && [[ \$- == *i* ]]; then
    export NIX_USER_CHROOT=1
    exec "$nix_user_chroot" "\$HOME/.nix" "\$HOME/.nix-profile/bin/zsh" -l
fi
EOF
	fi
	case "${SHELL##*/}" in
	bash) ;;
	*) say "Your login shell is $SHELL; switch it to bash (chsh -s /bin/bash) so ~/.bash_profile can enter the chroot" ;;
	esac
	say "Done. Log in again, or run: $nix_user_chroot ~/.nix ~/.nix-profile/bin/zsh -l"
else
	say "Done. Open a new shell. To make Nix's zsh the login shell, add $HOME/.nix-profile/bin/zsh to /etc/shells and chsh to it."
fi
