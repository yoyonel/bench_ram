#!/bin/bash
# C++ benchmark — infinite loop
lang_name="C++"
lang_cmd="g++"

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
