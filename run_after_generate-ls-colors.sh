#!/bin/sh
if command -v vivid > /dev/null 2>&1; then
    mkdir -p ~/.cache
    vivid generate molokai > ~/.cache/ls_colors
fi
