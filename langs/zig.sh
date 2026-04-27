#!/bin/bash
# Zig benchmark — infinite loop
lang_name="Zig"
lang_cmd="zig"

lang_prepare() {
    local ws="$1"
    cat > "$ws/loop.zig" << 'EOF'
pub fn main() void {
    while (true) {}
}
EOF
    (cd "$ws" && zig build-exe loop.zig -O ReleaseSafe -femit-bin=loop_zig 2>/dev/null)
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/loop_zig\"" >> "$ws/run.sh"
}
