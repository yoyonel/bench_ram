#!/bin/bash
# startup.sh — Measure process startup time.
# Uses wall-clock time of executing a minimal program that immediately exits.
# The program prints nothing; we measure the shell overhead-subtracted time.

# Measure startup time of a script/binary that exits immediately.
# Usage: measure_startup <script_path>
# Output: time in microseconds
measure_startup() {
    local script="$1"
    local start_ns end_ns elapsed_ns

    start_ns=$(date +%s%N)
    "$script"
    end_ns=$(date +%s%N)

    elapsed_ns=$((end_ns - start_ns))
    # Return microseconds
    echo $((elapsed_ns / 1000))
}

# Run N startup measurements, return median in microseconds.
# Usage: benchmark_startup <n_runs> <script_path>
benchmark_startup() {
    local n="$1" script="$2"
    local times=()

    for ((i = 0; i < n; i++)); do
        local t
        t=$(measure_startup "$script")
        times+=("$t")
    done

    median "${times[@]}"
}
