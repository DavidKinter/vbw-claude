# VBW With Targeted Reflection Implementation Playbook

**Created**: 2026-01-20
**Purpose**: Add targeted failure diagnosis to VBW execution loop without full reflexive LLM pattern
**Project**: vbw-claude (https://github.com/DavidKinter/vbw-claude)
**Reference**: VBW Framework Design, existing command files in `commands/`

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Key Principles](#key-principles)
3. [Project Structure](#project-structure)
4. [Phase 0: Baseline Measurement](#phase-0-baseline-measurement)
5. [Phase 1: Diagnosis Protocol Design](#phase-1-diagnosis-protocol-design)
6. [Phase 2: Implementation](#phase-2-implementation)
7. [Phase 3: Testing](#phase-3-testing)
8. [Phase 4: Evaluation & Decision](#phase-4-evaluation--decision)
9. [Troubleshooting](#troubleshooting)
10. [Error Pattern Reference](#error-pattern-reference)

---

## Executive Summary

### What We're Building

```
CURRENT VBW EXECUTION LOOP:
┌─────────────────────────────────────────────────────────────────┐
│  Implement → Validate → FAIL → Retry (blind) → Validate → ...  │
│                           │                                     │
│                           └── No analysis of WHY it failed      │
└─────────────────────────────────────────────────────────────────┘

ENHANCED VBW WITH TARGETED REFLECTION:
┌─────────────────────────────────────────────────────────────────┐
│  Implement → Validate → FAIL → Diagnose → Fix Strategy → Retry  │
│                           │        │                            │
│                           │        ├── Parse error message      │
│                           │        ├── Classify failure type    │
│                           │        └── Lookup fix pattern       │
│                           │                                     │
│                           └── Validation remains deterministic  │
└─────────────────────────────────────────────────────────────────┘
```

### What This Is NOT

| Reflexive LLM Pattern | Targeted Reflection |
|-----------------------|---------------------|
| General self-critique | Structured error parsing |
| "Is my code good?" | "What does this error mean?" |
| Judges quality | Classifies failure type |
| May justify bypassing validation | Validation is hard gate |
| Adds interpretation | Adds categorization |

### Success Criteria

VBW Targeted Reflection is valuable if:
1. **Measurable**: Reduces mean iterations-to-pass by ≥20%
2. **Safe**: Zero cases where diagnosis overrides validation
3. **Efficient**: Token overhead < 30% per failed iteration

---

## Key Principles

### Critical Constraints

| Rule | Rationale |
|------|-----------|
| **Diagnosis is ADVISORY** | Guides retry strategy, never overrides pass/fail |
| **Validation remains DETERMINISTIC** | String matching is the hard gate |
| **No general reflection** | "What's wrong with this error?" not "Is my code good?" |
| **Embedded, not separate** | Diagnosis in vbw-execute, not new skill |
| **Measure before/after** | No improvement = remove feature |

### Diagnosis vs Reflection

```
✓ DIAGNOSIS (What we're adding):
  "ImportError: No module named 'foo'"
  → Type: ImportError
  → Cause: Missing module or typo in import path
  → Strategy: Check import statement, verify module exists

✗ REFLECTION (What we're NOT adding):
  "Let me evaluate whether my code is well-structured..."
  "I think this approach might be better..."
  "The error seems benign, we can probably ignore it..."
```

---

## Project Structure

### VBW-Claude Directory Layout

```
vbw-claude/
├── README.md                    # Project overview
├── package.json                 # npm package config
├── pyproject.toml               # Python dependencies (if any)
├── bin/
│   └── install.js               # Installation script
├── commands/                    # Slash command definitions
│   ├── vbw-implement.md         # Orchestrator (TO BE MODIFIED)
│   ├── vbw-execute.md           # Execution subagent (TO BE MODIFIED)
│   ├── vbw-team.md              # Team generation
│   ├── vbw-validate.md          # Validation generation
│   ├── vbw-advocate.md          # Devil's advocate
│   ├── vbw-deps.md              # Dependency resolution
│   └── vbw-report.md            # Report aggregation
├── settings/
│   └── vbw.json                 # Configuration
└── docs/
    └── 26-01-20_vbw-targeted-reflection-playbook.md  # THIS FILE
```

### Files to Modify in This Playbook

| File | Purpose | Modification |
|------|---------|--------------|
| `commands/vbw-execute.md` | Execution subagent | Add Failure Diagnosis Protocol section |
| `commands/vbw-implement.md` | Orchestrator | Add diagnosis requirement for subagent |
| `settings/vbw-error-patterns-{lang}.json` | NEW | Language-specific error pattern files (python, typescript, go) |

### Installation Paths (Post-Install)

When installed via `npx github:DavidKinter/vbw-claude --local`:

```
target-project/
└── .claude/
    ├── commands/           # Commands copied here
    │   ├── vbw-implement.md
    │   ├── vbw-execute.md
    │   └── ...
    └── settings/           # Settings copied here
        └── vbw.json
```

---

## Phase 0: Baseline Measurement

**Goal**: Establish current iteration patterns before changes
**Time**: ~1 hour
**Prerequisites**: Working VBW implementation in a test project

### Step 0.1: Define Test Task Suite

Create a standard set of tasks that represent typical VBW usage:

```markdown
## Baseline Test Suite

### Task 1: Dockerfile Modification (Single File)
- Add health check to Dockerfile
- Expected iterations: 1-3

### Task 2: Python Service (Import Dependencies)
- Create new helper function with imports
- Expected iterations: 2-4

### Task 3: Test File (Fixture Dependencies)
- Add new pytest test with fixtures
- Expected iterations: 2-5

### Task 4: Multi-File Change (Dependencies)
- Add router endpoint + test
- Expected iterations: 3-6

### Task 5: Configuration Change (Validation-Heavy)
- Update compose.yml with new service
- Expected iterations: 2-4
```

### Step 0.2: Run Baseline Tests

**Prompt for baseline measurement**:

```
═══════════════════════════════════════════════════════════════════════════════
TASK: Run VBW baseline measurement for targeted reflection evaluation

INSTRUCTIONS:
1. For each task in the test suite:
   a. Run /vbw-implement with the task description
   b. Record: iterations, failure types, time to pass
   c. Do NOT implement any diagnosis features yet
2. Document all results in baseline table

OUTPUT FORMAT:
## Baseline Results

| Task | Iterations | Failure Types | Time (min) | Final Status |
|------|------------|---------------|------------|--------------|
| 1. Dockerfile | 2 | BuildError | 3 | PASS |
| 2. Python Service | 4 | ImportError, SyntaxError | 8 | PASS |
| ... | ... | ... | ... | ... |

### Failure Pattern Analysis
- ImportError: X occurrences
- SyntaxError: Y occurrences
- AssertionError: Z occurrences
- BuildError: W occurrences

### Iteration Statistics
- Mean: X.X iterations
- Median: X iterations
- Max: X iterations
- Mode failure type: [type]
═══════════════════════════════════════════════════════════════════════════════
```

### Step 0.3: Document Baseline

**File**: `docs/vbw-reflection-baseline.md`

```markdown
# VBW Targeted Reflection Baseline Measurement

**Date**: {date}
**VBW Version**: Pre-reflection

## Test Results

| Task | Iterations | Failure Types | Notes |
|------|------------|---------------|-------|
| ... | ... | ... | ... |

## Statistics

- **Mean iterations**: X.X
- **Median iterations**: X
- **Max iterations**: X
- **Mode failure type**: ImportError (40%)

## Failure Type Distribution

| Type | Count | Percentage |
|------|-------|------------|
| ImportError | X | X% |
| SyntaxError | X | X% |
| AssertionError | X | X% |
| BuildError | X | X% |
| Other | X | X% |
```

### Phase 0 Checkpoint

| Step | Status | Evidence |
|------|--------|----------|
| 0.1 Test suite defined | [ ] PASS / [ ] FAIL | 5 tasks documented |
| 0.2 Baseline tests run | [ ] PASS / [ ] FAIL | All tasks executed |
| 0.3 Baseline documented | [ ] PASS / [ ] FAIL | Statistics calculated |

**Gate**: Baseline complete before Phase 1

---

## Phase 1: Diagnosis Protocol Design

**Goal**: Design structured error classification and fix strategies
**Time**: ~45 minutes

### Step 1.1: Define Error Type Taxonomy

```markdown
## Error Type Taxonomy

### Level 1: Python Errors
```
ImportError
├── ModuleNotFoundError    → Module doesn't exist or wrong path
├── ImportError (circular) → Circular import detected
└── ImportError (name)     → Name not exported from module

SyntaxError
├── IndentationError       → Wrong indentation
├── TabError               → Mixed tabs/spaces
└── SyntaxError (general)  → Invalid Python syntax

NameError
├── NameError (undefined)  → Variable not defined
└── NameError (scope)      → Variable not in scope

TypeError
├── TypeError (args)       → Wrong number of arguments
├── TypeError (type)       → Wrong type passed
└── TypeError (callable)   → Object not callable

AssertionError
├── AssertionError (value) → Expected != actual
└── AssertionError (type)  → Type mismatch in assertion
```

### Level 2: Test Errors
```
FixtureError
├── fixture 'X' not found  → Fixture missing from conftest.py
├── ScopeMismatch          → Fixture scope incompatible
└── SetupError             → Fixture setup failed

CollectionError
├── ImportError            → Test file has import error
├── SyntaxError            → Test file has syntax error
└── NoTestsFound           → No test_ functions found
```

### Level 3: Build Errors
```
DockerBuildError
├── SyntaxError            → Dockerfile syntax invalid
├── StageNotFound          → --target stage doesn't exist
├── BaseImageError         → FROM image not found
└── COPYError              → Source file not found

ComposeError
├── SyntaxError            → YAML syntax invalid
├── ServiceNotFound        → Referenced service doesn't exist
├── PortConflict           → Port already in use
└── VolumeError            → Volume path invalid
```
```

### Step 1.2: Define Fix Strategies

**Prompt**:

```
═══════════════════════════════════════════════════════════════════════════════
TASK: Create fix strategy lookup table for VBW diagnosis

FOR EACH error type in taxonomy, define:
1. Pattern: Regex or string match to identify this error
2. Root Cause: What typically causes this error
3. Fix Strategy: Specific action to take
4. Example: Concrete before/after

OUTPUT FORMAT:
## Fix Strategy Reference

### ImportError: ModuleNotFoundError

**Pattern**: `ModuleNotFoundError: No module named '(\w+)'`

**Root Cause**:
- Module not installed (external dependency)
- Wrong import path (internal module)
- Typo in module name

**Fix Strategy**:
1. Check if module is in pyproject.toml/requirements.txt
2. If external: verify package is installed
3. If internal: verify file exists at expected path
4. Check for typos in module name

**Example**:
```python
# ERROR: ModuleNotFoundError: No module named 'src.services.ai'
# DIAGNOSIS: Internal module, check path

# BEFORE (wrong):
from src.services.ai import MyService

# AFTER (correct):
from src.services.my_service import MyService
```

[Continue for each error type...]
═══════════════════════════════════════════════════════════════════════════════
```

### Step 1.3: Design Diagnosis Prompt Section

This section will be added to `commands/vbw-execute.md`:

```markdown
## Failure Diagnosis Protocol (REQUIRED on validation failure)

When ANY validation fails, perform diagnosis BEFORE retrying:

### Step 1: Parse Error Message
```
Extract from validation output:
- Error type (first line, e.g., "ImportError", "SyntaxError")
- Error message (description after colon)
- Location (file:line if present)
- Context (surrounding lines if shown)
```

### Step 2: Classify Failure Type
```
Match against known patterns:

| Pattern | Type | Fix Strategy |
|---------|------|--------------|
| `ModuleNotFoundError: No module named '(\w+)'` | ImportError | Check import path |
| `cannot import name '(\w+)' from '(\w+)'` | ImportError | Verify export exists |
| `IndentationError` | SyntaxError | Fix indentation |
| `expected an indented block` | SyntaxError | Add indentation |
| `fixture '(\w+)' not found` | FixtureError | Add fixture or fix name |
| `assert .* == .*` | AssertionError | Check expected value |
| `Successfully built` NOT in output | BuildError | Check Dockerfile syntax |
```

### Step 3: Generate Fix Hypothesis
```
Based on classification:
1. State the diagnosed problem in one sentence
2. State the specific fix to attempt
3. State what will be different in the retry

Format:
DIAGNOSIS: [error type] - [specific cause]
FIX: [concrete action]
VERIFICATION: [how to confirm fix worked]
```

### Step 4: Apply Fix and Retry
```
1. Make the diagnosed change
2. Run: git add -A && git commit -m "VBW: Iter N - [diagnosis summary]"
3. Re-run validation
4. If still fails: new diagnosis (max 5 iterations total)
```

### CONSTRAINTS
- NEVER skip validation based on diagnosis
- NEVER retry with identical code
- ALWAYS document diagnosis in commit message
- If diagnosis is uncertain, state: "UNCERTAIN: trying [approach]"
```

### Phase 1 Checkpoint

| Step | Status | Evidence |
|------|--------|----------|
| 1.1 Error taxonomy | [ ] PASS / [ ] FAIL | All types categorized |
| 1.2 Fix strategies | [ ] PASS / [ ] FAIL | Strategy per error type |
| 1.3 Diagnosis prompt | [ ] PASS / [ ] FAIL | Protocol section drafted |

**Gate**: Protocol design complete before Phase 2

---

## Phase 2: Implementation

**Goal**: Add diagnosis protocol to vbw-execute.md
**Time**: ~30 minutes

### Step 2.1: Update commands/vbw-execute.md

**File**: `commands/vbw-execute.md`

**Add after "## Workflow" section**:

```markdown
## Failure Diagnosis Protocol

When validation fails, diagnose BEFORE retrying:

### Diagnosis Steps

1. **Parse Error**: Extract error type, message, and location
2. **Classify**: Match against known patterns (see Error Pattern Reference)
3. **Hypothesize**: State diagnosis and planned fix
4. **Apply**: Make specific change based on diagnosis
5. **Retry**: Re-run validation

### Error Pattern Reference

| Error Pattern | Type | Fix Strategy |
|---------------|------|--------------|
| `ModuleNotFoundError: No module named` | Import | Check path, verify file exists |
| `cannot import name .* from` | Import | Verify name is exported |
| `IndentationError` | Syntax | Fix indentation level |
| `SyntaxError: invalid syntax` | Syntax | Check for typos, missing colons |
| `fixture '.*' not found` | Test | Add fixture or fix fixture name |
| `AssertionError: assert` | Test | Check expected vs actual values |
| `docker build` fails | Build | Check Dockerfile syntax and paths |
| `yaml.scanner.ScannerError` | Config | Fix YAML indentation/syntax |

### Diagnosis Commit Message Format

```
VBW: Iter N - [DIAGNOSIS] [fix summary]

Examples:
- VBW: Iter 2 - [ImportError] Fixed module path src.services.pantry_ai
- VBW: Iter 3 - [SyntaxError] Added missing colon after function def
- VBW: Iter 4 - [FixtureError] Changed test_user to auth_headers fixture
```

### Constraints

- Diagnosis is ADVISORY - validation remains the authority
- NEVER skip validation based on diagnosis interpretation
- NEVER retry with identical code (diagnosis must produce change)
- If uncertain: state "UNCERTAIN" and try most likely fix
```

**Validation**:
```bash
# Verify section added (run from vbw-claude root)
grep -c "Failure Diagnosis Protocol" commands/vbw-execute.md
# Expected: 1

# Verify error patterns present
grep -c "ModuleNotFoundError" commands/vbw-execute.md
# Expected: ≥ 1
```

### Step 2.2: Add Error Pattern Reference File

**File**: `settings/vbw-error-patterns-python.json` (and other language-specific files)

> **Note**: Error patterns are now language-specific. See `settings/vbw-error-patterns-{lang}.json` for python, typescript, go.

```json
{
  "version": "1.0.0",
  "error_patterns": [
    {
      "id": "import_module_not_found",
      "pattern": "ModuleNotFoundError: No module named '([^']+)'",
      "type": "ImportError",
      "severity": "blocking",
      "fix_strategy": "Check import path, verify module file exists at expected location",
      "common_causes": [
        "Typo in module name",
        "Wrong directory structure",
        "Missing __init__.py"
      ]
    },
    {
      "id": "import_name_not_found",
      "pattern": "cannot import name '([^']+)' from '([^']+)'",
      "type": "ImportError",
      "severity": "blocking",
      "fix_strategy": "Verify the name is actually exported from the module",
      "common_causes": [
        "Function/class renamed",
        "Name not exported in __all__",
        "Circular import"
      ]
    },
    {
      "id": "syntax_indentation",
      "pattern": "IndentationError",
      "type": "SyntaxError",
      "severity": "blocking",
      "fix_strategy": "Fix indentation to match surrounding code (4 spaces per level)",
      "common_causes": [
        "Mixed tabs and spaces",
        "Wrong nesting level",
        "Missing indent after colon"
      ]
    },
    {
      "id": "syntax_general",
      "pattern": "SyntaxError: invalid syntax",
      "type": "SyntaxError",
      "severity": "blocking",
      "fix_strategy": "Check line for typos, missing colons, unmatched brackets",
      "common_causes": [
        "Missing colon after def/if/for",
        "Unmatched parentheses/brackets",
        "Invalid character"
      ]
    },
    {
      "id": "test_fixture_not_found",
      "pattern": "fixture '([^']+)' not found",
      "type": "FixtureError",
      "severity": "blocking",
      "fix_strategy": "Add fixture to conftest.py or use existing fixture name",
      "common_causes": [
        "Fixture name typo",
        "Fixture not in conftest.py",
        "Fixture scope mismatch"
      ]
    },
    {
      "id": "test_assertion_value",
      "pattern": "AssertionError: assert .* == ",
      "type": "AssertionError",
      "severity": "blocking",
      "fix_strategy": "Compare expected vs actual values, check for off-by-one or type differences",
      "common_causes": [
        "Wrong expected value",
        "Type mismatch (str vs int)",
        "Floating point precision"
      ]
    },
    {
      "id": "docker_build_fail",
      "pattern": "ERROR.*Dockerfile",
      "type": "BuildError",
      "severity": "blocking",
      "fix_strategy": "Check Dockerfile syntax, verify COPY source files exist",
      "common_causes": [
        "Invalid instruction",
        "Missing FROM",
        "COPY source not in context"
      ]
    },
    {
      "id": "yaml_syntax",
      "pattern": "yaml\\.scanner\\.ScannerError",
      "type": "ConfigError",
      "severity": "blocking",
      "fix_strategy": "Fix YAML indentation (2 spaces), check for tab characters",
      "common_causes": [
        "Tab instead of spaces",
        "Wrong indentation level",
        "Missing dash for list items"
      ]
    }
  ]
}
```

**Validation**:
```bash
# Verify valid JSON (run from vbw-claude root)
python -c "import json; json.load(open('settings/vbw-error-patterns.json'))"
# Expected: No output (valid JSON)

# Count patterns
python -c "import json; print(len(json.load(open('settings/vbw-error-patterns.json'))['error_patterns']))"
# Expected: 8 (or more)
```

### Step 2.3: Update commands/vbw-implement.md Orchestration

**File**: `commands/vbw-implement.md`

**Add to "Tool Restrictions for Execution Subagent" section**:

```markdown
### Diagnosis Requirements

When spawning vbw-execute subagent, include in prompt:

```
DIAGNOSIS PROTOCOL ENABLED:
On validation failure, subagent MUST:
1. Parse error message
2. Classify against known patterns
3. State diagnosis in commit message
4. Apply targeted fix
5. Never retry with identical code
```
```

**Validation**:
```bash
grep -c "DIAGNOSIS PROTOCOL" commands/vbw-implement.md
# Expected: ≥ 1
```

### Step 2.4: Update bin/install.js (if needed)

Ensure the installer copies `settings/vbw-error-patterns.json` to target project:

**Check current install script**:
```bash
grep -A5 "settings" bin/install.js
```

**If not already copying settings directory, add**:
```javascript
// Copy settings directory
const settingsSource = path.join(__dirname, '..', 'settings');
const settingsTarget = path.join(targetDir, 'settings');
fs.cpSync(settingsSource, settingsTarget, { recursive: true });
```

### Phase 2 Checkpoint

| Step | Status | Evidence |
|------|--------|----------|
| 2.1 vbw-execute.md updated | [ ] PASS / [ ] FAIL | Diagnosis section present |
| 2.2 Error patterns file | [ ] PASS / [ ] FAIL | Valid JSON, 8+ patterns |
| 2.3 vbw-implement.md updated | [ ] PASS / [ ] FAIL | Protocol reference added |
| 2.4 Installer updated | [ ] PASS / [ ] FAIL | Settings copied on install |

**Gate**: Implementation complete before Phase 3

---

## Phase 3: Testing

**Goal**: Run test suite with diagnosis enabled, compare to baseline
**Time**: ~1-2 hours

### Step 3.1: Install Updated VBW to Test Project

```bash
# From test project directory
npx github:DavidKinter/vbw-claude --local

# Or if testing locally before push:
node ./vbw-claude/bin/install.js --local
```

### Step 3.2: Run Test Suite with Diagnosis

**Prompt**:

```
═══════════════════════════════════════════════════════════════════════════════
TASK: Run VBW test suite WITH targeted reflection enabled

INSTRUCTIONS:
1. For each task in the baseline test suite:
   a. Run /vbw-implement with the task description
   b. Verify diagnosis appears in commit messages
   c. Record: iterations, failure types, diagnosis accuracy
2. Document all results

OUTPUT FORMAT:
## Test Results (With Diagnosis)

| Task | Iterations | Baseline | Diagnosis Used | Diagnosis Accurate |
|------|------------|----------|----------------|-------------------|
| 1. Dockerfile | 1 | 2 | Yes (BuildError) | Yes |
| 2. Python Service | 3 | 4 | Yes (ImportError x2) | Yes (2/2) |
| ... | ... | ... | ... | ... |

### Diagnosis Accuracy Log

| Task | Iteration | Error | Diagnosis | Correct? | Notes |
|------|-----------|-------|-----------|----------|-------|
| 2 | 1 | ImportError | Wrong path | Yes | Fixed on first retry |
| 2 | 2 | ImportError | Name not exported | Yes | Fixed on first retry |
| ... | ... | ... | ... | ... | ... |

### Comparison Summary
- Baseline mean iterations: X.X
- With diagnosis mean iterations: Y.Y
- Improvement: Z%
- Diagnosis accuracy: W%
═══════════════════════════════════════════════════════════════════════════════
```

### Step 3.3: Verify Diagnosis in Commits

```bash
# Check shadow project git log for diagnosis patterns
git -C /tmp/vbw-shadow log --oneline | grep -E '\[(Import|Syntax|Fixture|Assertion|Build|Config)Error\]'

# Count diagnosis commits
git -C /tmp/vbw-shadow log --oneline | grep -c '\[.*Error\]'
```

**Expected**: Majority of retry commits include diagnosis tag

### Step 3.4: Document Test Results

**File**: `docs/vbw-reflection-test-results.md`

```markdown
# VBW Targeted Reflection Test Results

**Date**: {date}
**VBW Version**: With diagnosis

## Test Results

| Task | Baseline | With Diagnosis | Improvement |
|------|----------|----------------|-------------|
| 1 | 2 | 1 | -1 (50%) |
| 2 | 4 | 3 | -1 (25%) |
| ... | ... | ... | ... |

## Statistics Comparison

| Metric | Baseline | With Diagnosis | Change |
|--------|----------|----------------|--------|
| Mean iterations | X.X | Y.Y | -Z% |
| Median iterations | X | Y | -Z |
| Max iterations | X | Y | -Z |
| Total failures | X | Y | -Z% |

## Diagnosis Accuracy

| Error Type | Correct | Incorrect | Accuracy |
|------------|---------|-----------|----------|
| ImportError | X | Y | Z% |
| SyntaxError | X | Y | Z% |
| ... | ... | ... | ... |

## Conclusion

[To be filled based on results]
```

### Phase 3 Checkpoint

| Step | Status | Evidence |
|------|--------|----------|
| 3.1 VBW installed | [ ] PASS / [ ] FAIL | Commands in .claude/commands/ |
| 3.2 Test suite run | [ ] PASS / [ ] FAIL | All tasks executed |
| 3.3 Diagnosis in commits | [ ] PASS / [ ] FAIL | Tags present |
| 3.4 Results documented | [ ] PASS / [ ] FAIL | Comparison complete |

**Gate**: Testing complete before Phase 4

---

## Phase 4: Evaluation & Decision

**Goal**: Decide whether to keep, modify, or remove diagnosis feature
**Time**: ~30 minutes

### Step 4.1: Calculate Improvement

```markdown
## Improvement Calculation

### Iteration Reduction
Baseline mean: X.X
With diagnosis mean: Y.Y
Reduction: (X.X - Y.Y) / X.X * 100 = Z%

### Token Overhead Estimate
Diagnosis adds ~200 tokens per failed iteration
Average failed iterations: N
Additional tokens per task: N * 200 = M tokens
Baseline tokens per task: ~5000
Overhead: M / 5000 * 100 = P%

### Cost-Benefit
If Z% ≥ 20% AND P% < 30%: KEEP
If Z% < 20% OR P% > 30%: EVALUATE further
If Z% < 10%: REMOVE
```

### Step 4.2: Decision Matrix

| Metric | Threshold | Actual | Pass? |
|--------|-----------|--------|-------|
| Iteration reduction | ≥ 20% | ? | ? |
| Token overhead | < 30% | ? | ? |
| Diagnosis accuracy | ≥ 70% | ? | ? |
| Zero validation bypasses | 0 | ? | ? |

### Step 4.3: Final Decision

**Prompt**:

```
═══════════════════════════════════════════════════════════════════════════════
TASK: Make final decision on VBW Targeted Reflection

INPUT: Test results from Phase 3

DECISION TREE:
1. If iteration reduction ≥ 20% AND accuracy ≥ 70%:
   → KEEP: Feature provides measurable value

2. If iteration reduction 10-20% AND accuracy ≥ 70%:
   → MODIFY: Refine error patterns, retest

3. If iteration reduction < 10% OR accuracy < 70%:
   → REMOVE: Feature doesn't justify complexity

4. If ANY validation bypasses occurred:
   → REMOVE: Safety violation

OUTPUT:
## Decision: [KEEP / MODIFY / REMOVE]

### Rationale
[2-3 sentences explaining decision]

### If KEEP:
- Tag release with "v1.1.0-reflection"
- Update README with new feature
- Consider expanding error patterns

### If MODIFY:
- Specific changes needed
- Timeline for retest

### If REMOVE:
- Revert commands/vbw-execute.md
- Delete settings/vbw-error-patterns.json
- Document learnings in docs/
═══════════════════════════════════════════════════════════════════════════════
```

### Phase 4 Checkpoint

| Step | Status | Evidence |
|------|--------|----------|
| 4.1 Improvement calculated | [ ] PASS / [ ] FAIL | Metrics computed |
| 4.2 Decision matrix | [ ] PASS / [ ] FAIL | All thresholds checked |
| 4.3 Final decision | [ ] PASS / [ ] FAIL | Decision documented |

**Gate**: Decision made and documented

---

## Troubleshooting

### Diagnosis Doesn't Appear in Commits

**Symptom**: Git log shows "VBW: Iter N" without diagnosis tag

**Cause**: Subagent not following diagnosis protocol

**Fix**:
1. Verify `commands/vbw-execute.md` has diagnosis section
2. Verify `commands/vbw-implement.md` includes DIAGNOSIS PROTOCOL in subagent prompt
3. Re-run with explicit prompt

### Diagnosis is Incorrect

**Symptom**: Diagnosis says "ImportError" but actual error is different

**Cause**: Pattern matching failed or error message unusual

**Fix**:
1. Add new pattern to `settings/vbw-error-patterns.json`
2. Update pattern regex to handle variation
3. Document edge case

### Same Code Retried Despite Diagnosis

**Symptom**: Iteration N and N+1 have identical code

**Cause**: Diagnosis produced but fix not applied

**Fix**: Strengthen constraint in `commands/vbw-execute.md`:
```
CONSTRAINT: If diagnosis produces no code change, report:
"DIAGNOSIS BLOCKED: Unable to determine fix for [error type]"
and request user intervention
```

### Validation Bypassed

**Symptom**: PASS reported but validation command would have failed

**Cause**: Critical safety violation - diagnosis overrode validation

**Fix**:
1. IMMEDIATELY revert feature
2. Analyze logs to understand how bypass occurred
3. Add explicit constraint: "NEVER mark PASS without running validation command"
4. Consider if feature should be abandoned

### Token Usage Excessive

**Symptom**: Task uses 2x+ expected tokens

**Cause**: Diagnosis prompts too verbose or many iterations

**Fix**:
1. Shorten diagnosis output format
2. Add hard iteration cap with "FAIL - max iterations"
3. Consider diagnosis only after iteration 2 (not first failure)

### Settings Not Copied on Install

**Symptom**: `vbw-error-patterns.json` missing after install

**Cause**: `bin/install.js` doesn't copy settings directory

**Fix**: Update install script to include settings:
```javascript
// In bin/install.js
const settingsFiles = ['vbw.json', 'vbw-error-patterns.json'];
for (const file of settingsFiles) {
    fs.copyFileSync(
        path.join(__dirname, '..', 'settings', file),
        path.join(targetDir, 'settings', file)
    );
}
```

---

## Error Pattern Reference

### Quick Lookup Table

| Error Message Contains | Type | First Fix to Try |
|------------------------|------|------------------|
| `No module named` | ImportError | Check file path |
| `cannot import name` | ImportError | Check export name |
| `IndentationError` | SyntaxError | Fix indentation |
| `SyntaxError: invalid syntax` | SyntaxError | Look for typos |
| `fixture '.*' not found` | FixtureError | Check conftest.py |
| `AssertionError` | AssertionError | Check expected value |
| `docker build` + error | BuildError | Check Dockerfile |
| `yaml` + error | ConfigError | Check YAML indentation |

### Pattern Regex Reference

```python
PATTERNS = {
    "import_module": r"ModuleNotFoundError: No module named '([^']+)'",
    "import_name": r"cannot import name '([^']+)' from '([^']+)'",
    "syntax_indent": r"IndentationError",
    "syntax_general": r"SyntaxError: invalid syntax",
    "fixture_missing": r"fixture '([^']+)' not found",
    "assertion_value": r"AssertionError: assert .* == ",
    "docker_fail": r"ERROR.*Dockerfile",
    "yaml_fail": r"yaml\.scanner\.ScannerError",
}
```

### Adding New Patterns

When encountering an unrecognized error:

1. Extract the error message
2. Identify the distinguishing pattern
3. Add to `settings/vbw-error-patterns.json`:

```json
{
  "id": "new_error_type",
  "pattern": "regex pattern here",
  "type": "ErrorCategory",
  "severity": "blocking",
  "fix_strategy": "Description of fix approach",
  "common_causes": ["cause 1", "cause 2"]
}
```

4. Test by triggering the error and verifying diagnosis

---

## Success Criteria Summary

VBW Targeted Reflection is COMPLETE when:

| Phase | Criteria | Status |
|-------|----------|--------|
| 0 | Baseline measured | [ ] |
| 1 | Protocol designed | [ ] |
| 2 | Implementation complete | [ ] |
| 3 | Testing complete | [ ] |
| 4 | Decision made | [ ] |

### Final Gate: Feature Evaluation

| Metric | Required | Actual | Pass? |
|--------|----------|--------|-------|
| Iteration reduction | ≥ 20% | | |
| Token overhead | < 30% | | |
| Diagnosis accuracy | ≥ 70% | | |
| Validation bypasses | 0 | | |

---

## References

- `commands/vbw-execute.md` - Execution subagent (to be modified)
- `commands/vbw-implement.md` - Orchestrator (to be modified)
- `settings/vbw.json` - Existing VBW configuration
- `README.md` - Project overview and installation
- VBW Framework Design documentation
