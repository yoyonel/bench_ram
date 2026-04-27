#!/bin/bash
# C benchmark — infinite loop
lang_name="C"
lang_cmd="gcc"

lang_prepare() {
    local ws="$1" flags="${2:--O2}"
    echo 'int main(){while(1);}' >"$ws/loop.c"
    # shellcheck disable=SC2086
    gcc $flags "$ws/loop.c" -o "$ws/loop_c"
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_c\"" >>"$ws/run.sh"
}
