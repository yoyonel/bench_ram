#!/bin/bash
# C++ startup — immediate exit
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
