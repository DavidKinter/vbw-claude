#!/bin/bash
# VBW Execution Gate - Stop Hook
#
# Native enforcement: Claude cannot finish a VBW session until actual
# execution (docker build, pytest, npm test, etc.) has occurred.
# Syntax checks and grep patterns are not sufficient.
#
# This hook is triggered by the "Stop" event in Claude Code.
# It checks the execution log in the shadow directory.
#
# Installation: Add to .claude/settings.json:
# {
#   "hooks": {
#     "Stop": [{
#       "hooks": [{
#         "type": "command",
#         "command": ".claude/hooks/vbw-execution-gate.sh"
#       }]
#     }]
#   }
# }

set -e

SHADOW="/tmp/vbw-shadow"
EXEC_LOG="$SHADOW/.vbw-execution-log"
GATE_MARKER="$SHADOW/.vbw-gate-required"

# -----------------------------------------------------------------------------
# If not in VBW context, allow stop (don't interfere with normal Claude usage)
# -----------------------------------------------------------------------------
if [ ! -f "$GATE_MARKER" ]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# VBW session active - enforce execution gate
# -----------------------------------------------------------------------------

# Check if execution log exists
if [ ! -f "$EXEC_LOG" ]; then
    cat << 'EOF'
{
  "decision": "block",
  "reason": "VBW Execution Gate: No execution log found. Commands must be logged during execution. Ensure vbw-execute logs commands to /tmp/vbw-shadow/.vbw-execution-log"
}
EOF
    exit 0
fi

# Patterns that indicate ACTUAL execution (not just syntax checks)
# These are commands that build, run, or test code
EXEC_PATTERNS="docker build|docker-compose build|docker compose build"
EXEC_PATTERNS="$EXEC_PATTERNS|pytest|py\.test|python -m pytest"
EXEC_PATTERNS="$EXEC_PATTERNS|npm test|npm run test|yarn test|pnpm test"
EXEC_PATTERNS="$EXEC_PATTERNS|cargo build|cargo test|cargo run"
EXEC_PATTERNS="$EXEC_PATTERNS|go build|go test|go run"
EXEC_PATTERNS="$EXEC_PATTERNS|uv run|uv sync"
EXEC_PATTERNS="$EXEC_PATTERNS|bundle exec|rake test|rspec"
EXEC_PATTERNS="$EXEC_PATTERNS|mvn test|gradle test"
EXEC_PATTERNS="$EXEC_PATTERNS|dotnet build|dotnet test"

# Patterns that are NOT sufficient (syntax checks only)
SYNTAX_ONLY_PATTERNS="py_compile|python -m py_compile"
SYNTAX_ONLY_PATTERNS="$SYNTAX_ONLY_PATTERNS|yaml\.safe_load|json\.load"
SYNTAX_ONLY_PATTERNS="$SYNTAX_ONLY_PATTERNS|^grep |^rg |^awk |^sed "
SYNTAX_ONLY_PATTERNS="$SYNTAX_ONLY_PATTERNS|hadolint|yamllint|jsonlint"

# Count execution commands
EXEC_COUNT=$(grep -cE "$EXEC_PATTERNS" "$EXEC_LOG" 2>/dev/null || echo 0)

# Count syntax-only commands
SYNTAX_COUNT=$(grep -cE "$SYNTAX_ONLY_PATTERNS" "$EXEC_LOG" 2>/dev/null || echo 0)

# -----------------------------------------------------------------------------
# Decision logic
# -----------------------------------------------------------------------------

if [ "$EXEC_COUNT" -eq 0 ]; then
    # No execution commands found - BLOCK

    # Build helpful message showing what was found
    FOUND_COMMANDS=$(grep -E "^CMD:" "$EXEC_LOG" 2>/dev/null | head -5 | sed 's/^/    /' || echo "    (none)")

    cat << EOF
{
  "decision": "block",
  "reason": "VBW Execution Gate FAILED: No build/test commands detected.\n\nFound only:\n$FOUND_COMMANDS\n\nVBW requires at least one of:\n  - docker build\n  - pytest / npm test / cargo test / go test\n  - uv run <command>\n\nSyntax checks (py_compile, grep, yaml.safe_load) are NOT sufficient.\n\nReturn to execution and run actual build/test commands."
}
EOF
    exit 0
fi

# Execution commands found - ALLOW
cat << EOF
{
  "decision": "allow",
  "reason": "VBW Execution Gate PASSED: $EXEC_COUNT execution command(s) detected."
}
EOF
exit 0
