#!/bin/bash
# V startup — immediate exit
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
