#!/bin/bash
# VBW Live API Validation Gate - Stop Hook
#
# Native enforcement: Claude cannot finish a VBW session that involves
# external API integration until live API validation has been performed
# and no structural mismatches (MISMATCH verdicts) were detected.
#
# Activation: Only active when /tmp/vbw-sandbox/.vbw-live-validation-endpoints
# exists — meaning the orchestrator identified external API integration
# in the current task. Sessions with no external APIs are unaffected.
#
# Architecture: The orchestrator performs the live HTTP calls and writes
# results to .vbw-live-validation-result. This hook only VERIFIES that
# the validation occurred and checks for MISMATCH verdicts. It does NOT
# make HTTP calls itself.
#
# Installation: Included in .claude/settings.json Stop hooks array.
# Runs in parallel with vbw-execution-gate.sh on every Stop event.

set -e

SANDBOX="/tmp/vbw-sandbox"
ENDPOINTS_MARKER="$SANDBOX/.vbw-live-validation-endpoints"
RESULT_FILE="$SANDBOX/.vbw-live-validation-result"
GATE_MARKER="$SANDBOX/.vbw-gate-required"

# -------------------------------------------------------------------
# If not in VBW context, allow stop (normal Claude Code usage)
# -------------------------------------------------------------------
if [ ! -f "$GATE_MARKER" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# -------------------------------------------------------------------
# If no API validation marker, allow stop (task has no external APIs)
# -------------------------------------------------------------------
if [ ! -f "$ENDPOINTS_MARKER" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# -------------------------------------------------------------------
# API validation IS required — check that it was performed
# -------------------------------------------------------------------

# Check 1: Result file must exist
if [ ! -f "$RESULT_FILE" ]; then
    cat << 'EOF'
{
  "decision": "block",
  "reason": "VBW Live API Gate BLOCKED: External API integration detected but no live validation was performed.\n\nThe file .vbw-live-validation-endpoints exists, indicating this task involves external APIs.\nBut .vbw-live-validation-result does not exist, meaning Phase 3.5 (Live API Validation) was skipped.\n\nYou MUST:\n1. Make a live HTTP call to each endpoint listed in .vbw-live-validation-endpoints\n2. Compare the response structure against the mocked test expectations\n3. Write the verdict (MATCH/PARTIAL/MISMATCH/UNREACHABLE) to .vbw-live-validation-result\n\nReturn to the orchestrator and complete Phase 3.5 before finishing."
}
EOF
    exit 0
fi

# Check 2: Result file must not contain MISMATCH
if grep -q "^MISMATCH" "$RESULT_FILE" 2>/dev/null; then
    MISMATCHES=$(grep "^MISMATCH" "$RESULT_FILE" | head -5 | sed 's/^/    /')
    cat << EOF
{
  "decision": "block",
  "reason": "VBW Live API Gate BLOCKED: Live API validation detected structural mismatches.\n\nMismatched endpoints:\n$MISMATCHES\n\nThe live API response structure does not match the mocked test expectations.\nThis means the mocked tests are wrong — they validate against a hallucinated API schema.\n\nYou MUST fix the mocked tests to match the actual API response structure,\nthen re-run validation before finishing."
}
EOF
    exit 0
fi

# Check 3: Result file exists and contains no MISMATCH — allow stop
VERDICT_COUNT=$(wc -l < "$RESULT_FILE" | tr -d ' ')
cat << EOF
{
  "decision": "approve",
  "reason": "VBW Live API Gate PASSED: $VERDICT_COUNT endpoint(s) validated, no mismatches detected."
}
EOF
exit 0
