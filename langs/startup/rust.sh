#!/bin/bash
# Rust startup — immediate exit
lang_startup_prepare() {
    local ws="$1" flags="${2:--C opt-level=2}"
    echo 'fn main(){}' > "$ws/startup.rs"
    rustc $flags "$ws/startup.rs" -o "$ws/startup_rust"
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec \"$ws/startup_rust\"" >> "$ws/startup_run.sh"
}
