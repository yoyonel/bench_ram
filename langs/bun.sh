#!/bin/bash
# Bun benchmark
lang_name="Bun"
lang_cmd="bun"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec bun -e 'while(true){}'
RUNNER
}

# Startup benchmark — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat >"$ws/startup_run.sh" <<'RUNNER'
#!/bin/bash
exec bun -e 'process.exit(0)'
RUNNER
}
