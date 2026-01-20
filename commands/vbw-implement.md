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
│  4. COMMIT PHASE                                                │
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

**Step 1.5: User Approval**
- Present complete action plan to user
- Format as table with files, validations, expected outputs
- WAIT for explicit user approval before proceeding

### Phase 2: Execution (Shadow Context)

**Step 2.1: Shadow Sync**
```bash
./utils/vbw_shadow_sync.sh
```
- Creates /tmp/vbw-shadow/ with rsync
- Initializes fresh git repo
- Confirms initial commit

**Step 2.2: Spawn Execution Subagent**
- Use Task tool with vbw-execute prompt
- Include:
  - Task description
  - Files to modify (in dependency order)
  - Validation commands with expected outputs
  - Tool restrictions (see below)
- WAIT for subagent to return result

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

### Phase 4: Commit

**Step 4.1: Copy Validated Files**
```bash
cp /tmp/vbw-shadow/{file} {real_path}
```
- Only copy files that passed validation
- Preserve file permissions

**Step 4.2: Cleanup (Optional)**
```bash
rm -rf /tmp/vbw-shadow
```

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

- NEVER proceed without user approval at each gate
- NEVER skip validation steps
- NEVER report PASS without string match confirmation
- ALWAYS enforce tool restrictions on subagent
- ALWAYS enforce directory constraints on subagent
