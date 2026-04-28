#!/bin/bash
# validate_delta.sh — Compare RAM benchmark results: native vs container.
# Exits 0 if all languages are within threshold, 1 otherwise.
# Usage: ./scripts/validate_delta.sh [-n runs] [-t threshold_pct]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

THRESHOLD=${BENCH_DELTA_THRESHOLD:-5}
N_RUNS=3

while getopts "n:t:" opt; do
    case $opt in
        n) N_RUNS="$OPTARG" ;;
        t) THRESHOLD="$OPTARG" ;;
        *)
            echo "Usage: $0 [-n runs] [-t threshold_pct]"
            exit 1
            ;;
    esac
done

# ── Detect container runtime ────────────────────────────────
if command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
else
    echo "Error: neither podman nor docker found" >&2
    exit 1
fi

IMAGE_TAG=$(cat "$SCRIPT_DIR/VERSION")
IMAGE="bench_ram:${IMAGE_TAG}"

NATIVE_DIR=$(mktemp -d /tmp/bench_delta_native_XXXXXX)
CONTAINER_DIR=$(mktemp -d /tmp/bench_delta_container_XXXXXX)
trap 'rm -rf "$NATIVE_DIR" "$CONTAINER_DIR"' EXIT

echo "================================================================"
echo "  VALIDATION: Delta container vs native"
echo "  Runs: $N_RUNS | Threshold: ${THRESHOLD}% on RssAnon"
echo "  Runtime: $RUNTIME | Image: $IMAGE"
echo "================================================================"
echo ""

# ── Run native benchmark ────────────────────────────────────
echo "--- [1/3] Running native benchmark..."
"$SCRIPT_DIR/bench_ram.sh" -n "$N_RUNS" -o "$NATIVE_DIR" >/dev/null
NATIVE_JSON="$(ls "$NATIVE_DIR"/ram_*.json)"
echo "  -> $(basename "$NATIVE_JSON")"
echo ""

# ── Run container benchmark ─────────────────────────────────
echo "--- [2/3] Running container benchmark..."
"$RUNTIME" run --rm \
    -v "$SCRIPT_DIR:/bench:ro" \
    -v "$CONTAINER_DIR:/output" \
    -e "BENCH_CONTAINER_IMAGE=$IMAGE" \
    -e "BENCH_CONTAINER_RUNTIME=$RUNTIME" \
    "$IMAGE" \
    ./bench_ram.sh -n "$N_RUNS" -o /output >/dev/null
CONTAINER_JSON="$(ls "$CONTAINER_DIR"/ram_*.json)"
echo "  -> $(basename "$CONTAINER_JSON")"
echo ""

# ── Compute and display delta ───────────────────────────────
echo "--- [3/3] Computing delta..."
echo ""

python3 - "$NATIVE_JSON" "$CONTAINER_JSON" "$THRESHOLD" <<'PYEOF'
import json, sys

native_path, container_path, threshold = sys.argv[1], sys.argv[2], float(sys.argv[3])

def load_results(path):
    with open(path) as f:
        data = json.load(f)
    results = data["results"] if isinstance(data, dict) else data
    return {r["language"]: r for r in results}

native = load_results(native_path)
container = load_results(container_path)

metrics = ["vmsize_kb", "vmrss_kb", "rssanon_kb"]
header = f"{'Language':>12s} | {'VmSize':>10s} | {'VmRSS':>10s} | {'RssAnon':>10s} | Status"
sep = "-" * len(header)

print(header)
print(sep)

all_pass = True
for lang in sorted(native.keys()):
    if lang not in container:
        print(f"{lang:>12s} | {'MISSING':>10s} | {'MISSING':>10s} | {'MISSING':>10s} | SKIP")
        continue

    n, c = native[lang], container[lang]
    deltas = []
    for m in metrics:
        nv, cv = n[m], c[m]
        if nv == 0:
            delta = 0.0 if cv == 0 else float("inf")
        else:
            delta = ((cv - nv) / nv) * 100
        deltas.append(delta)

    rssanon_delta = abs(deltas[2])
    status = "PASS" if rssanon_delta <= threshold else "FAIL"
    if rssanon_delta > threshold:
        all_pass = False

    cols = " | ".join(f"{d:>+9.1f}%" for d in deltas)
    mark = "\u2713" if status == "PASS" else "\u2717"
    print(f"{lang:>12s} | {cols} | {mark} {status}")

print(sep)
if all_pass:
    print(f"\n\u2713 All languages within {threshold}% threshold on RssAnon.")
    sys.exit(0)
else:
    print(f"\n\u2717 Some languages exceed {threshold}% threshold on RssAnon.")
    sys.exit(1)
PYEOF
