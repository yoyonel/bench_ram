#!/bin/bash
# Do NOT use set -e: startup measurements may have non-zero exits.
set -uo pipefail

# ============================================================
# bench_startup.sh — Benchmark startup time of programming languages
# Measures wall-clock time of a minimal program that exits immediately.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/tmp/ram_bench_workspace"
N_RUNS="${BENCH_RUNS:-5}"

# Source libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/startup.sh"

# Parse arguments
OPT_FLAGS=""
while getopts "n:f:" opt; do
    case $opt in
        n) N_RUNS="$OPTARG" ;;
        f) OPT_FLAGS="$OPTARG" ;;
        *) echo "Usage: $0 [-n runs] [-f 'compiler flags']"; exit 1 ;;
    esac
done

# Setup workspace
rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"

# First, measure the shell overhead (empty exec)
cat > "$WORKSPACE/baseline_run.sh" << 'EOF'
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

# Collect results: array of "lang time_us"
declare -a RESULTS=()

# Run each language
for lang_file in "$SCRIPT_DIR"/langs/*.sh; do
    local_name=$(basename "$lang_file" .sh)
    startup_file="$SCRIPT_DIR/langs/startup/$local_name.sh"

    # Must have a matching startup definition
    [[ -f "$startup_file" ]] || continue

    # Reset functions
    unset -f lang_startup_prepare lang_startup_runner
    lang_name="" lang_cmd=""

    # Source the main lang file (for lang_name, lang_cmd)
    source "$lang_file"

    # Check command availability
    if ! check_cmd "$lang_cmd" "$lang_name"; then
        continue
    fi

    # Source startup definitions
    source "$startup_file"

    # Prepare
    if [[ -n "$OPT_FLAGS" ]]; then
        lang_startup_prepare "$WORKSPACE" "$OPT_FLAGS" 2>/dev/null
    else
        lang_startup_prepare "$WORKSPACE" 2>/dev/null
    fi

    # Write runner
    lang_startup_runner "$WORKSPACE"
    chmod +x "$WORKSPACE/startup_run.sh"

    # Measure
    raw_time=$(benchmark_startup "$N_RUNS" "$WORKSPACE/startup_run.sh")
    # Subtract shell overhead
    adjusted=$((raw_time - SHELL_OVERHEAD))
    ((adjusted < 0)) && adjusted=0

    RESULTS+=("$lang_name $adjusted")
    printf "  ✓ %-12s done (%d runs)\n" "$lang_name" "$N_RUNS" >&2
done

echo "=====================================================================" >&2

# Sort and display
echo ""
printf "%-12s | %14s | %14s\n" "Langage" "Startup (µs)" "Startup (ms)"
echo "---------------------------------------------"

IFS=$'\n' sorted=($(for r in "${RESULTS[@]}"; do
    echo "$r"
done | sort -t' ' -k2 -n))
unset IFS

for line in "${sorted[@]}"; do
    read -r name time_us <<< "$line"
    time_ms=$(awk "BEGIN {printf \"%.2f\", $time_us / 1000}")
    printf "%-12s | %12s | %12s\n" "$name" "${time_us} µs" "${time_ms} ms"
done

echo "============================================="

# Cleanup
cd /tmp
rm -rf "$WORKSPACE"
