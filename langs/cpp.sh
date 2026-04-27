#!/bin/bash
# C++ benchmark
lang_name="C++"
lang_cmd="g++"
lang_type="compiled"

# Compare profile flags (g++-style)
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
    echo 'int main(){while(true);}' >"$ws/loop.cpp"
    # shellcheck disable=SC2086
    g++ $flags "$ws/loop.cpp" -o "$ws/loop_cpp"
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_cpp\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1" flags="${2:--O2}"
    echo 'int main(){return 0;}' >"$ws/startup.cpp"
    # shellcheck disable=SC2086
    g++ $flags "$ws/startup.cpp" -o "$ws/startup_cpp"
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_cpp\"" >>"$ws/startup_run.sh"
}
