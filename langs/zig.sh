#!/bin/bash
# Zig benchmark
lang_name="Zig"
lang_cmd="zig"
lang_type="compiled"

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1"
    cat >"$ws/loop.zig" <<'EOF'
pub fn main() void {
    while (true) {}
}
EOF
    (cd "$ws" && zig build-exe loop.zig -O ReleaseSafe -femit-bin=loop_zig 2>/dev/null)
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_zig\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1"
    cat >"$ws/startup.zig" <<'EOF'
pub fn main() void {}
EOF
    (cd "$ws" && zig build-exe startup.zig -O ReleaseSafe -femit-bin=startup_zig 2>/dev/null)
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_zig\"" >>"$ws/startup_run.sh"
}
