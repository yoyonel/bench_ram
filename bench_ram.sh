#!/bin/bash
# Do NOT use set -e: we intentionally kill processes and wait on them,
# which returns non-zero exit codes by design.
set -uo pipefail

# ============================================================
# bench_ram.sh — Benchmark RAM footprint of programming languages
# Measures VmSize, VmRSS, RssAnon via /proc/[pid]/status
# with poll-based stabilization and N repetitions (median).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/tmp/ram_bench_workspace"
N_RUNS="${BENCH_RUNS:-5}"

# Source libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/measure.sh"

# Parse arguments
OPT_FLAGS=""
while getopts "n:f:" opt; do
    case $opt in
        n) N_RUNS="$OPTARG" ;;
        f) OPT_FLAGS="$OPTARG" ;;  # e.g. "-O3" or "-O0 -static"
        *) echo "Usage: $0 [-n runs] [-f 'compiler flags']"; exit 1 ;;
    esac
done

# Setup workspace
rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"

echo "====================================================================="
echo "  BENCHMARK: Empreinte RAM — boucle infinie (Linux /proc/status)"
echo "  Runs: $N_RUNS | Compiler flags: ${OPT_FLAGS:-(default per lang)}"
echo "====================================================================="

# Collect results: array of "lang vmsize vmrss rssanon"
declare -a RESULTS=()

# Run each language
for lang_file in "$SCRIPT_DIR"/langs/*.sh; do
    # Reset lang vars
    unset -f lang_prepare lang_run lang_write_runner
    lang_name="" lang_cmd=""

    source "$lang_file"

    # Check command availability
    if ! check_cmd "$lang_cmd" "$lang_name"; then
        continue
    fi

    # Prepare (compile if needed), writes $WORKSPACE/run.sh
    if [[ -n "$OPT_FLAGS" ]]; then
        lang_prepare "$WORKSPACE" "$OPT_FLAGS" 2>/dev/null
    else
        lang_prepare "$WORKSPACE" 2>/dev/null
    fi

    # Generate launcher script
    lang_write_runner "$WORKSPACE"
    chmod +x "$WORKSPACE/run.sh"

    # Run benchmark
    result=$(run_benchmark "$lang_name" "$N_RUNS" "$WORKSPACE/run.sh")
    read -r vs vr ra <<< "$result"
    RESULTS+=("$lang_name $vs $vr $ra")

    printf "  ✓ %-12s done (%d runs)\n" "$lang_name" "$N_RUNS" >&2
done

echo "=====================================================================" >&2

# Sort results by RssAnon (ascending) and display
echo ""
printf "%-12s | %14s | %14s | %14s\n" "Langage" "VmSize (Virt)" "VmRSS (Total)" "RssAnon (Excl)"
echo "-----------------------------------------------------------------------"

IFS=$'\n' sorted=($(for r in "${RESULTS[@]}"; do
    read -r name vs vr ra <<< "$r"
    printf "%s %s %s %s\n" "$name" "$vs" "$vr" "$ra"
done | sort -t' ' -k4 -n))
unset IFS

for line in "${sorted[@]}"; do
    read -r name vs vr ra <<< "$line"
    printf "%-12s | %12s | %12s | %12s\n" \
        "$name" "$(fmt_kb "$vs")" "$(fmt_kb "$vr")" "$(fmt_kb "$ra")"
done

echo "======================================================================="

# Cleanup
cd /tmp
rm -rf "$WORKSPACE"