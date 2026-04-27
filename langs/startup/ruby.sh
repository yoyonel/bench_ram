#!/bin/bash
# Ruby startup — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat > "$ws/startup_run.sh" << 'RUNNER'
#!/bin/bash
exec ruby -e ''
RUNNER
}
