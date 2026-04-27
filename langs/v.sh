#!/bin/bash
# V benchmark — infinite loop
lang_name="V"
lang_cmd="v"

lang_prepare() {
    local ws="$1"
    echo 'fn main() { for {} }' > "$ws/loop.v"
    (cd "$ws" && v -o loop_v loop.v 2>/dev/null)
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/loop_v\"" >> "$ws/run.sh"
}
