# VBW Implement - Orchestrator

Implements a task using Validate-Before-Write protocol with full skill orchestration.

## Usage
/vbw-implement {task description}

## Skill Invocation Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                    VBW ORCHESTRATION FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PLANNING PHASE (Main Context)                               │
│     ┌──────────────┐                                            │
│     │ vbw-deps     │ → Analyze files, determine dependency order│
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ vbw-team     │ → Identify review roles for file types     │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ vbw-validate │ → Generate validation commands per role    │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ vbw-advocate │ → Challenge validations, expose gaps       │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ USER REVIEW  │ → Present action plan, get approval        │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│  2. EXECUTION PHASE (Shadow Context)                            │
│     ┌──────────────┐                                            │
│     │ Shadow Sync  │ → rsync project to /tmp/vbw-shadow/        │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ vbw-execute  │ → Implement changes, run validations       │
│     └──────┬───────┘   (SUBAGENT - restricted tools)            │
│            ▼                                                    │
│  3. REVIEW PHASE (Main Context)                                 │
│     ┌──────────────┐                                            │
│     │ vbw-report   │ → Aggregate results, generate report       │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│     ┌──────────────┐                                            │
│     │ USER REVIEW  │ → Present results, get approval to copy    │
│     └──────┬───────┘                                            │
│            ▼                                                    │
│  4. COMMIT PHASE (BLOCKED until approval)                       │
│     ┌──────────────┐                                            │
│     │ ASK USER     │ → AskUserQuestion: "Copy to project?"      │
│     └──────┬───────┘                                            │
│            ▼ (only if approved)                                 │
│     ┌──────────────┐                                            │
│     │ Copy Files   │ → cp from shadow to real codebase          │
│     └──────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Workflow

### Phase 1: Planning (Main Context)

**Step 1.1: Dependency Analysis**
- Read task description
- Identify files that will be created/modified
- Invoke vbw-deps mentally or via prompt
- Output: Ordered list of files by dependency layer

**Step 1.2: Team Assignment**
- Based on file types (Dockerfile, Python, YAML, etc.)
- Invoke vbw-team mentally or via prompt
- Output: List of roles (Platform Engineer, Security Engineer, etc.)

**Step 1.3: Validation Generation**
- For each role, generate validation commands
- Invoke vbw-validate for each role
- Output: Table of validations with expected outputs

**Step 1.4: Challenge Round**
- Present validations to vbw-advocate
- Incorporate feedback
- Output: Improved validation set

**Step 1.5: Worst-Case Estimation**

For each validation command, estimate resource impact using these heuristics:

| Command Type | Disk Estimate | Time Estimate | Network? |
|--------------|---------------|---------------|----------|
| `uv lock/sync` | ~50-200MB | 30s-2min | Yes |
| `npm install` | ~100MB-2GB | 30s-5min | Yes |
| `docker build` | ~100MB-2GB | 1-10min | Usually |
| `pytest/test` | Minimal | Varies by count | No |
| `cargo build` | ~500MB-2GB | 1-10min | Yes (first) |

Adjust based on project context:
- Read `package.json` to gauge dependency count
- Read `Dockerfile` to identify base image size
- Count test files for test duration estimate

Express as ranges with explanatory notes:
- "~300MB (node_modules, 47 dependencies)"
- "~3 min (docker build, python:3.11 base)"

Reversibility check:
- Shadow-only operations → Reversible
- External writes (push, deploy, DB) → Not reversible (should not be in validation anyway)

Output: Completed "Expected Worst Case" table for action plan

**Step 1.6: User Approval**
- Present complete action plan to user
- Format as table with files, validations, expected outputs, worst case
- WAIT for explicit user approval before proceeding

### Phase 2: Execution (Shadow Context)

**Step 2.1: Shadow Sync**
```bash
.claude/utils/vbw_shadow_sync.sh
```
- Creates /tmp/vbw-shadow/ with rsync
- Initializes fresh git repo
- Confirms initial commit

**Step 2.2: Enable Execution Gate**
```bash
touch /tmp/vbw-shadow/.vbw-gate-required
> /tmp/vbw-shadow/.vbw-execution-log
```
- Creates gate marker (activates Stop hook enforcement)
- Initializes empty execution log
- From this point, Claude CANNOT complete until execution is verified

**Step 2.3: Spawn Execution Subagent**
- Use Task tool with vbw-execute prompt
- Include:
  - Task description
  - Files to modify (in dependency order)
  - Validation commands with expected outputs
  - Tool restrictions (see below)
  - **Command logging requirement** (see below)
- WAIT for subagent to return result

**CRITICAL: Command Logging Requirement**

The subagent MUST log every Bash command to the execution log:

```bash
# Before EVERY Bash command, log it:
echo "CMD: <command>" >> /tmp/vbw-shadow/.vbw-execution-log

# Then run the command
<command>
```

Example:
```bash
echo "CMD: docker build -t test ." >> /tmp/vbw-shadow/.vbw-execution-log
docker build -t test .
```

This log is verified by the execution gate. If no execution commands (docker build, pytest, npm test, etc.) appear in the log, the gate will BLOCK completion.

**What counts as execution:**
- `docker build`, `docker-compose build`
- `pytest`, `npm test`, `cargo test`, `go test`
- `uv run`, `uv sync`

**What does NOT count (syntax only):**
- `python -m py_compile`
- `grep`, `rg`, pattern matching
- `yaml.safe_load`, `json.load`

### Phase 3: Review (Main Context)

**Step 3.1: Parse Subagent Result**
- Extract JSON report from subagent
- Verify all validations ran
- Check PASS/FAIL status

**Step 3.2: Aggregate Report**
- Use vbw-report format
- Include: files modified, validations passed/failed, commit hash

**Step 3.3: User Approval**
- Present results with file diffs
- WAIT for explicit user approval before copying

### Phase 4: Commit (REQUIRES EXPLICIT APPROVAL)

**CRITICAL: MANDATORY APPROVAL GATE (Hook-Enforced)**

Before ANY file is copied from shadow to project, you MUST:

1. Use the `AskUserQuestion` tool to request explicit approval
2. List every file that will be copied
3. Wait for user to select "Yes, copy to project"
4. If user declines or selects any other option, ABORT the copy entirely
5. **Only after approval**: Create the approval marker (see below)

```
REQUIRED: AskUserQuestion with:
- Question: "Copy validated files from shadow to project?"
- Options:
  - "Yes, copy to project" (approval)
  - "No, keep in shadow only" (reject)
  - "Show me the diffs first" (defer)
```

**Step 4.0: Create Approval Marker (ONLY after user selects "Yes")**

The PreToolUse hook (`vbw-copy-gate.sh`) blocks all copy operations from shadow to project. The marker unlocks this gate.

```bash
# ONLY execute this if user selected "Yes, copy to project":
touch /tmp/vbw-shadow/.vbw-copy-approved
```

**IMPORTANT**:
- Do NOT create this marker before AskUserQuestion
- Do NOT create this marker if user declines
- The hook will BLOCK any copy attempt without this marker

**Step 4.1: Copy Validated Files (ONLY after approval + marker)**
```bash
cp /tmp/vbw-shadow/{file} {real_path}
```
- Only copy files that passed validation
- Preserve file permissions
- Copy will be BLOCKED by hook if marker is missing

**Step 4.2: Shadow Cleanup (REQUIRES EXPLICIT APPROVAL)**

**CRITICAL: MANDATORY APPROVAL GATE**

After the copy decision is resolved (approved or declined), you MUST:

1. Use the `AskUserQuestion` tool to request explicit approval for shadow removal
2. Wait for user to select an option
3. Only remove shadow if user selects "Yes, remove shadow"
4. If user declines, shadow remains at `/tmp/vbw-shadow/` for manual inspection

```
REQUIRED: AskUserQuestion with:
- Question: "Remove shadow directory (/tmp/vbw-shadow)?"
- Options:
  - "Yes, remove shadow" (cleanup)
  - "No, keep shadow for inspection" (preserve)
```

```bash
# Only execute if user approved removal:
rm -rf /tmp/vbw-shadow
```

**Note:** Removing the shadow directory also removes:
- `.vbw-gate-required` - deactivates execution gate for future sessions
- `.vbw-copy-approved` - clears copy approval for future sessions
- `.vbw-execution-log` - clears execution log

## Tool Restrictions for Execution Subagent

### ALLOWED Tools (Subagent)
- Bash (for running commands in shadow)
- Write (for creating files in shadow)
- Edit (for modifying files in shadow)
- Read (for reading files in shadow)

### DENIED Tools (Subagent)
- Grep (use `grep` via Bash instead)
- Glob (use `find` via Bash instead)
- Task (no nested subagents)
- WebFetch (no external requests)
- WebSearch (no external requests)
- LSP (not needed in shadow)

### Directory Constraint
ALL file operations MUST target paths starting with `/tmp/vbw-shadow/`

Before ANY Write/Edit/Read:
```
IF path does NOT start with "/tmp/vbw-shadow/":
    STOP
    Report: "ERROR: Attempted operation outside shadow directory"
    FAIL immediately
```

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

## Action Plan Template

Present this to user for approval:

```markdown
## VBW Action Plan: {task_description}

### Files to Modify (Dependency Order)
| Layer | File | Action | Dependencies |
|-------|------|--------|--------------|
| 0 | {file} | create/modify | none |
| 1 | {file} | create/modify | Layer 0 |

### Validation Commands
| # | Role | Command | Expected Output |
|---|------|---------|-----------------|
| 1 | Platform | `{command}` | "{expected}" |
| 2 | Security | `{command}` | "{expected}" |

### Expected Worst Case
| Resource | Estimate | Notes |
|----------|----------|-------|
| Disk | ~{X}MB | {packages, docker layers, etc.} |
| Time | ~{X} min | {build, test, validation duration} |
| Network | Yes/No | {dependency fetches, docker pulls} |
| Reversible | Yes/No | {shadow-only, or modifies external state} |

### Challenges Addressed
- {challenge from vbw-advocate}
- {how it was addressed}

### Approval Required
- [ ] User approves action plan
- [ ] User approves to proceed with execution
```

## Report Template

Present this after execution:

```markdown
## VBW Execution Report: {task_description}

### Status: PASS / PARTIAL / FAIL

### Files Modified
| File | Status | Commit |
|------|--------|--------|
| {file} | ✓ / ✗ | {hash} |

### Validations
| # | Command | Expected | Actual | Pass |
|---|---------|----------|--------|------|
| 1 | `{cmd}` | "{exp}" | "{act}" | ✓/✗ |

### Next Steps
- [ ] User approves copy to real codebase
- [ ] User requests changes
- [ ] User abandons task
```

## Constraints

- **NEVER copy files from shadow to project without explicit AskUserQuestion approval**
- NEVER proceed without user approval at each gate
- NEVER skip validation steps
- NEVER report PASS without string match confirmation
- ALWAYS enforce tool restrictions on subagent
- ALWAYS enforce directory constraints on subagent
- ALWAYS use AskUserQuestion tool before Phase 4 copy operations
- If approval is denied, shadow files remain in /tmp/vbw-shadow/ for manual inspection
