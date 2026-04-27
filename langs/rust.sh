#!/bin/bash
# Rust benchmark — infinite loop
lang_name="Rust"
lang_cmd="rustc"

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
