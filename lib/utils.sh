#!/bin/bash
# utils.sh — Shared helpers for bench_ram.

# Check if a command exists. Print skip message if not.
# Usage: check_cmd <command> <lang_display_name>
# Returns 0 if available, 1 if not.
check_cmd() {
    local cmd="$1" lang="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf "%-12s | [Ignoré : '%s' non installé]\n" "$lang" "$cmd"
        return 1
    fi
    return 0
}

# Compute median of a list of integers.
# Usage: median <val1> <val2> ... <valN>
median() {
    local sorted
    mapfile -t sorted < <(printf '%s\n' "$@" | sort -n)
    local n=${#sorted[@]}
    echo "${sorted[$((n / 2))]}"
}

# Format kB value for display (right-aligned with unit).
fmt_kb() {
    local val="$1"
    if [[ "$val" == "0" || -z "$val" ]]; then
        echo "N/A"
    else
        echo "${val} kB"
    fi
}
