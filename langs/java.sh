#!/bin/bash
# Java benchmark (single-file source, JDK 11+)
lang_name="Java"
lang_cmd="java"
lang_type="interpreted"

# RAM benchmark — infinite loop
lang_prepare() {
    local ws="$1"
    cat >"$ws/Loop.java" <<'EOF'
public class Loop {
    public static void main(String[] args) {
        while (true) {}
    }
}
EOF
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/run.sh"
    echo "exec java -cp \"$ws\" Loop.java" >>"$ws/run.sh"
}

# Startup benchmark — immediate exit
lang_startup_prepare() {
    local ws="$1"
    cat >"$ws/Startup.java" <<'EOF'
public class Startup {
    public static void main(String[] args) {}
}
EOF
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' >"$ws/startup_run.sh"
    echo "exec java -cp \"$ws\" Startup.java" >>"$ws/startup_run.sh"
}
