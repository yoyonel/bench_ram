#!/bin/bash
# Zig startup — immediate exit
lang_startup_prepare() {
    local ws="$1"
    cat > "$ws/startup.zig" << 'EOF'
pub fn main() void {}
EOF
    (cd "$ws" && zig build-exe startup.zig -O ReleaseSafe -femit-bin=startup_zig 2>/dev/null)
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec \"$ws/startup_zig\"" >> "$ws/startup_run.sh"
}
