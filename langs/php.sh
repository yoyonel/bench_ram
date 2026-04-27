#!/bin/bash
# PHP benchmark
lang_name="PHP"
lang_cmd="php"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec php -r 'while(true){}'
RUNNER
}

# Startup benchmark — immediate exit
lang_startup_prepare() { :; }

lang_startup_runner() {
    local ws="$1"
    cat >"$ws/startup_run.sh" <<'RUNNER'
#!/bin/bash
exec php -r ''
RUNNER
}
