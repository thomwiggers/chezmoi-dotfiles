#!/bin/sh
# Sync lazy.nvim plugins quietly; show the output only if something went wrong.
if type nvim >/dev/null; then
  log="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-lazy-sync.log"
  mkdir -p "$(dirname "$log")"
  # Skip checkout lines: their commit subjects can mention "error".
  if ! nvim --headless "+Lazy! sync" +qa >"$log" 2>&1 ||
    grep -v 'HEAD is now at' "$log" | grep -qiE 'error|failed'; then
    cat "$log" >&2
    echo "nvim plugin sync had problems; log in $log" >&2
  fi
fi
