#!/bin/bash
# Bun benchmark — infinite loop
lang_name="Bun"
lang_cmd="bun"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec bun -e 'while(true){}'
RUNNER
}
