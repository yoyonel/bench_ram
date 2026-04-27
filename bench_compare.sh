#!/bin/bash
# Do NOT use set -e: we intentionally kill processes.
set -uo pipefail

# ============================================================
# bench_compare.sh — Compare RAM across compilation profiles:
#   debug (-O0), release (-O2), release+static, release+stripped
# Only applies to compiled languages (C, C++, Rust, Go, Zig, Nim, V).
# Interpreted languages are shown once (no compile flags apply).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/tmp/ram_bench_workspace"
N_RUNS="${BENCH_RUNS:-3}"

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/measure.sh"

# Parse arguments
while getopts "n:" opt; do
    case $opt in
        n) N_RUNS="$OPTARG" ;;
        *)
            echo "Usage: $0 [-n runs]"
            exit 1
            ;;
    esac
done

# Profiles for compiled languages
declare -A PROFILES=(
    ["debug"]="-O0 -g"
    ["release"]="-O2"
    ["static"]="-O2 -static"
    ["stripped"]="-O2 -s"
)

# Rust has different flags
declare -A RUST_PROFILES=(
    ["debug"]="-C opt-level=0 -g"
    ["release"]="-C opt-level=2"
    ["static"]="-C opt-level=2 -C target-feature=+crt-static"
    ["stripped"]="-C opt-level=2 -C strip=symbols"
)

# Languages where compile flags apply
COMPILED_LANGS="c cpp rust go zig nim v"

# Check if a lang file is compiled
is_compiled() {
    local name="$1"
    [[ " $COMPILED_LANGS " == *" $name "* ]]
}

get_flags_for_lang() {
    local lang_basename="$1" profile="$2"
    if [[ "$lang_basename" == "rust" ]]; then
        echo "${RUST_PROFILES[$profile]}"
    elif [[ "$lang_basename" == "go" ]]; then
        # Go doesn't use gcc flags; build flags are fixed
        echo ""
    else
        echo "${PROFILES[$profile]}"
    fi
}

# Setup workspace
rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"

echo "========================================================================"
echo "  BENCHMARK COMPARATIF: debug vs release vs static vs stripped"
echo "  Runs per profile: $N_RUNS | Métrique: RssAnon (kB)"
echo "========================================================================"
echo ""

# Header
printf "%-12s | %10s | %10s | %10s | %10s\n" "Langage" "debug" "release" "static" "stripped"
echo "------------------------------------------------------------------------"

# Process each language
for lang_file in "$SCRIPT_DIR"/langs/*.sh; do
    [[ -d "$lang_file" ]] && continue # skip startup/ directory

    local_name=$(basename "$lang_file" .sh)

    # Reset
    unset -f lang_prepare lang_write_runner lang_run
    lang_name="" lang_cmd=""
    source "$lang_file"

    if ! check_cmd "$lang_cmd" "$lang_name" 2>/dev/null; then
        continue
    fi

    if is_compiled "$local_name"; then
        declare -A profile_results=()
        for profile in debug release static stripped; do
            rm -f "$WORKSPACE/run.sh"
            flags=$(get_flags_for_lang "$local_name" "$profile")

            # Re-source to reset functions
            unset -f lang_prepare lang_write_runner
            source "$lang_file"

            if [[ -n "$flags" ]]; then
                lang_prepare "$WORKSPACE" "$flags" 2>/dev/null
            else
                lang_prepare "$WORKSPACE" 2>/dev/null
            fi

            # Check if compilation succeeded
            lang_write_runner "$WORKSPACE"
            chmod +x "$WORKSPACE/run.sh"

            result=$(run_benchmark "$lang_name" "$N_RUNS" "$WORKSPACE/run.sh" 2>/dev/null)
            read -r _vs _vr ra <<<"$result"
            profile_results[$profile]="${ra:-N/A}"
        done

        printf "%-12s | %8s kB | %8s kB | %8s kB | %8s kB\n" \
            "$lang_name" \
            "${profile_results[debug]}" \
            "${profile_results[release]}" \
            "${profile_results[static]}" \
            "${profile_results[stripped]}"

        unset profile_results
    else
        # Interpreted: run once, show same value across all columns
        lang_prepare "$WORKSPACE" 2>/dev/null
        lang_write_runner "$WORKSPACE"
        chmod +x "$WORKSPACE/run.sh"

        result=$(run_benchmark "$lang_name" "$N_RUNS" "$WORKSPACE/run.sh" 2>/dev/null)
        read -r _vs _vr ra <<<"$result"

        printf "%-12s | %8s kB | %8s kB |        N/A |        N/A\n" \
            "$lang_name" "${ra:-N/A}" "${ra:-N/A}"
    fi

    printf "  ✓ %-12s done\n" "$lang_name" >&2
done

echo "========================================================================"
echo ""
echo "Notes:"
echo "  - 'static' = linkage statique (pas de .so). Peut ne pas compiler partout."
echo "  - 'stripped' = symboles de debug retirés (-s)."
echo "  - Interprétés: même résultat debug/release (pas de compilation)."

# Cleanup
cd /tmp || exit 1
rm -rf "$WORKSPACE"
