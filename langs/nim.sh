#!/bin/bash
# Nim benchmark — infinite loop
lang_name="Nim"
lang_cmd="nim"

lang_prepare() {
    local ws="$1"
    echo 'while true: discard' > "$ws/loop.nim"
    nim c -d:release --hints:off --outdir:"$ws" "$ws/loop.nim" >/dev/null 2>&1
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/loop\"" >> "$ws/run.sh"
}
