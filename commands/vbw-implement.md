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
│  2. EXECUTION PHASE (Sandbox Context)                            │
│     ┌──────────────┐                                            │
│     │ Sandbox Sync  │ → rsync project to /tmp/vbw-sandbox/        │
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
│     │ Copy Files   │ → cp from sandbox to real codebase          │
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
- Sandbox-only operations → Reversible
- External writes (push, deploy, DB) → Not reversible (should not be in validation anyway)

Output: Completed "Expected Worst Case" table for action plan

**Step 1.6: User Approval**
- Present complete action plan to user
- Format as table with files, validations, expected outputs, worst case
- WAIT for explicit user approval before proceeding

### Phase 2: Execution (Sandbox Context)

**Step 2.1: Sandbox Sync**
```bash
.claude/utils/vbw_sandbox_sync.sh
```
- Creates /tmp/vbw-sandbox/ with rsync
- Initializes fresh git repo
- Confirms initial commit

**Step 2.2: Enable Execution Gate**
```bash
touch /tmp/vbw-sandbox/.vbw-gate-required
> /tmp/vbw-sandbox/.vbw-execution-log
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
echo "CMD: <command>" >> /tmp/vbw-sandbox/.vbw-execution-log

# Then run the command
<command>
```

Example:
```bash
echo "CMD: docker build -t test ." >> /tmp/vbw-sandbox/.vbw-execution-log
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

### Phase 3.5: Live API Validation (Hook-Enforced — API Tasks Only)

**Enforcement:** This phase is enforced by the `vbw-live-api-gate.sh`
Stop hook. If the orchestrator creates the endpoints marker file but
does not complete validation, Claude CANNOT finish the session.

**When to activate:** After sandbox execution completes, scan the
sandbox code for API integration indicators:
- HTTP client imports (`import requests`, `import httpx`, `import aiohttp`)
- HTTP mocking decorators (`@responses.activate`, `httpretty`, `@patch`)
- URL string constants matching `https?://` patterns (excluding localhost)

If ANY indicator is present, create the marker file:
```bash
# Write endpoints to validate (one per line: METHOD URL EXPECTED_KEYS)
cat > /tmp/vbw-sandbox/.vbw-live-validation-endpoints << 'ENDPOINTS'
GET https://example.com/api/endpoint key1,key2,key3
POST https://other.com/api/data totalCount,items
ENDPOINTS
```

**When to skip:** If NO indicators are present, do NOT create the marker
file. The hook will allow the Stop event without validation.

**Step 3.5.1: Extract Endpoints**
From the sandbox implementation code, identify:
- The API endpoint URL(s) being called
- The HTTP method (GET/POST)
- Required headers and authentication (read from project .env)
- Expected response structure (from mocked test data)

**Step 3.5.2: Make Live API Call**
From the ORCHESTRATOR context (not the sandbox), make ONE real HTTP
request to each identified endpoint. Use the minimum parameters needed
to get a valid response (e.g., page_size=1, limit=1).
```bash
uv run python -c "
import requests, json, os, sys, time, random
from dotenv import load_dotenv; load_dotenv()

# --- Status code classification (RFC 9110) ---
ABSENT_CODES = {404, 410, 405, 501}       # Endpoint does not exist (hard fail)
CONFIRMED_CODES = {400, 401, 403, 409, 415, 422}  # Endpoint exists, request rejected
RETRYABLE_CODES = {408, 429, 500, 502, 503, 504}  # Transient, retry with backoff

def classify_response(resp):
    # Cloudflare challenge detection (Cloudflare, 2026)
    cf_mitigated = resp.headers.get('cf-mitigated', '')
    if cf_mitigated.lower() == 'challenge':
        return 'TRANSIENT'  # Cloudflare challenge, not a real API response
    # Content-Type interception detection
    content_type = resp.headers.get('content-type', '')
    if 'text/html' in content_type and resp.status_code != 200:
        return 'TRANSIENT'  # Likely CDN/proxy HTML error page, not API
    # RFC 9110 classification
    if 200 <= resp.status_code < 400:
        return 'SUCCESS'
    if resp.status_code in ABSENT_CODES:
        return 'ABSENT'
    if resp.status_code in CONFIRMED_CODES:
        return 'CONFIRMED'
    if resp.status_code in RETRYABLE_CODES:
        return 'TRANSIENT'
    return 'TRANSIENT'  # Unknown codes default to transient

def make_request_with_retry(method, url, max_retries=3):
    headers = {'Accept': 'application/json', 'User-Agent': 'VBW-Validator/1.1'}
    last_resp = None
    for attempt in range(max_retries + 1):
        try:
            if method == 'GET':
                resp = requests.get(url, headers=headers, timeout=15)
            else:
                resp = requests.post(url, json={}, headers=headers, timeout=15)
            classification = classify_response(resp)
            if classification != 'TRANSIENT' or attempt == max_retries:
                return resp, classification
            # Honour Retry-After if present and reasonable
            retry_after = resp.headers.get('Retry-After')
            if retry_after and retry_after.isdigit() and int(retry_after) <= 60:
                time.sleep(int(retry_after))
            else:
                # Exponential backoff with full jitter (AWS, 2019)
                delay = random.uniform(0, min(10, 1 * (2 ** attempt)))
                time.sleep(delay)
            last_resp = resp
        except (requests.ConnectionError, requests.Timeout) as e:
            if attempt == max_retries:
                return None, 'TRANSIENT'
            delay = random.uniform(0, min(10, 1 * (2 ** attempt)))
            time.sleep(delay)
    return last_resp, 'TRANSIENT'

# --- Main validation loop ---
endpoints = open('/tmp/vbw-sandbox/.vbw-live-validation-endpoints').read().strip().split('\n')
results = []

for line in endpoints:
    parts = line.split()
    method, url = parts[0], parts[1]
    expected_keys = set(parts[2].split(',')) if len(parts) > 2 else set()

    resp, classification = make_request_with_retry(method, url)

    if classification == 'ABSENT':
        verdict = 'MISMATCH'
        detail = f'HTTP {resp.status_code} — endpoint does not exist'
    elif classification == 'CONFIRMED':
        verdict = 'CONFIRMED'
        detail = f'HTTP {resp.status_code} — endpoint exists (request rejected)'
    elif classification == 'SUCCESS':
        try:
            actual_keys = set(resp.json().keys())
            if expected_keys and not expected_keys.issubset(actual_keys):
                verdict = 'MISMATCH'
                detail = f'expected {sorted(expected_keys)}, got {sorted(actual_keys)}'
            elif expected_keys:
                verdict = 'MATCH'
                detail = 'all expected keys present'
            else:
                verdict = 'PARTIAL'
                detail = 'no expected keys specified'
        except (json.JSONDecodeError, ValueError):
            verdict = 'MISMATCH'
            detail = 'response is not valid JSON'
    else:  # TRANSIENT after retries exhausted
        verdict = 'UNREACHABLE'
        status = resp.status_code if resp else 'N/A'
        detail = f'HTTP {status} after 3 retries — transient failure'

    status_code = resp.status_code if resp else 0
    results.append(f'{verdict} {url} {status_code}')
    print(f'{verdict}: {url} ({detail})')

with open('/tmp/vbw-sandbox/.vbw-live-validation-result', 'w') as f:
    f.write('\n'.join(results) + '\n')

print('LIVE_VALIDATION: COMPLETE')
"
```

**Step 3.5.3: Evaluate Results**
- **MATCH**: All expected keys present in live response → proceed to Phase 4
- **CONFIRMED**: Endpoint exists but rejected the request (401/403/400/422) →
  proceed to Phase 4. The endpoint is real; authentication or payload
  requirements prevent full validation but confabulated URLs are ruled out.
- **PARTIAL**: Response received but no expected keys specified → proceed with WARNING
- **MISMATCH**: Endpoint does not exist (404/410), expected keys not found in
  response, or response is not valid JSON → STOP and report discrepancy.
  The hook will BLOCK completion until mismatches are resolved.
- **UNREACHABLE**: API timeout, connection failure, or transient server error
  (5xx) after 3 retries → proceed with WARNING (soft fail on genuine
  transient unavailability only)

**Step 3.5.4: Include in Report**
Add the live validation result to the VBW Execution Report:
```markdown
### Live API Validation
| Endpoint | Status | Expected Keys | Actual Keys | Verdict |
|----------|--------|---------------|-------------|---------|
| {url}    | {code} | {expected}    | {actual}    | MATCH   |
```

If verdict is MISMATCH, include the full expected vs actual key comparison
and recommend specific fixes before proceeding.

### Phase 4: Commit (REQUIRES EXPLICIT APPROVAL)

**CRITICAL: MANDATORY APPROVAL GATE (Hook-Enforced)**

Before ANY file is copied from sandbox to project, you MUST:

1. Use the `AskUserQuestion` tool to request explicit approval
2. List every file that will be copied
3. Wait for user to select "Yes, copy to project"
4. If user declines or selects any other option, ABORT the copy entirely
5. **Only after approval**: Create the approval marker (see below)

```
REQUIRED: AskUserQuestion with:
- Question: "Copy validated files from sandbox to project?"
- Options:
  - "Yes, copy to project" (approval)
  - "No, keep in sandbox only" (reject)
  - "Show me the diffs first" (defer)
```

**Step 4.0: Create Approval Marker (ONLY after user selects "Yes")**

The PreToolUse hook (`vbw-copy-gate.sh`) blocks all copy operations from sandbox to project. The marker unlocks this gate.

```bash
# ONLY execute this if user selected "Yes, copy to project":
touch /tmp/vbw-sandbox/.vbw-copy-approved
```

**IMPORTANT**:
- Do NOT create this marker before AskUserQuestion
- Do NOT create this marker if user declines
- The hook will BLOCK any copy attempt without this marker

**Step 4.1: Copy Validated Files (ONLY after approval + marker)**
```bash
cp /tmp/vbw-sandbox/{file} {real_path}
```
- Only copy files that passed validation
- Preserve file permissions
- Copy will be BLOCKED by hook if marker is missing

**Step 4.2: Sandbox Cleanup (REQUIRES EXPLICIT APPROVAL)**

**CRITICAL: MANDATORY APPROVAL GATE**

After the copy decision is resolved (approved or declined), you MUST:

1. Use the `AskUserQuestion` tool to request explicit approval for sandbox removal
2. Wait for user to select an option
3. Only remove sandbox if user selects "Yes, remove sandbox"
4. If user declines, sandbox remains at `/tmp/vbw-sandbox/` for manual inspection

```
REQUIRED: AskUserQuestion with:
- Question: "Remove sandbox directory (/tmp/vbw-sandbox)?"
- Options:
  - "Yes, remove sandbox" (cleanup)
  - "No, keep sandbox for inspection" (preserve)
```

```bash
# Only execute if user approved removal:
rm -rf /tmp/vbw-sandbox
```

**Note:** Removing the sandbox directory also removes:
- `.vbw-gate-required` - deactivates execution gate for future sessions
- `.vbw-copy-approved` - clears copy approval for future sessions
- `.vbw-execution-log` - clears execution log
- `.vbw-live-validation-endpoints` - deactivates live API gate for future sessions
- `.vbw-live-validation-result` - clears validation results for future sessions

## Tool Restrictions for Execution Subagent

### ALLOWED Tools (Subagent)
- Bash (for running commands in sandbox)
- Write (for creating files in sandbox)
- Edit (for modifying files in sandbox)
- Read (for reading files in sandbox)

### DENIED Tools (Subagent)
- Grep (use `grep` via Bash instead)
- Glob (use `find` via Bash instead)
- Task (no nested subagents)
- WebFetch (no external requests)
- WebSearch (no external requests)
- LSP (not needed in sandbox)

### Directory Constraint
ALL file operations MUST target paths starting with `/tmp/vbw-sandbox/`

Before ANY Write/Edit/Read:
```
IF path does NOT start with "/tmp/vbw-sandbox/":
    STOP
    Report: "ERROR: Attempted operation outside sandbox directory"
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
| Reversible | Yes/No | {sandbox-only, or modifies external state} |

### Challenges Addressed
- {challenge from vbw-advocate}
- {how it was addressed}

### Live API Validation Required
- [ ] Yes — endpoints identified: {list of URLs}
- [ ] No — task does not involve external APIs

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

### Live API Validation (if applicable)
| Endpoint | Status | Verdict |
|----------|--------|---------|
| {url}    | {code} | MATCH/PARTIAL/MISMATCH/UNREACHABLE |

### Next Steps
- [ ] User approves copy to real codebase
- [ ] User requests changes
- [ ] User abandons task
```

## Constraints

- **NEVER copy files from sandbox to project without explicit AskUserQuestion approval**
- NEVER proceed without user approval at each gate
- NEVER skip validation steps
- NEVER report PASS without string match confirmation
- ALWAYS enforce tool restrictions on subagent
- ALWAYS enforce directory constraints on subagent
- ALWAYS use AskUserQuestion tool before Phase 4 copy operations
- If approval is denied, sandbox files remain in /tmp/vbw-sandbox/ for manual inspection
