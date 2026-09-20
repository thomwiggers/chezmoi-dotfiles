# package <input>...           — compress, auto-name from first input
# package -o <output> <input...>
package() {
    local output
    local -a inputs

    if [[ $1 == -o ]]; then
        output=$2
        shift 2
    fi

    if [[ $# -eq 0 ]]; then
        print "Usage: package [-o <output>] <input>..." >&2
        return 1
    fi

    inputs=("$@")
    if [[ -z $output ]]; then
        local base=${1%/}
        output="${base:t}.tar.zst"
    fi

    tar --use-compress-program='zstd -T0' -cf "$output" "${inputs[@]}"
}

# Restore terminal modes that a remote tmux/Claude Code left enabled when an
# ssh session dies uncleanly (e.g. ServerAlive timeout). On a clean detach the
# remote tmux client resets the terminal itself; on a timeout those bytes never
# arrive, leaving mouse reporting on so scrolling types garbage into the shell.
ssh() {
    command ssh "$@"
    local rc=$?
    if [[ -t 1 ]]; then
        # mouse (1000/1002/1003, SGR 1006), focus (1004), bracketed paste (2004),
        # show cursor, pop kitty keyboard protocol flags
        printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?2004l\e[?25h\e[<u'
        stty sane
    fi
    return $rc
}
