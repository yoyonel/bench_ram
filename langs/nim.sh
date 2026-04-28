#!/bin/bash
# Nim benchmark
lang_name="Nim"
lang_cmd="nim"
lang_type="compiled"

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1"
    echo 'while true: discard' >"$ws/loop.nim"
    nim c -d:release --hints:off --outdir:"$ws" "$ws/loop.nim" >/dev/null 2>&1
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1"
    echo 'discard' >"$ws/startup_nim.nim"
    nim c -d:release --hints:off -o:"$ws/startup_nim" "$ws/startup_nim.nim" >/dev/null 2>&1
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_nim\"" >>"$ws/startup_run.sh"
}
