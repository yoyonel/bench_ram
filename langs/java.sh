#!/bin/bash
# Java benchmark — infinite loop (single-file source, JDK 11+)
lang_name="Java"
lang_cmd="java"

lang_prepare() {
    local ws="$1"
    cat > "$ws/Loop.java" << 'EOF'
public class Loop {
    public static void main(String[] args) {
        while (true) {}
    }
}
EOF
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec java -cp \"$ws\" Loop.java" >> "$ws/run.sh"
}
