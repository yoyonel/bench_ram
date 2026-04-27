#!/bin/bash
# Nim startup — immediate exit
lang_startup_prepare() {
    local ws="$1"
    echo 'discard' >"$ws/startup_nim.nim"
    nim c -d:release --hints:off --outdir:"$ws" -o:startup_nim "$ws/startup_nim.nim" >/dev/null 2>&1
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_nim\"" >>"$ws/startup_run.sh"
}
