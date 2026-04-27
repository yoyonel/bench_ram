#!/bin/bash
# Node.js benchmark — infinite loop
lang_name="Node.js"
lang_cmd="node"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat > "$ws/run.sh" << 'RUNNER'
#!/bin/bash
exec node -e 'while(true){}'
RUNNER
}
