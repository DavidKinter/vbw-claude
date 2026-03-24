#!/bin/bash
# VBW Copy Gate - PreToolUse Hook
#
# Native enforcement: Claude cannot copy files from sandbox to project
# without explicit user approval via AskUserQuestion.
#
# This hook is triggered by the "PreToolUse" event for Bash commands.
# It checks for copy operations from /tmp/vbw-sandbox/ to outside paths.
#
# Installation: Add to .claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{
#         "type": "command",
#         "command": ".claude/hooks/vbw-copy-gate.sh"
#       }]
#     }]
#   }
# }

set -e

SANDBOX="/tmp/vbw-sandbox"
APPROVAL_MARKER="$SANDBOX/.vbw-copy-approved"
GATE_MARKER="$SANDBOX/.vbw-gate-required"

# -----------------------------------------------------------------------------
# Read the command from stdin (Claude Code passes tool input as JSON)
# Input format: {"tool_name": "Bash", "tool_input": {"command": "..."}, ...}
# -----------------------------------------------------------------------------
INPUT=$(cat)

# Extract the command being executed
# Handles JSON like: {"tool_input": {"command": "cp /tmp/vbw-sandbox/file.py /project/"}}
# Use sed for portability (macOS doesn't have grep -P)
COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# If we couldn't extract command, allow (don't break non-Bash tools)
if [ -z "$COMMAND" ]; then
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

# -----------------------------------------------------------------------------
# If not in VBW context, allow (don't interfere with normal Claude usage)
# -----------------------------------------------------------------------------
if [ ! -f "$GATE_MARKER" ]; then
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

# -----------------------------------------------------------------------------
# Check if command copies FROM sandbox TO outside sandbox
# -----------------------------------------------------------------------------

# Patterns that indicate copy FROM sandbox
SANDBOX_SOURCE_PATTERNS=(
    "cp .*${SANDBOX}"
    "cp -[a-zA-Z]* .*${SANDBOX}"
    "rsync .*${SANDBOX}"
    "mv .*${SANDBOX}"
    "cat ${SANDBOX}.*>"
)

# Check if command matches any copy-from-sandbox pattern
COPIES_FROM_SANDBOX=false
for pattern in "${SANDBOX_SOURCE_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
        COPIES_FROM_SANDBOX=true
        break
    fi
done

# If not copying from sandbox, allow
if [ "$COPIES_FROM_SANDBOX" = false ]; then
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

# -----------------------------------------------------------------------------
# Now check: is the DESTINATION outside sandbox?
# -----------------------------------------------------------------------------

# Extract destination path (last argument for cp/mv/rsync, or path after > for cat)
# This is heuristic - covers common cases

DEST=""

# For cat redirect: cat /tmp/vbw-sandbox/file > /dest/file
if echo "$COMMAND" | grep -qE "cat.*>"; then
    DEST=$(echo "$COMMAND" | sed -n 's/.*> *\([^ ]*\).*/\1/p')
fi

# For cp: cp [-flags] source dest
if echo "$COMMAND" | grep -qE "^cp "; then
    # Get last argument
    DEST=$(echo "$COMMAND" | awk '{print $NF}')
fi

# For mv: mv [-flags] source dest
if echo "$COMMAND" | grep -qE "^mv "; then
    DEST=$(echo "$COMMAND" | awk '{print $NF}')
fi

# For rsync: rsync [-flags] source dest
if echo "$COMMAND" | grep -qE "^rsync "; then
    DEST=$(echo "$COMMAND" | awk '{print $NF}')
fi

# If destination is inside sandbox, allow (sandbox-internal operations are fine)
if echo "$DEST" | grep -qE "^${SANDBOX}"; then
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    exit 0
fi

# If destination is empty or unclear, be safe and check for approval
# (Could be a complex command we don't fully parse)

# -----------------------------------------------------------------------------
# This is a copy FROM sandbox TO outside - REQUIRE APPROVAL MARKER
# -----------------------------------------------------------------------------

if [ -f "$APPROVAL_MARKER" ]; then
    # Approval marker exists - allow the copy
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "VBW Copy Gate: Approval marker present, copy allowed."
  }
}
EOF
    exit 0
fi

# No approval marker - BLOCK (deny)
cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "VBW Copy Gate BLOCKED: Attempting to copy from sandbox to project without approval. You must use AskUserQuestion to get explicit user approval before copying files from /tmp/vbw-sandbox/ to the project. After user approves, create the approval marker with: touch /tmp/vbw-sandbox/.vbw-copy-approved"
  }
}
EOF
exit 0
