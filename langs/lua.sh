#!/bin/bash
# Lua benchmark — infinite loop
lang_name="Lua"
lang_cmd="lua"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat > "$ws/run.sh" << 'RUNNER'
#!/bin/bash
exec lua -e 'while true do end'
RUNNER
}
