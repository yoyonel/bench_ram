#!/bin/bash
# container.sh — Run bench_ram inside a Docker/Podman container.
# Usage: ./scripts/container.sh [--rebuild] <command> [args...]
# Commands: ram, startup, compare, all, export, shell, langs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="bench_ram"
IMAGE_TAG="$(cat "$SCRIPT_DIR/VERSION")"

# ── Detect container runtime ────────────────────────────────
detect_runtime() {
    if command -v podman >/dev/null 2>&1; then
        echo "podman"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo "Error: neither podman nor docker found" >&2
        exit 1
    fi
}

RUNTIME="$(detect_runtime)"

# ── Image management ────────────────────────────────────────
image_exists() {
    "$RUNTIME" image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1
}

build_image() {
    echo "Building ${IMAGE_NAME}:${IMAGE_TAG} with ${RUNTIME}..."
    "$RUNTIME" build -t "${IMAGE_NAME}:${IMAGE_TAG}" "$SCRIPT_DIR"
    echo "Done."
}

ensure_image() {
    if ! image_exists; then
        echo "Image ${IMAGE_NAME}:${IMAGE_TAG} not found. Building..."
        build_image
    fi
}

# ── Run container ───────────────────────────────────────────
run_container() {
    "$RUNTIME" run --rm \
        -v "$SCRIPT_DIR:/bench:ro" \
        -v "$SCRIPT_DIR/results:/bench/results" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        "$@"
}

run_shell() {
    "$RUNTIME" run --rm -it \
        -v "$SCRIPT_DIR:/bench:ro" \
        -v "$SCRIPT_DIR/results:/bench/results" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        /bin/bash
}

# ── Parse global options ────────────────────────────────────
REBUILD=0
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --rebuild)
            REBUILD=1
            shift
            ;;
        --runtime)
            RUNTIME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ $REBUILD -eq 1 ]]; then
    build_image
else
    ensure_image
fi

# ── Dispatch command ────────────────────────────────────────
CMD="${1:-help}"
shift || true

case "$CMD" in
    ram)
        run_container ./bench_ram.sh "$@"
        ;;
    startup)
        run_container ./bench_startup.sh "$@"
        ;;
    compare)
        run_container ./bench_compare.sh "$@"
        ;;
    all)
        run_container ./bench_ram.sh "$@"
        run_container ./bench_startup.sh "$@"
        run_container ./bench_compare.sh "$@"
        ;;
    export)
        run_container ./bench_ram.sh -o results "$@"
        run_container ./bench_startup.sh -o results "$@"
        run_container ./bench_compare.sh -o results "$@"
        ;;
    shell)
        run_shell
        ;;
    langs)
        run_container bash -c '
            echo "Langage      | Commande     | Version"
            echo "-------------|--------------|--------"
            for f in langs/*.sh; do
                lang_name="" lang_cmd=""
                source "$f"
                if command -v "$lang_cmd" >/dev/null 2>&1; then
                    ver=$("$lang_cmd" --version 2>/dev/null | head -1 || echo "installed")
                    [[ -z "$ver" || "$ver" == *"usage"* || "$ver" == *"flag"* ]] && \
                        ver=$("$lang_cmd" version 2>/dev/null | head -1 || echo "installed")
                    printf "%-12s | %-12s | %s\n" "$lang_name" "$lang_cmd" "$ver"
                else
                    printf "%-12s | %-12s | NOT FOUND\n" "$lang_name" "$lang_cmd"
                fi
            done
        '
        ;;
    build)
        # Already built above (ensure_image or --rebuild)
        echo "Image ${IMAGE_NAME}:${IMAGE_TAG} ready (${RUNTIME})."
        ;;
    help | *)
        cat <<EOF
Usage: $(basename "$0") [--rebuild] [--runtime docker|podman] <command> [args...]

Commands:
  ram      [args]    Run RAM benchmark (bench_ram.sh)
  startup  [args]    Run startup benchmark (bench_startup.sh)
  compare  [args]    Run compare benchmark (bench_compare.sh)
  all      [args]    Run all three benchmarks
  export   [args]    Run all benchmarks with export to results/
  shell             Open interactive shell in container
  langs             List available languages and versions
  build             Build/verify the container image
  help              Show this help

Options:
  --rebuild          Force rebuild of the container image
  --runtime <rt>     Force runtime (docker or podman)

Examples:
  $(basename "$0") ram -n 5
  $(basename "$0") --rebuild all -n 3
  $(basename "$0") shell
EOF
        ;;
esac
