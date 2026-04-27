#!/bin/bash
# Go benchmark — infinite loop
lang_name="Go"
lang_cmd="go"

lang_prepare() {
    local ws="$1"
    cat > "$ws/loop.go" << 'EOF'
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
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/loop_go\"" >> "$ws/run.sh"
}
