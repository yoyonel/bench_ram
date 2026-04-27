#!/bin/bash
# Go startup — immediate exit
lang_startup_prepare() {
    local ws="$1"
    echo 'package main; func main() {}' > "$ws/startup.go"
    (cd "$ws" && go build -o startup_go startup.go)
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec \"$ws/startup_go\"" >> "$ws/startup_run.sh"
}
