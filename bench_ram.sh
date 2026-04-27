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
source "$SCRIPT_DIR/lib/engine.sh"
engine_init "bench_ram" 5 "[-n runs] [-f 'compiler flags'] [-o output_dir]" "n:f:o:" "$@"

source "$SCRIPT_DIR/lib/measure.sh"

echo "====================================================================="
echo "  BENCHMARK: Empreinte RAM — boucle infinie (Linux /proc/status)"
echo "  Runs: $N_RUNS | Compiler flags: ${OPT_FLAGS:-(default per lang)}"
echo "====================================================================="

declare -a RESULTS=()

run_ram_lang() {
    if [[ -n "$OPT_FLAGS" ]]; then
        lang_prepare "$WORKSPACE" "$OPT_FLAGS" 2>/dev/null
    else
        lang_prepare "$WORKSPACE" 2>/dev/null
    fi

    lang_write_runner "$WORKSPACE"
    chmod +x "$WORKSPACE/run.sh"

    result=$(run_benchmark "$lang_name" "$N_RUNS" "$WORKSPACE/run.sh")
    read -r vs vr ra <<<"$result"
    RESULTS+=("$lang_name $vs $vr $ra")

    printf "  ✓ %-12s done (%d runs)\n" "$lang_name" "$N_RUNS" >&2
}

engine_iterate_langs run_ram_lang

echo "=====================================================================" >&2

# Sort results by RssAnon (ascending) and display
echo ""
printf "%-12s | %14s | %14s | %14s\n" "Langage" "VmSize (Virt)" "VmRSS (Total)" "RssAnon (Excl)"
echo "-----------------------------------------------------------------------"

mapfile -t sorted < <(for r in "${RESULTS[@]}"; do
    echo "$r"
done | sort -t' ' -k4 -n)

for line in "${sorted[@]}"; do
    read -r name vs vr ra <<<"$line"
    printf "%-12s | %12s | %12s | %12s\n" \
        "$name" "$(fmt_kb "$vs")" "$(fmt_kb "$vr")" "$(fmt_kb "$ra")"
done

echo "======================================================================="

engine_finish "ram" "${sorted[@]}"
