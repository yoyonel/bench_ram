#!/bin/bash
# PHP benchmark — infinite loop
lang_name="PHP"
lang_cmd="php"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec php -r 'while(true){}'
RUNNER
}
