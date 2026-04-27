#!/bin/bash
# measure.sh — Poll /proc/[pid]/status until VmRSS stabilizes, then capture metrics.

# Wait for VmRSS to stabilize: read every POLL_INTERVAL_MS ms,
# consider stable when N consecutive reads have delta < THRESHOLD_KB.
# Timeout after MAX_WAIT_S seconds.
POLL_INTERVAL_MS=100
STABLE_COUNT=3
THRESHOLD_KB=64
MAX_WAIT_S=10

# Read a single metric from /proc/$1/status
read_proc_metric() {
    local pid="$1" metric="$2"
    if [[ -f "/proc/$pid/status" ]]; then
        awk -v m="$metric:" '$1 == m {print $2}' "/proc/$pid/status"
    fi
}

# Poll VmRSS until stable, then capture all metrics.
# Sets global vars: MEASURED_VMSIZE, MEASURED_VMRSS, MEASURED_RSSANON
wait_stable_and_measure() {
    local pid="$1"
    local prev_rss=0
    local stable=0
    local elapsed=0
    local max_ms=$((MAX_WAIT_S * 1000))

    while ((elapsed < max_ms)); do
        local rss
        rss=$(read_proc_metric "$pid" "VmRSS")
        [[ -z "$rss" ]] && break # process gone

        local delta=$((rss > prev_rss ? rss - prev_rss : prev_rss - rss))
        if ((delta < THRESHOLD_KB)); then
            ((stable++))
        else
            stable=0
        fi

        if ((stable >= STABLE_COUNT)); then
            # Stable — capture final snapshot
            MEASURED_VMSIZE=$(read_proc_metric "$pid" "VmSize")
            MEASURED_VMRSS=$(read_proc_metric "$pid" "VmRSS")
            MEASURED_RSSANON=$(read_proc_metric "$pid" "RssAnon")
            return 0
        fi

        prev_rss=$rss
        sleep "0.$(printf '%03d' "$POLL_INTERVAL_MS")"
        ((elapsed += POLL_INTERVAL_MS))
    done

    # Timeout — capture whatever we have
    MEASURED_VMSIZE=$(read_proc_metric "$pid" "VmSize")
    MEASURED_VMRSS=$(read_proc_metric "$pid" "VmRSS")
    MEASURED_RSSANON=$(read_proc_metric "$pid" "RssAnon")
    return 1
}

# Run a single measurement: launch script, wait stable, kill, return metrics.
# Usage: run_once <lang_name> <script_path>
# Outputs: VMSIZE VMRSS RSSANON (in kB, space-separated)
run_once() {
    local lang="$1" script="$2"
    "$script" &
    local pid=$!

    wait_stable_and_measure "$pid"

    kill -9 "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    if [[ -n "${MEASURED_VMRSS:-}" ]]; then
        echo "${MEASURED_VMSIZE:-0} ${MEASURED_VMRSS:-0} ${MEASURED_RSSANON:-0}"
    else
        echo "0 0 0"
    fi
}

# Run N repetitions, compute median for each metric.
# Usage: run_benchmark <lang_name> <n_runs> <script_path>
# Outputs: VMSIZE_MEDIAN VMRSS_MEDIAN RSSANON_MEDIAN (in kB, space-separated)
run_benchmark() {
    local lang="$1" n="$2" script="$3"
    local vmsize_arr=() vmrss_arr=() rssanon_arr=()

    for ((i = 0; i < n; i++)); do
        local result
        result=$(run_once "$lang" "$script")
        read -r vs vr ra <<<"$result"
        vmsize_arr+=("$vs")
        vmrss_arr+=("$vr")
        rssanon_arr+=("$ra")
    done

    local vmsize_med vmrss_med rssanon_med
    vmsize_med=$(median "${vmsize_arr[@]}")
    vmrss_med=$(median "${vmrss_arr[@]}")
    rssanon_med=$(median "${rssanon_arr[@]}")

    echo "$vmsize_med $vmrss_med $rssanon_med"
}
