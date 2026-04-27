#!/bin/bash
# Lua benchmark
lang_name="Lua"
lang_cmd="lua"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec lua -e 'while true do end'
RUNNER
}

# Startup benchmark — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat >"$ws/startup_run.sh" <<'RUNNER'
#!/bin/bash
exec lua -e ''
RUNNER
}
