#!/bin/bash
# Python 3 benchmark
lang_name="Python"
lang_cmd="python3"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec python3 -c 'while True: pass'
RUNNER
}

# Startup benchmark — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat >"$ws/startup_run.sh" <<'RUNNER'
#!/bin/bash
exec python3 -c ''
RUNNER
}
