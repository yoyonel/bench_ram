#!/bin/bash
# export.sh — Export benchmark results to CSV, JSON, and Markdown.

# Write RAM benchmark results to CSV.
# Usage: export_ram_csv <output_file> <sorted_results_array_name>
export_ram_csv() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "language,vmsize_kb,vmrss_kb,rssanon_kb"
        for line in "${lines[@]}"; do
            read -r name vs vr ra <<<"$line"
            echo "$name,$vs,$vr,$ra"
        done
    } >"$output"
}

# Write RAM benchmark results to JSON.
export_ram_json() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "["
        local first=1
        for line in "${lines[@]}"; do
            read -r name vs vr ra <<<"$line"
            [[ $first -eq 0 ]] && echo ","
            printf '  {"language": "%s", "vmsize_kb": %s, "vmrss_kb": %s, "rssanon_kb": %s}' \
                "$name" "$vs" "$vr" "$ra"
            first=0
        done
        echo ""
        echo "]"
    } >"$output"
}

# Write RAM benchmark results to Markdown table.
export_ram_md() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "| Langage | VmSize (kB) | VmRSS (kB) | RssAnon (kB) |"
        echo "|---------|------------:|----------:|-------------:|"
        for line in "${lines[@]}"; do
            read -r name vs vr ra <<<"$line"
            echo "| $name | $vs | $vr | $ra |"
        done
    } >"$output"
}

# Write startup benchmark results to CSV.
export_startup_csv() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "language,startup_us"
        for line in "${lines[@]}"; do
            read -r name time_us <<<"$line"
            echo "$name,$time_us"
        done
    } >"$output"
}

# Write startup benchmark results to JSON.
export_startup_json() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "["
        local first=1
        for line in "${lines[@]}"; do
            read -r name time_us <<<"$line"
            [[ $first -eq 0 ]] && echo ","
            printf '  {"language": "%s", "startup_us": %s}' "$name" "$time_us"
            first=0
        done
        echo ""
        echo "]"
    } >"$output"
}

# Write startup benchmark results to Markdown table.
export_startup_md() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "| Langage | Startup (µs) | Startup (ms) |"
        echo "|---------|-------------:|-------------:|"
        for line in "${lines[@]}"; do
            read -r name time_us <<<"$line"
            local time_ms
            time_ms=$(awk "BEGIN {printf \"%.2f\", $time_us / 1000}")
            echo "| $name | $time_us | $time_ms |"
        done
    } >"$output"
}

# Write compare benchmark results to CSV.
export_compare_csv() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "language,debug_kb,release_kb,static_kb,stripped_kb"
        for line in "${lines[@]}"; do
            # Format: "name debug release static stripped"
            read -r name d r s st <<<"$line"
            echo "$name,$d,$r,$s,$st"
        done
    } >"$output"
}

# Write compare benchmark results to JSON.
export_compare_json() {
    local output="$1"
    shift
    local lines=("$@")
    {
        echo "["
        local first=1
        for line in "${lines[@]}"; do
            read -r name d r s st <<<"$line"
            [[ $first -eq 0 ]] && echo ","
            printf '  {"language": "%s", "debug_kb": "%s", "release_kb": "%s", "static_kb": "%s", "stripped_kb": "%s"}' \
                "$name" "$d" "$r" "$s" "$st"
            first=0
        done
        echo ""
        echo "]"
    } >"$output"
}

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

    case "$type" in
        ram)
            export_ram_csv "$outdir/ram_${ts}.csv" "${results[@]}"
            export_ram_json "$outdir/ram_${ts}.json" "${results[@]}"
            export_ram_md "$outdir/ram_${ts}.md" "${results[@]}"
            ;;
        startup)
            export_startup_csv "$outdir/startup_${ts}.csv" "${results[@]}"
            export_startup_json "$outdir/startup_${ts}.json" "${results[@]}"
            export_startup_md "$outdir/startup_${ts}.md" "${results[@]}"
            ;;
        compare)
            export_compare_csv "$outdir/compare_${ts}.csv" "${results[@]}"
            export_compare_json "$outdir/compare_${ts}.json" "${results[@]}"
            ;;
    esac

    echo "  Exported to $outdir/ (${type}_${ts}.*)" >&2
}
