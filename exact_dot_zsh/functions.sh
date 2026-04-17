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
