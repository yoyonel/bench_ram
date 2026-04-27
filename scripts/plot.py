#!/usr/bin/env python3
"""Generate bar charts from bench_ram CSV exports.

Usage:
    python3 scripts/plot.py results/ram_*.csv
    python3 scripts/plot.py results/startup_*.csv
    python3 scripts/plot.py results/ram_*.csv --output chart.png
    python3 scripts/plot.py results/ram_*.csv --ascii  # No matplotlib needed
"""

import argparse
import csv
import sys
from pathlib import Path


def read_csv(path):
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        return list(reader)


def detect_type(headers):
    if "rssanon_kb" in headers:
        return "ram"
    if "startup_us" in headers:
        return "startup"
    if "debug_kb" in headers:
        return "compare"
    return None


def plot_ascii_bar(labels, values, unit, title, max_width=50):
    print(f"\n  {title}\n")
    if not values:
        print("  (no data)")
        return
    max_val = max(values) if max(values) > 0 else 1
    for label, val in zip(labels, values):
        bar_len = int((val / max_val) * max_width)
        bar = "█" * bar_len
        print(f"  {label:>12s} │ {bar} {val} {unit}")
    print()


def plot_matplotlib(labels, values, unit, title, output):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print(
            "Error: matplotlib not installed. Use --ascii or: pip install matplotlib",
            file=sys.stderr,
        )
        sys.exit(1)

    fig, ax = plt.subplots(figsize=(10, max(4, len(labels) * 0.5)))
    colors = []
    for v in values:
        if v < 500:
            colors.append("#2ecc71")
        elif v < 5000:
            colors.append("#f39c12")
        else:
            colors.append("#e74c3c")

    bars = ax.barh(labels[::-1], values[::-1], color=colors[::-1])
    ax.set_xlabel(unit)
    ax.set_title(title)
    ax.bar_label(bars, fmt="%d", padding=3)
    plt.tight_layout()

    if output:
        plt.savefig(output, dpi=150)
        print(f"  Chart saved to {output}", file=sys.stderr)
    else:
        plt.show()


def main():
    parser = argparse.ArgumentParser(description="Plot bench_ram results")
    parser.add_argument("csv_file", help="CSV file from bench_ram export")
    parser.add_argument("-o", "--output", help="Output image file (PNG/SVG)")
    parser.add_argument(
        "--ascii", action="store_true", help="ASCII bar chart (no matplotlib)"
    )
    args = parser.parse_args()

    rows = read_csv(args.csv_file)
    if not rows:
        print("Empty CSV", file=sys.stderr)
        sys.exit(1)

    bench_type = detect_type(rows[0].keys())

    if bench_type == "ram":
        labels = [r["language"] for r in rows]
        values = [int(r["rssanon_kb"]) for r in rows]
        unit = "kB"
        title = "RAM Footprint — RssAnon (kB)"
    elif bench_type == "startup":
        labels = [r["language"] for r in rows]
        values = [int(r["startup_us"]) for r in rows]
        unit = "µs"
        title = "Startup Time (µs)"
    elif bench_type == "compare":
        labels = [r["language"] for r in rows]
        values = [
            int(r["release_kb"]) if r["release_kb"] != "N/A" else 0 for r in rows
        ]
        unit = "kB"
        title = "RAM Footprint — Release Profile (kB)"
    else:
        print(f"Unknown CSV format: {list(rows[0].keys())}", file=sys.stderr)
        sys.exit(1)

    if args.ascii:
        plot_ascii_bar(labels, values, unit, title)
    else:
        plot_matplotlib(labels, values, unit, title, args.output)


if __name__ == "__main__":
    main()
