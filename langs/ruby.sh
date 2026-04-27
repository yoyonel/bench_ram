#!/bin/bash
# Ruby benchmark — infinite loop
lang_name="Ruby"
lang_cmd="ruby"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat >"$ws/run.sh" <<'RUNNER'
#!/bin/bash
exec ruby -e 'loop {}'
RUNNER
}
