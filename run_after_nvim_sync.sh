#!/bin/sh
if type nvim >/dev/null; then
  nvim --headless "+Lazy! sync" +qa
fi
