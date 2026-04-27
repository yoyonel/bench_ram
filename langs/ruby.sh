#!/bin/bash
# Ruby benchmark
lang_name="Ruby"
lang_cmd="ruby"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec ruby -e 'loop {}'
RUNNER
}

# Startup benchmark — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat >"$ws/startup_run.sh" <<'RUNNER'
#!/bin/bash
exec ruby -e ''
RUNNER
}
