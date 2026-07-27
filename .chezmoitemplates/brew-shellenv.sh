# Shared by scripts that need `brew`-installed tools (jq, etc.) on PATH.
# Each chezmoi script/modify_ hook runs as its own subprocess, so a PATH
# update from a sibling script (e.g. the run_onchange_before_install-packages
# scripts installing Homebrew) never reaches us — locate it ourselves.
if ! command -v brew >/dev/null 2>&1; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew \
                     /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        if [ -x "$candidate" ]; then
            eval "$("$candidate" shellenv)"
            break
        fi
    done
fi
