# bench_ram — Justfile
# Usage: just <recipe>  |  just --list

# Default: show available recipes
default:
    @just --list

# ─── Benchmarks ──────────────────────────────────────────────

# Run RAM benchmark (infinite loop, RssAnon)
ram *ARGS:
    ./bench_ram.sh {{ARGS}}

# Run RAM benchmark with default settings (5 runs, default flags)
ram-default:
    ./bench_ram.sh

# Run startup time benchmark (exit-immediately programs)
startup *ARGS:
    ./bench_startup.sh {{ARGS}}

# Run compilation profile comparison (debug/release/static/stripped)
compare *ARGS:
    ./bench_compare.sh {{ARGS}}

# Run all three benchmarks sequentially
all *ARGS:
    @echo "═══ RAM Benchmark ═══"
    ./bench_ram.sh {{ARGS}}
    @echo ""
    @echo "═══ Startup Benchmark ═══"
    ./bench_startup.sh {{ARGS}}
    @echo ""
    @echo "═══ Compare Benchmark ═══"
    ./bench_compare.sh {{ARGS}}

# ─── Quick presets ───────────────────────────────────────────

# Quick run: 1 iteration per language (fast sanity check)
quick:
    ./bench_ram.sh -n 1

# Precise run: 10 iterations per language
precise:
    ./bench_ram.sh -n 10

# Compare optimisation levels: -O0 vs -O2 vs -O3
optlevels:
    @echo "═══ -O0 (no optimization) ═══"
    ./bench_ram.sh -n 3 -f "-O0"
    @echo ""
    @echo "═══ -O2 (default release) ═══"
    ./bench_ram.sh -n 3 -f "-O2"
    @echo ""
    @echo "═══ -O3 (aggressive) ═══"
    ./bench_ram.sh -n 3 -f "-O3"

# ─── Export & Visualization ──────────────────────────────────

# Run all benchmarks and export results to results/
export *ARGS:
    ./bench_ram.sh -o results {{ARGS}}
    ./bench_startup.sh -o results {{ARGS}}
    ./bench_compare.sh -o results {{ARGS}}

# Generate all ASCII bar charts
plot: plot-ram plot-startup

# Generate ASCII bar chart from the latest RAM export
plot-ram:
    #!/bin/bash
    csv=$(ls -t results/ram_*.csv 2>/dev/null | head -1)
    [[ -z "$csv" ]] && echo "No RAM export found. Run 'just export' first." && exit 1
    python3 scripts/plot.py "$csv" --ascii

# Generate ASCII bar chart from the latest startup export
plot-startup:
    #!/bin/bash
    csv=$(ls -t results/startup_*.csv 2>/dev/null | head -1)
    [[ -z "$csv" ]] && echo "No startup export found. Run 'just export' first." && exit 1
    python3 scripts/plot.py "$csv" --ascii

# Generate PNG charts (requires matplotlib: pip install matplotlib)
plot-png:
    #!/bin/bash
    ram=$(ls -t results/ram_*.csv 2>/dev/null | head -1)
    startup=$(ls -t results/startup_*.csv 2>/dev/null | head -1)
    [[ -z "$ram" || -z "$startup" ]] && echo "No exports found. Run 'just export' first." && exit 1
    python3 scripts/plot.py "$ram" -o results/ram_chart.png
    python3 scripts/plot.py "$startup" -o results/startup_chart.png

# ─── Utilities ───────────────────────────────────────────────

# List all supported languages and their toolchain availability
langs:
    #!/bin/bash
    echo "Langage      | Commande     | Statut"
    echo "-------------|--------------|--------"
    for f in langs/*.sh; do
        [[ -d "$f" ]] && continue
        lang_name="" lang_cmd=""
        source "$f"
        if command -v "$lang_cmd" >/dev/null 2>&1; then
            version=$("$lang_cmd" --version 2>/dev/null | head -1 || echo "installed")
            [[ -z "$version" || "$version" == *"usage"* || "$version" == *"flag"* ]] && \
                version=$("$lang_cmd" version 2>/dev/null | head -1 || echo "installed")
            printf "%-12s | %-12s | ✓ %s\n" "$lang_name" "$lang_cmd" "$version"
        else
            printf "%-12s | %-12s | ✗ non installé\n" "$lang_name" "$lang_cmd"
        fi
    done

# Show project structure
tree:
    @find . -not -path './.git/*' -not -path './.git' | sort | sed 's|[^/]*/|  |g'

# Verify all scripts are executable
check:
    #!/bin/bash
    ok=0; fail=0
    for f in bench_ram.sh bench_startup.sh bench_compare.sh; do
        if [[ -x "$f" ]]; then
            echo "✓ $f (executable)"
            ((ok++))
        else
            echo "✗ $f (not executable)"
            ((fail++))
        fi
    done
    echo "---"
    echo "$ok OK, $fail issues"
    [[ $fail -eq 0 ]]

# ─── Lint & Format ───────────────────────────────────────────

# Show project version
version:
    @cat VERSION

# Run shellcheck on all scripts
lint:
    shellcheck bench_ram.sh bench_startup.sh bench_compare.sh lib/*.sh langs/*.sh

# Check formatting (no changes, exit 1 if diff)
format-check:
    shfmt -d -i 4 -bn -ci bench_ram.sh bench_startup.sh bench_compare.sh lib/*.sh langs/*.sh

# Auto-format all scripts in-place
format:
    shfmt -w -i 4 -bn -ci bench_ram.sh bench_startup.sh bench_compare.sh lib/*.sh langs/*.sh

# Run both lint and format check
ci: lint format-check

# ─── Container Execution ─────────────────────────────────────

# Build the container image
container-build:
    ./scripts/container.sh build

# Run RAM benchmark in container
container-ram *ARGS:
    ./scripts/container.sh ram {{ARGS}}

# Run startup benchmark in container
container-startup *ARGS:
    ./scripts/container.sh startup {{ARGS}}

# Run compare benchmark in container
container-compare *ARGS:
    ./scripts/container.sh compare {{ARGS}}

# Run all benchmarks in container
container-all *ARGS:
    ./scripts/container.sh all {{ARGS}}

# Export all benchmarks results from container
container-export *ARGS:
    ./scripts/container.sh export {{ARGS}}

# Open interactive shell in the container (debug)
container-shell:
    ./scripts/container.sh shell

# List languages and versions available in the container
container-langs:
    ./scripts/container.sh langs
