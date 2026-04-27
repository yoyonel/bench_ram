#!/bin/bash
# Java startup — immediate exit
lang_startup_prepare() {
    local ws="$1"
    cat > "$ws/Startup.java" << 'EOF'
public class Startup {
    public static void main(String[] args) {}
}
EOF
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec java -cp \"$ws\" Startup.java" >> "$ws/startup_run.sh"
}
