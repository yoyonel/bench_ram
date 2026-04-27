#!/bin/bash
# Do NOT use set -e: startup measurements may have non-zero exits.
set -uo pipefail

# ============================================================
# bench_startup.sh — Benchmark startup time of programming languages
# Measures wall-clock time of a minimal program that exits immediately.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/engine.sh"
engine_init "bench_startup" 5 "[-n runs] [-f 'compiler flags'] [-o output_dir]" "n:f:o:" "$@"

source "$SCRIPT_DIR/lib/startup.sh"

# Calibrate shell overhead (empty exec)
cat >"$WORKSPACE/baseline_run.sh" <<'EOF'
#!/bin/bash
exec true
EOF
chmod +x "$WORKSPACE/baseline_run.sh"
SHELL_OVERHEAD=$(benchmark_startup "$N_RUNS" "$WORKSPACE/baseline_run.sh")

echo "====================================================================="
echo "  BENCHMARK: Temps de démarrage (Linux, wall-clock)"
echo "  Runs: $N_RUNS | Compiler flags: ${OPT_FLAGS:-(default per lang)}"
echo "  Shell overhead (subtracted): ${SHELL_OVERHEAD} µs"
echo "====================================================================="

declare -a RESULTS=()

run_startup_lang() {
    # Must have startup functions defined
    if ! declare -f lang_startup_prepare >/dev/null 2>&1 \
        || ! declare -f lang_startup_runner >/dev/null 2>&1; then
        return
    fi

    if [[ -n "$OPT_FLAGS" ]]; then
        lang_startup_prepare "$WORKSPACE" "$OPT_FLAGS" 2>/dev/null
    else
        lang_startup_prepare "$WORKSPACE" 2>/dev/null
    fi

    lang_startup_runner "$WORKSPACE"
    chmod +x "$WORKSPACE/startup_run.sh"

    raw_time=$(benchmark_startup "$N_RUNS" "$WORKSPACE/startup_run.sh")
    adjusted=$((raw_time - SHELL_OVERHEAD))
    ((adjusted < 0)) && adjusted=0

    RESULTS+=("$lang_name $adjusted")
    printf "  ✓ %-12s done (%d runs)\n" "$lang_name" "$N_RUNS" >&2
}

engine_iterate_langs run_startup_lang

echo "=====================================================================" >&2

# Sort and display
echo ""
printf "%-12s | %14s | %14s\n" "Langage" "Startup (µs)" "Startup (ms)"
echo "---------------------------------------------"

mapfile -t sorted < <(for r in "${RESULTS[@]}"; do
    echo "$r"
done | sort -t' ' -k2 -n)

for line in "${sorted[@]}"; do
    read -r name time_us <<<"$line"
    time_ms=$(awk "BEGIN {printf \"%.2f\", $time_us / 1000}")
    printf "%-12s | %12s | %12s\n" "$name" "${time_us} µs" "${time_ms} ms"
done

echo "============================================="

engine_finish "startup" "${sorted[@]}"
