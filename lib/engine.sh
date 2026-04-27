#!/bin/bash
# engine.sh — Common benchmark engine.
# Provides init, lang iteration, and cleanup for all bench scripts.
# Caller must set SCRIPT_DIR before sourcing this file.

# Initialize benchmark environment.
# Usage: engine_init <bench_name> <default_runs> <usage_string> <getopts_string> "$@"
engine_init() {
    local bench_name="$1" default_runs="$2" usage="$3" getopts_str="$4"
    shift 4

    VERSION=$(cat "$SCRIPT_DIR/VERSION")
    WORKSPACE="/tmp/bench_workspace_$$"
    N_RUNS="${BENCH_RUNS:-$default_runs}"

    # Handle --version / --help before getopts
    case "${1:-}" in
        --version)
            echo "$bench_name $VERSION"
            exit 0
            ;;
        --help | -h)
            echo "Usage: $0 $usage"
            exit 0
            ;;
    esac

    # Source common libraries
    source "$SCRIPT_DIR/lib/utils.sh"
    source "$SCRIPT_DIR/lib/export.sh"

    # Parse arguments
    OPT_FLAGS=""
    OUTPUT_DIR=""
    OPTIND=1
    while getopts "$getopts_str" opt; do
        case $opt in
            n) N_RUNS="$OPTARG" ;;
            f) OPT_FLAGS="$OPTARG" ;;
            o) OUTPUT_DIR="$OPTARG" ;;
            *)
                echo "Usage: $0 $usage"
                exit 1
                ;;
        esac
    done

    # Setup workspace
    rm -rf "$WORKSPACE"
    mkdir -p "$WORKSPACE"
}

# Iterate over all language adapters.
# Calls the function $1 for each available language.
# Resets and sources each adapter, checks command availability.
# The callback receives the lang_file path as $1.
engine_iterate_langs() {
    local callback="$1"
    for lang_file in "$SCRIPT_DIR"/langs/*.sh; do
        [[ -d "$lang_file" ]] && continue

        # Reset all adapter functions and variables
        unset -f lang_prepare lang_write_runner lang_startup_prepare \
            lang_startup_runner lang_compare_flags lang_run
        lang_name="" lang_cmd="" lang_type=""

        source "$lang_file"

        if ! check_cmd "$lang_cmd" "$lang_name"; then
            continue
        fi

        "$callback" "$lang_file"
    done
}

# Export results and clean up workspace.
# Usage: engine_finish <type> <results...>
engine_finish() {
    local type="$1"
    shift

    if [[ -n "${OUTPUT_DIR:-}" && $# -gt 0 ]]; then
        export_all "$type" "$OUTPUT_DIR" "$@"
    fi

    cd /tmp || exit 1
    rm -rf "$WORKSPACE"
}
