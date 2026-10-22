#!/usr/bin/env bash
# Set up a machine from scratch: install Nix, put the age identity in place
# and activate the Home Manager configuration from this repository.
#
#   ./bootstrap.sh [role]
#   curl -fsSL https://raw.githubusercontent.com/thomwiggers/home-manager-config/main/bootstrap.sh | sh [-s -- role]
#
# Roles (see flake.nix): darwin, linux, linux-arm, chroot. Default: the role
# this machine was registered with (machines/<hostname>), else darwin on
# macOS and linux/linux-arm by architecture on Linux. Use `chroot` on Linux
# hosts without root: Nix then lives in ~/.nix and runs inside
# nix-user-chroot.
#
# Run from any checkout, it clones the repository to ~/.config/home-manager
# (where home-manager looks for its flake) and continues from there. At the
# end it registers the machine, so a plain `home-manager switch` works.
#
# Safe to re-run; every step is skipped when already done. Written for the
# bash 3.2 that ships with macOS.

# Piped into a shell there is no checkout, stdin is the script and `sh` may
# be dash: clone the repository and run its copy under bash, with the
# terminal as stdin for the passphrase and sudo prompts. POSIX sh up to the
# exec; the function means a truncated download runs nothing.
bootstrap_from_pipe() {
	dir="${XDG_CONFIG_HOME:-$HOME/.config}/home-manager"
	if [ ! -e "$dir" ]; then
		command -v git >/dev/null 2>&1 || {
			echo "error: git is required" >&2
			exit 1
		}
		printf '\033[1m==> %s\033[0m\n' "Cloning the repository into $dir" >&2
		git clone -q https://github.com/thomwiggers/home-manager-config.git "$dir" || exit 1
	fi
	[ -f "$dir/bootstrap.sh" ] || {
		echo "error: $dir exists but isn't a checkout of this repository; move it aside" >&2
		exit 1
	}
	if (exec </dev/tty) 2>/dev/null; then
		exec bash "$dir/bootstrap.sh" "$@" </dev/tty
	fi
	exec bash "$dir/bootstrap.sh" "$@" </dev/null
}
case ${0##*/} in
bootstrap.sh) ;;
*) bootstrap_from_pipe "$@" ;;
esac

set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd -P)
hm_dir="${XDG_CONFIG_HOME:-$HOME/.config}/home-manager"
default_url=https://github.com/thomwiggers/home-manager-config.git
host=$(hostname -s)

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
if [[ -s $repo/machines/$host ]]; then
	default_role=$(cat "$repo/machines/$host")
fi
role=${1:-$default_role}
case "$role" in
darwin | linux | linux-arm | chroot) ;;
*) die "unknown role '$role' (darwin, linux, linux-arm, chroot)" ;;
esac
[[ $role == chroot && $os != Linux ]] && die "the chroot role is Linux-only"

# Configurations exist per account (`users` in flake.nix) with a fixed home
# directory; Home Manager refuses to activate for anything else.
user=$(id -un)
case "$user" in
thom | thomwiggers) ;;
*) die "no configuration for user $user; add it to \`users\` in flake.nix" ;;
esac
want_home=/home/$user
[[ $os == Darwin ]] && want_home=/Users/$user
[[ $HOME == "$want_home" ]] ||
	die "configurations assume HOME=$want_home (got $HOME); adjust mkHome in flake.nix"

need curl
[[ $os == Linux ]] && need xz "the Nix installer tarball is xz-compressed"

# --- 0. Repository location -------------------------------------------------------

# home-manager finds its flake in ~/.config/home-manager by default. Clone
# from this checkout (keeping any local commits) and point origin at the
# remote this checkout uses.
if [[ $repo != "$(cd "$hm_dir" 2>/dev/null && pwd -P)" ]]; then
	if [[ ! -e $hm_dir ]]; then
		need git
		url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "$default_url")
		say "Cloning this repository into $hm_dir"
		git clone -q "$repo" "$hm_dir"
		git -C "$hm_dir" remote set-url origin "$url"
	elif [[ ! -e $hm_dir/flake.nix || ! -e $hm_dir/.git ]]; then
		die "$hm_dir exists but isn't a checkout of this repository; move it aside"
	fi
	say "Continuing from $hm_dir"
	exec "$hm_dir/bootstrap.sh" "$@"
fi

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

	[[ -d $HOME/.nix ]] || mkdir -m 0755 "$HOME/.nix"
	"$nix_user_chroot" "$HOME/.nix" true ||
		die "nix-user-chroot can't set up its namespace here (see the error above; user namespaces disabled, or blocked by AppArmor/seccomp in a container?)"

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

say "Activating $user@$role"
# -b: files Home Manager would overwrite (e.g. chezmoi-written dotfiles) are
# kept as <file>.hm-bak.
in_nix nix run "$repo#home-manager" -- switch -b hm-bak --flake "$repo#$user@$role"

# --- 4. Register this machine ---------------------------------------------------

# Lets a plain `home-manager switch` find <user>@<hostname>. Committed after
# the switch, when Home Manager has configured git's identity.
if [[ $(cat "$repo/machines/$host" 2>/dev/null) != "$role" ]]; then
	say "Registering $host as $role (machines/$host)"
	mkdir -p "$repo/machines"
	echo "$role" >"$repo/machines/$host"
	if in_nix git -C "$repo" add "machines/$host" &&
		in_nix git -C "$repo" commit -q -m "Register $host as $role" -- "machines/$host"; then
		say "Committed; push it with: git -C $repo push"
	else
		say "Couldn't commit machines/$host; commit and push it yourself"
	fi
fi

# --- 5. Login shell -------------------------------------------------------------

zsh_path="$HOME/.nix-profile/bin/zsh"

login_shell() {
	if [[ $os == Darwin ]]; then
		dscl . -read "/Users/$user" UserShell | awk '{print $2}'
	else
		getent passwd "$user" | cut -d: -f7
	fi
}

if [[ $role == chroot ]]; then
	# Everything Home Manager links points into /nix/store, which only exists
	# inside the chroot. The host's login shell (bash) hands interactive
	# sessions over to the Nix zsh inside nix-user-chroot.
	marker="# nix-user-chroot (dotfiles bootstrap.sh)"
	if ! grep -qF "$marker" "$HOME/.bash_profile" 2>/dev/null; then
		say "Adding the nix-user-chroot hand-off to ~/.bash_profile"
		if [[ ! -e $HOME/.bash_profile ]]; then
			# A new ~/.bash_profile stops bash from reading ~/.profile.
			echo '[ -f ~/.profile ] && . ~/.profile' >"$HOME/.bash_profile"
		fi
		cat >>"$HOME/.bash_profile" <<EOF

$marker
if [ -z "\${NIX_USER_CHROOT:-}" ] && [ -x "$nix_user_chroot" ] && [[ \$- == *i* ]]; then
    export NIX_USER_CHROOT=1 SHELL="\$HOME/.nix-profile/bin/zsh"
    exec "$nix_user_chroot" "\$HOME/.nix" "\$SHELL" -l
fi
EOF
	fi
	case "$(login_shell)" in
	*/bash) ;;
	*) say "Your login shell is $(login_shell); switch it to bash (chsh -s /bin/bash) so ~/.bash_profile can enter the chroot" ;;
	esac
	enter=("$nix_user_chroot" "$HOME/.nix" "$zsh_path" -l)
	export NIX_USER_CHROOT=1
else
	# Any zsh will do: Home Manager's ~/.zshenv and ~/.zprofile put Nix on
	# PATH even for the system zsh (macOS's default /bin/zsh). Anything else
	# (bash on fresh Linux hosts) is switched to the profile's zsh.
	current=$(login_shell)
	if [[ ${current##*/} != zsh ]]; then
		say "Changing the login shell from $current to $zsh_path (needs sudo)"
		if { grep -qxF "$zsh_path" /etc/shells ||
			echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; } &&
			sudo chsh -s "$zsh_path" "$user"; then
			:
		else
			say "Couldn't change the login shell; do it by hand: add $zsh_path to /etc/shells, then chsh -s $zsh_path"
		fi
	fi
	enter=("$zsh_path" -l)
fi
export SHELL="$zsh_path"

if [[ -t 0 && -t 1 ]]; then
	say "Done. Starting a login shell with the new configuration"
	unset NIX_CONFIG
	exec "${enter[@]}"
fi
say "Done. Log in again (or run: ${enter[*]})"
