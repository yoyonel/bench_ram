#!/bin/bash
# V benchmark
lang_name="V"
lang_cmd="v"
lang_type="compiled"

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1"
    echo 'fn main() { for {} }' >"$ws/loop.v"
    (cd "$ws" && v -o loop_v loop.v 2>/dev/null)
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_v\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1"
    echo 'fn main() {}' >"$ws/startup.v"
    (cd "$ws" && v -o startup_v startup.v 2>/dev/null)
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_v\"" >>"$ws/startup_run.sh"
}
