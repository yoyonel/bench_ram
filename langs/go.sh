#!/bin/bash
# Go benchmark
lang_name="Go"
lang_cmd="go"
lang_type="compiled"

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1"
    cat >"$ws/loop.go" <<'EOF'
package main

import "runtime"

func main() {
    runtime.LockOSThread()
    for {
    }
}
EOF
    (cd "$ws" && go build -o loop_go loop.go)
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec \"$ws/loop_go\"" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1"
    echo 'package main; func main() {}' >"$ws/startup.go"
    (cd "$ws" && go build -o startup_go startup.go)
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec \"$ws/startup_go\"" >>"$ws/startup_run.sh"
}
