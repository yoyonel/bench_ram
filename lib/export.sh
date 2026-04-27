#!/bin/bash
# export.sh — Export benchmark results to CSV, JSON, and Markdown.
# Schema-driven: field definitions live in export_all, format writers are generic.

# ── Generic format writers ───────────────────────────────────

# Write CSV file from space-separated results.
# Usage: _export_csv <output> <header> <results...>
_export_csv() {
    local output="$1" header="$2"
    shift 2
    {
        echo "$header"
        for line in "$@"; do
            echo "${line// /,}"
        done
    } >"$output"
}

# Write JSON file from space-separated results.
# Usage: _export_json <output> <keys> <types> <results...>
# keys: space-separated JSON field names
# types: space-separated (s=string, n=number), matching keys positionally
_export_json() {
    local output="$1"
    local -a keys types
    read -ra keys <<<"$2"
    read -ra types <<<"$3"
    shift 3
    {
        echo "["
        local first=1
        for line in "$@"; do
            local -a vals
            read -ra vals <<<"$line"
            [[ $first -eq 0 ]] && echo ","
            printf '  {'
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
        echo "]"
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

    case "$type" in
        ram)
            _export_csv "$base.csv" \
                "language,vmsize_kb,vmrss_kb,rssanon_kb" \
                "${results[@]}"
            _export_json "$base.json" \
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
            _export_csv "$base.csv" \
                "language,startup_us" \
                "${results[@]}"
            _export_json "$base.json" \
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
            _export_csv "$base.csv" \
                "language,debug_kb,release_kb,static_kb,stripped_kb" \
                "${results[@]}"
            _export_json "$base.json" \
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
