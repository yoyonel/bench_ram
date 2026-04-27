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
source "$SCRIPT_DIR/lib/engine.sh"
engine_init "bench_compare" 3 "[-n runs] [-o output_dir]" "n:o:" "$@"

source "$SCRIPT_DIR/lib/measure.sh"

# Default compile profiles (fallback when adapter has no lang_compare_flags)
declare -A DEFAULT_PROFILES=(
    ["debug"]="-O0 -g"
    ["release"]="-O2"
    ["static"]="-O2 -static"
    ["stripped"]="-O2 -s"
)

echo "========================================================================"
echo "  BENCHMARK COMPARATIF: debug vs release vs static vs stripped"
echo "  Runs per profile: $N_RUNS | Métrique: RssAnon (kB)"
echo "========================================================================"
echo ""

printf "%-12s | %10s | %10s | %10s | %10s\n" "Langage" "debug" "release" "static" "stripped"
echo "------------------------------------------------------------------------"

declare -a COMPARE_RESULTS=()

run_compare_lang() {
    local lang_file="$1"

    if [[ "${lang_type:-interpreted}" == "compiled" ]]; then
        declare -A profile_results=()
        for profile in debug release static stripped; do
            rm -f "$WORKSPACE/run.sh"

            # Get flags from adapter or fallback to defaults
            if declare -f lang_compare_flags >/dev/null 2>&1; then
                flags=$(lang_compare_flags "$profile")
            else
                flags="${DEFAULT_PROFILES[$profile]:-}"
            fi

            # Re-source to reset functions
            unset -f lang_prepare lang_write_runner lang_compare_flags
            source "$lang_file"

            if [[ -n "$flags" ]]; then
                lang_prepare "$WORKSPACE" "$flags" 2>/dev/null
            else
                lang_prepare "$WORKSPACE" 2>/dev/null
            fi

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

        COMPARE_RESULTS+=("$lang_name ${profile_results[debug]} ${profile_results[release]} ${profile_results[static]} ${profile_results[stripped]}")

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

        COMPARE_RESULTS+=("$lang_name ${ra:-N/A} ${ra:-N/A} N/A N/A")
    fi

    printf "  ✓ %-12s done\n" "$lang_name" >&2
}

engine_iterate_langs run_compare_lang

echo "========================================================================"
echo ""
echo "Notes:"
echo "  - 'static' = linkage statique (pas de .so). Peut ne pas compiler partout."
echo "  - 'stripped' = symboles de debug retirés (-s)."
echo "  - Interprétés: même résultat debug/release (pas de compilation)."

engine_finish "compare" "${COMPARE_RESULTS[@]}"
