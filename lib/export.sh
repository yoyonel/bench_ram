#!/bin/bash
# export.sh — Export benchmark results to CSV, JSON, and Markdown.
# Schema-driven: field definitions live in export_all, format writers are generic.

# ── Environment detection ────────────────────────────────────

# Detect if running inside a container.
_detect_environment() {
    if [[ -n "${BENCH_CONTAINER_IMAGE:-}" ]] \
        || [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] \
        || grep -qsE 'docker|containerd|podman' /proc/1/cgroup 2>/dev/null; then
        echo "container"
    else
        echo "native"
    fi
}

# Build metadata JSON fragment for embedding in exports.
_build_metadata_json() {
    local type="$1"
    local env kernel version ts
    env=$(_detect_environment)
    kernel=$(uname -r)
    version="${VERSION:-unknown}"
    ts=$(date -Iseconds)

    printf '  "metadata": {\n'
    printf '    "benchmark_type": "%s",\n' "$type"
    printf '    "timestamp": "%s",\n' "$ts"
    printf '    "version": "%s",\n' "$version"
    printf '    "environment": "%s",\n' "$env"
    printf '    "kernel_version": "%s"' "$kernel"
    if [[ "$env" == "container" ]]; then
        printf ',\n    "container_image": "%s"' "${BENCH_CONTAINER_IMAGE:-unknown}"
        printf ',\n    "container_runtime": "%s"' "${BENCH_CONTAINER_RUNTIME:-unknown}"
    fi
    printf '\n  }'
}

# Build metadata comment line for CSV headers.
_build_metadata_csv() {
    local type="$1"
    local env kernel version ts
    env=$(_detect_environment)
    kernel=$(uname -r)
    version="${VERSION:-unknown}"
    ts=$(date -Iseconds)

    printf '# benchmark_type=%s;timestamp=%s;version=%s;environment=%s;kernel_version=%s' \
        "$type" "$ts" "$version" "$env" "$kernel"
    if [[ "$env" == "container" ]]; then
        printf ';container_image=%s;container_runtime=%s' \
            "${BENCH_CONTAINER_IMAGE:-unknown}" "${BENCH_CONTAINER_RUNTIME:-unknown}"
    fi
    printf '\n'
}

# ── Generic format writers ───────────────────────────────────

# Write CSV file from space-separated results.
# Usage: _export_csv <output> <metadata_comment> <header> <results...>
_export_csv() {
    local output="$1" metadata="$2" header="$3"
    shift 3
    {
        [[ -n "$metadata" ]] && echo "$metadata"
        echo "$header"
        for line in "$@"; do
            echo "${line// /,}"
        done
    } >"$output"
}

# Write JSON file from space-separated results.
# Usage: _export_json <output> <metadata_json> <keys> <types> <results...>
# metadata_json: output of _build_metadata_json (empty string = plain array)
# keys: space-separated JSON field names
# types: space-separated (s=string, n=number), matching keys positionally
_export_json() {
    local output="$1" metadata="$2"
    local -a keys types
    read -ra keys <<<"$3"
    read -ra types <<<"$4"
    shift 4
    local indent="  "
    {
        if [[ -n "$metadata" ]]; then
            echo "{"
            echo "$metadata,"
            echo '  "results": ['
            indent="    "
        else
            echo "["
        fi
        local first=1
        for line in "$@"; do
            local -a vals
            read -ra vals <<<"$line"
            [[ $first -eq 0 ]] && echo ","
            printf '%s{' "$indent"
            for i in "${!keys[@]}"; do
                ((i > 0)) && printf ', '
                if [[ "${vals[$i]}" == "N/A" ]]; then
                    printf '"%s": null' "${keys[$i]}"
                elif [[ "${types[$i]}" == "n" ]]; then
                    printf '"%s": %s' "${keys[$i]}" "${vals[$i]}"
                else
                    printf '"%s": "%s"' "${keys[$i]}" "${vals[$i]}"
                fi
            done
            printf '}'
            first=0
        done
        echo ""
        if [[ -n "$metadata" ]]; then
            echo "  ]"
            echo "}"
        else
            echo "]"
        fi
    } >"$output"
}

# Write Markdown table from results.
# Usage: _export_md <output> <header> <separator> <row_fn> <results...>
# row_fn: function that formats one result line into a Markdown row
_export_md() {
    local output="$1" header="$2" separator="$3" row_fn="$4"
    shift 4
    {
        echo "$header"
        echo "$separator"
        for line in "$@"; do
            "$row_fn" "$line"
        done
    } >"$output"
}

# ── Markdown row formatters ──────────────────────────────────

_md_row_ram() {
    read -r name vs vr ra <<<"$1"
    echo "| $name | $vs | $vr | $ra |"
}

_md_row_startup() {
    read -r name time_us <<<"$1"
    local time_ms
    time_ms=$(awk "BEGIN {printf \"%.2f\", $time_us / 1000}")
    echo "| $name | $time_us | $time_ms |"
}

_md_row_compare() {
    read -r name d r s st <<<"$1"
    echo "| $name | $d | $r | $s | $st |"
}

# ── Main export dispatcher ───────────────────────────────────

# Export all formats for a given benchmark type.
# Usage: export_all <type> <output_dir> <results...>
# type: ram, startup, compare
export_all() {
    local type="$1" outdir="$2"
    shift 2
    local results=("$@")

    mkdir -p "$outdir"

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local base="$outdir/${type}_${ts}"

    # Collect environment metadata
    local meta_json meta_csv
    meta_json=$(_build_metadata_json "$type")
    meta_csv=$(_build_metadata_csv "$type")

    case "$type" in
        ram)
            _export_csv "$base.csv" "$meta_csv" \
                "language,vmsize_kb,vmrss_kb,rssanon_kb" \
                "${results[@]}"
            _export_json "$base.json" "$meta_json" \
                "language vmsize_kb vmrss_kb rssanon_kb" \
                "s n n n" \
                "${results[@]}"
            _export_md "$base.md" \
                "| Langage | VmSize (kB) | VmRSS (kB) | RssAnon (kB) |" \
                "|---------|------------:|----------:|-------------:|" \
                _md_row_ram \
                "${results[@]}"
            ;;
        startup)
            _export_csv "$base.csv" "$meta_csv" \
                "language,startup_us" \
                "${results[@]}"
            _export_json "$base.json" "$meta_json" \
                "language startup_us" \
                "s n" \
                "${results[@]}"
            _export_md "$base.md" \
                "| Langage | Startup (µs) | Startup (ms) |" \
                "|---------|-------------:|-------------:|" \
                _md_row_startup \
                "${results[@]}"
            ;;
        compare)
            _export_csv "$base.csv" "$meta_csv" \
                "language,debug_kb,release_kb,static_kb,stripped_kb" \
                "${results[@]}"
            _export_json "$base.json" "$meta_json" \
                "language debug_kb release_kb static_kb stripped_kb" \
                "s n n n n" \
                "${results[@]}"
            _export_md "$base.md" \
                "| Langage | debug (kB) | release (kB) | static (kB) | stripped (kB) |" \
                "|---------|----------:|------------:|----------:|-------------:|" \
                _md_row_compare \
                "${results[@]}"
            ;;
    esac

    echo "  Exported to $outdir/ (${type}_${ts}.*)" >&2
}
