# Shared by the run_onchange_before_install-packages-* scripts. Callers install
# the platform build prerequisites first, and run under `set -euo pipefail`.

formulae=(
{{ range .packages.brew }}  "{{ . }}"
{{ end }}{{- if eq .chezmoi.os "darwin" }}{{ range .packages.brew_darwin_extra }}  "{{ . }}"
{{ end }}{{- end }})

{{ template "brew-shellenv.sh" . }}
if ! command -v brew >/dev/null 2>&1; then
    for attempt in 1 2 3; do
        if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            break
        fi
        echo "homebrew installer failed (attempt ${attempt}/3); retrying in $((attempt * 15))s" >&2
        sleep $((attempt * 15))
    done
{{ template "brew-shellenv.sh" . }}
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "brew is still not on PATH after installation; cannot install packages" >&2
    exit 1
fi

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# `brew bundle` defaults to HOMEBREW_BUNDLE_JOBS=auto (up to 4 parallel
# installs). Workers that share a dependency race on the download cache lock:
#   Error: A `brew install --formula bat` process has already locked
#   .../libcap-2.78.bottle_manifest.json.incomplete
# Sequential installs are slower but actually finish.
export HOMEBREW_BUNDLE_NO_JOBS=1

if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" != "x86_64" ]; then
    echo "note: Homebrew ships no bottles for $(uname -m) Linux, so every formula" >&2
    echo "      is built from source; expect this to take a long while" >&2
fi

# Write a real Brewfile: `--file=/dev/stdin` breaks whenever brew re-execs and
# loses the heredoc.
brewfile=$(mktemp)
trap 'rm -f "$brewfile"' EXIT
printf 'brew "%s"\n' "${formulae[@]}" >"$brewfile"

if ! brew bundle install --file="$brewfile"; then
    echo "brew bundle failed; refreshing homebrew and retrying" >&2
    brew update --force --quiet || true

    if ! brew bundle install --file="$brewfile"; then
        # bundle is all-or-nothing, so one bad formula takes down the whole
        # chezmoi apply. Install what we can and report the rest.
        echo "brew bundle failed again; falling back to per-formula install" >&2
        failed=()
        for formula in "${formulae[@]}"; do
            if brew list --formula --versions "$formula" >/dev/null 2>&1; then
                continue
            fi
            brew install --formula "$formula" || failed+=("$formula")
        done
        if [ ${#failed[@]} -gt 0 ]; then
            echo "WARNING: could not install: ${failed[*]}" >&2
            echo "WARNING: retry later with: chezmoi apply --force" >&2
        fi
    fi
fi
