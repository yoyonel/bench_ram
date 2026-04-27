#!/bin/bash
# C startup — immediate exit
lang_startup_prepare() {
    local ws="$1" flags="${2:--O2}"
    echo 'int main(){return 0;}' > "$ws/startup.c"
    gcc $flags "$ws/startup.c" -o "$ws/startup_c"
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec \"$ws/startup_c\"" >> "$ws/startup_run.sh"
}
