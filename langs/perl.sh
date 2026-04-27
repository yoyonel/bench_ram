#!/bin/bash
# Perl benchmark — infinite loop
lang_name="Perl"
lang_cmd="perl"

lang_prepare() { :; }

lang_write_runner() {
    local ws="$1"
    cat > "$ws/run.sh" << 'RUNNER'
#!/bin/bash
exec perl -e 'while(1){}'
RUNNER
}
