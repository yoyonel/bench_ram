#!/bin/bash
# test_container.sh — Non-regression tests for container execution.
# Validates that container mode behaves consistently with native mode.
# Usage: ./scripts/test_container.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
TOTAL=0

pass() {
    ((TOTAL++)) || true
    ((PASS++)) || true
    printf "  ✓ %s\n" "$1"
}

fail() {
    ((TOTAL++)) || true
    ((FAIL++)) || true
    printf "  ✗ %s\n" "$1"
}

assert_contains() {
    local output="$1" pattern="$2" label="$3"
    if echo "$output" | grep -qE "$pattern"; then
        pass "$label"
    else
        fail "$label — expected pattern: $pattern"
    fi
}

assert_exit() {
    local code="$1" expected="$2" label="$3"
    if [[ "$code" -eq "$expected" ]]; then
        pass "$label"
    else
        fail "$label — got exit $code, expected $expected"
    fi
}

echo "================================================================"
echo "  NON-REGRESSION TESTS — Container mode"
echo "================================================================"
echo ""

# ── T1: Script help and version ─────────────────────────────
echo "--- [T1] --version / --help in container"

out=$(./scripts/container.sh ram --version 2>&1) || true
assert_contains "$out" "bench_ram [0-9]" "bench_ram.sh --version"

out=$(./scripts/container.sh startup --version 2>&1) || true
assert_contains "$out" "bench_startup [0-9]" "bench_startup.sh --version"

out=$(./scripts/container.sh compare --version 2>&1) || true
assert_contains "$out" "bench_compare [0-9]" "bench_compare.sh --version"

out=$(./scripts/container.sh help 2>&1) || true
assert_contains "$out" "Usage:" "container.sh help"

echo ""

# ── T2: Arguments propagation ───────────────────────────────
echo "--- [T2] Argument propagation (-n)"

out=$(./scripts/container.sh ram -n 1 2>&1) || true
assert_contains "$out" "Runs: 1" "ram -n 1 propagates runs"
assert_contains "$out" "done \(1 runs\)" "ram -n 1 actually runs 1"

echo ""

# ── T3: Export format validation ─────────────────────────────
echo "--- [T3] Export formats (CSV, JSON, Markdown)"

EXPORT_DIR=$(mktemp -d /tmp/bench_test_export_XXXXXX)
trap 'rm -rf "$EXPORT_DIR"' EXIT

./scripts/container.sh ram -n 1 -- -o /bench/results 2>&1 | tail -1
# Use the output dir mapped in the container
# Actually, run export command to get files in a temp dir
# The container maps results/ so we need to use container export

# Run a quick RAM export in the container
TMPRESULTS=$(mktemp -d /tmp/bench_export_XXXXXX)
cp -r results "$TMPRESULTS/results_backup" 2>/dev/null || true

./scripts/container.sh export -n 1 >/dev/null 2>&1

# Find the latest export files
CSV=$(find results -maxdepth 1 -name 'ram_*.csv' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
JSON=$(find results -maxdepth 1 -name 'ram_*.json' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
MD=$(find results -maxdepth 1 -name 'ram_*.md' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)

if [[ -n "$CSV" ]]; then
    # CSV: has metadata comment + header + data
    if head -1 "$CSV" | grep -q '^#'; then
        pass "CSV has metadata comment line"
    else
        fail "CSV missing metadata comment line"
    fi
    if grep -q 'language,vmsize_kb,vmrss_kb,rssanon_kb' "$CSV"; then
        pass "CSV has correct header"
    else
        fail "CSV header mismatch"
    fi
    data_lines=$(grep -cv '^#\|^language' "$CSV" || true)
    if [[ "$data_lines" -ge 15 ]]; then
        pass "CSV has $data_lines data rows (>= 15 languages)"
    else
        fail "CSV has only $data_lines data rows (expected >= 15)"
    fi
else
    fail "No RAM CSV export found"
fi

if [[ -n "$JSON" ]]; then
    # JSON: has metadata wrapper
    if python3 -c "
import json, sys
with open('$JSON') as f:
    d = json.load(f)
assert 'metadata' in d, 'no metadata key'
assert 'results' in d, 'no results key'
m = d['metadata']
assert m['environment'] == 'container', f'environment={m[\"environment\"]}'
assert 'container_image' in m, 'no container_image'
assert 'container_runtime' in m, 'no container_runtime'
assert len(d['results']) >= 15, f'only {len(d[\"results\"])} results'
" 2>&1; then
        pass "JSON has metadata + results structure (container)"
    else
        fail "JSON metadata validation failed"
    fi
else
    fail "No RAM JSON export found"
fi

if [[ -n "$MD" ]]; then
    if grep -q '| Langage' "$MD"; then
        pass "Markdown has table header"
    else
        fail "Markdown missing table header"
    fi
else
    fail "No RAM Markdown export found"
fi

echo ""

# ── T4: All 15 languages produce results ────────────────────
echo "--- [T4] Language completeness in container"

out=$(./scripts/container.sh ram -n 1 2>&1)
count=$(echo "$out" | grep -c '✓' || true)
if [[ "$count" -ge 15 ]]; then
    pass "RAM benchmark: $count/15 languages completed"
else
    fail "RAM benchmark: only $count/15 languages completed"
fi

echo ""

# ── T5: Native mode not broken ──────────────────────────────
echo "--- [T5] Native mode still works"

native_out=$(./bench_ram.sh -n 1 2>&1) || true
native_count=$(echo "$native_out" | grep -c '✓' || true)
if [[ "$native_count" -ge 1 ]]; then
    pass "Native mode: $native_count languages completed"
else
    fail "Native mode: no languages completed"
fi

native_version=$(./bench_ram.sh --version 2>&1) || true
assert_contains "$native_version" "bench_ram [0-9]" "Native --version works"

echo ""

# ── Summary ─────────────────────────────────────────────────
echo "================================================================"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================================================"

[[ $FAIL -eq 0 ]]
