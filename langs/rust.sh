#!/bin/bash
# Rust benchmark
lang_name="Rust"
lang_cmd="rustc"
lang_type="compiled"

# Compare profile flags (rustc-style)
lang_compare_flags() {
    local profile="$1"
    case "$profile" in
        debug) echo "-C opt-level=0 -g" ;;
        release) echo "-C opt-level=2" ;;
        static) echo "-C opt-level=2 -C target-feature=+crt-static" ;;
        stripped) echo "-C opt-level=2 -C strip=symbols" ;;
    esac
}

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1" flags="${2:--C opt-level=2}"
    echo 'fn main(){loop{}}' >"$ws/loop.rs"
    # shellcheck disable=SC2086
    rustc $flags "$ws/loop.rs" -o "$ws/loop_rust"
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_rust\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1" flags="${2:--C opt-level=2}"
    echo 'fn main(){}' >"$ws/startup.rs"
    # shellcheck disable=SC2086
    rustc $flags "$ws/startup.rs" -o "$ws/startup_rust"
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_rust\"" >>"$ws/startup_run.sh"
}
