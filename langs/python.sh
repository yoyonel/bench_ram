#!/bin/bash
# Python 3 benchmark — infinite loop
lang_name="Python"
lang_cmd="python3"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec python3 -c 'while True: pass'
RUNNER
}
