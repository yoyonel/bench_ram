#!/bin/bash
# C benchmark
lang_name="C"
lang_cmd="gcc"
lang_type="compiled"

# Compare profile flags (gcc-style)
lang_compare_flags() {
    local profile="$1"
    case "$profile" in
        debug) echo "-O0 -g" ;;
        release) echo "-O2" ;;
        static) echo "-O2 -static" ;;
        stripped) echo "-O2 -s" ;;
    esac
}

# RAM benchmark — infinite loop
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

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1" flags="${2:--O2}"
    echo 'int main(){return 0;}' >"$ws/startup.c"
    # shellcheck disable=SC2086
    gcc $flags "$ws/startup.c" -o "$ws/startup_c"
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_c\"" >>"$ws/startup_run.sh"
}
