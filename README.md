# vbw-claude

> ⚠️ **WARNING: This project is highly experimental and under active development. Expect breaking changes, bugs, and incomplete features. Not recommended for production use.**

![Status](https://img.shields.io/badge/status-experimental-orange)
![Stability](https://img.shields.io/badge/stability-unstable-red)

Validate-Before-Write framework for Claude Code. Builds, runs, and validates code in a sandbox—iterating until it works—before touching your real project.

## Why VBW?

### The Problem

Claude Code writes code—but often doesn't verify it actually works:

- Writes a Dockerfile but doesn't run `docker build`
- Adds imports but doesn't check if the module exists
- Creates tests but doesn't run `pytest`
- Generates code with syntax errors that only surface later

You end up debugging what Claude wrote.

### The Solution

VBW enforces **validation before commit**:

```
Write Code → Build It → Run Tests → Fix Errors → Repeat Until It Works
                                         ↑
                            (up to 5 automated iterations)
```

| Gap in Native Claude Code | VBW Solution |
|---------------------------|--------------|
| Writes Dockerfile, doesn't build | Runs `docker build`, iterates on errors |
| Adds imports, doesn't verify | Catches `ModuleNotFoundError`, fixes paths |
| Creates tests, doesn't run | Runs `pytest`, fixes assertion failures |
| Syntax errors go unnoticed | Compiler/interpreter catches them first |
| Dependency issues surface later | Diagnosed and resolved automatically |

**Result**: Code that lands in your project has been **built, run, and validated**—not just written.

### How It Stays Safe

```
┌─────────────────────────────────────────────────────────────────┐
│                         VBW WORKFLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Your Project                                                  │
│        │                                                        │
│        ▼ (rsync, secrets excluded)                              │
│   ┌─────────────┐                                               │
│   │   Shadow    │  ← All changes happen here first              │
│   │   /tmp/vbw- │                                               │
│   │   shadow/   │                                               │
│   └──────┬──────┘                                               │
│          │                                                      │
│          ▼                                                      │
│   ┌─────────────┐     ┌─────────────┐                           │
│   │  Implement  │────▶│  Validate   │──── PASS ───▶ User Review │
│   └─────────────┘     └──────┬──────┘                    │      │
│          ▲                   │                           ▼      │
│          │              FAIL │                    ┌───────────┐ │
│          │                   │                    │  Approve? │ │
│   ┌──────┴──────┐            │                    └─────┬─────┘ │
│   │  Diagnose   │◀───────────┘                          │       │
│   │  & Fix      │                                       ▼       │
│   └─────────────┘                             Your Project      │
│   (up to 5 iterations)                          Updated         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key Benefits**:
- ✅ **Actually runs your code** - Builds images, runs tests, compiles. Catches errors before they reach you.
- ✅ **Automatic retry** - Diagnoses failures and fixes them (up to 5 iterations)
- ✅ **Your project stays clean** - All iteration happens in shadow; only validated code is copied
- ✅ **Context isolation** - Execution runs in a subagent; error traces don't pollute your conversation
- ✅ **Secrets protected** - `.env`, `*.pem`, `*.key`, credentials never copied to shadow
- ✅ **Explicit approval** - You approve before anything touches your real codebase

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- Project using a supported language (see [Supported Languages](#supported-languages))
- Node.js 16+ (for installer)

## Install

```bash
# Recommended: Install with native enforcement hooks
npx github:DavidKinter/vbw-claude --local --with-hooks

# Or without hooks (commands only)
npx github:DavidKinter/vbw-claude --local

# Clone and run directly
git clone git@github.com:DavidKinter/vbw-claude.git
node vbw-claude/bin/install.js --local --with-hooks
```

| Flag | Description |
|------|-------------|
| `--local` | Install to current project's `.claude/` (default) |
| `--global` | Install to `~/.claude/` for all projects |
| `--with-hooks` | Install native enforcement hooks **(recommended)** |
| `--help` | Show installation options |

### What Gets Installed

| Directory | Contents | With `--with-hooks` |
|-----------|----------|---------------------|
| `.claude/commands/` | VBW slash commands | ✅ |
| `.claude/agents/` | vbw-execute subagent | ✅ |
| `.claude/settings/` | Language error patterns | ✅ |
| `.claude/utils/` | Shell utilities | ✅ |
| `.claude/hooks/` | Native enforcement hooks | Only with flag |
| `.claude/settings.json` | Hook configuration | Only with flag |

### Verify Installation

```bash
# Check commands installed
ls .claude/commands/vbw-*.md

# Check subagent installed
ls .claude/agents/vbw-execute.md

# Check hooks installed (if --with-hooks was used)
ls .claude/hooks/vbw-*.sh
cat .claude/settings.json | grep -A5 '"hooks"'
```

## VBW Promises

VBW makes two guarantees, enforced by native Claude Code hooks:

| Promise | Hook | What It Does |
|---------|------|--------------|
| **Always run code** | `vbw-execution-gate.sh` (Stop) | Claude cannot finish a VBW session until actual execution (docker build, pytest, etc.) has occurred. Syntax checks alone are not sufficient. |
| **Never copy without approval** | `vbw-copy-gate.sh` (PreToolUse) | Claude cannot copy files from shadow to project without explicit user approval via AskUserQuestion. |

These hooks provide **native enforcement**—Claude cannot bypass them, even if prompted to do so.

### Without Hooks

If you install without `--with-hooks`, VBW still works but relies on prompt-based instructions. Claude *should* follow them, but there's no native enforcement preventing bypass.

## Quick Start

```
/vbw-implement Add input validation to the user registration endpoint
```

VBW will:
1. **Plan** - Analyze task, identify files, assign reviewer roles, generate validations
2. **Ask** - Present action plan for your approval
3. **Execute** - Build/run/test in shadow with automatic retry on failures
4. **Report** - Show results and request approval before copying
5. **Commit** - Copy validated files to your project (only after you approve)

### Example Session

```
You: /vbw-implement Add rate limiting to POST /api/login

Claude: ## VBW Action Plan: Add rate limiting to login endpoint

### Files to Modify
| Layer | File | Action |
|-------|------|--------|
| 0 | src/middleware/rate_limit.py | create |
| 1 | src/routers/auth.py | modify |
| 2 | tests/test_auth.py | modify |

### Validation Commands
| Role | Command | Expected |
|------|---------|----------|
| Security | `bandit -r src/` | No high-severity issues |
| Backend | `uv run python -c "from src.middleware.rate_limit import ..."` | No ImportError |
| QA | `uv run pytest tests/test_auth.py -v` | All tests pass |

Approve this action plan? [Yes / No / Modify]
```

## Commands

| Command | You Run It? | Description |
|---------|-------------|-------------|
| `/vbw-implement` | ✅ **Yes** | Main entry point—orchestrates full workflow |
| `/vbw-team` | ⚪ Optional | Generate reviewer roles for a task |
| `/vbw-validate` | ⚪ Optional | Generate validation commands per role |
| `/vbw-advocate` | ⚪ Optional | Devil's advocate—challenge proposed validations |
| `/vbw-deps` | ⚪ Optional | Analyze file dependency order |
| `/vbw-report` | ⚪ Optional | Aggregate validation results |

> **Note**: `vbw-execute` is a **subagent**, not a slash command. It runs automatically in the shadow environment when `/vbw-implement` spawns it via the Task tool.

### Why a Subagent?

The `vbw-execute` subagent runs in its own context window:

| Main Conversation | Subagent (vbw-execute) |
|-------------------|------------------------|
| Planning, approval gates | Implementation, validation, retries |
| Sees final JSON report only | Sees all errors, iterations, diagnostics |
| Stays clean for follow-up work | Can generate 50KB+ of output safely |

This isolation prevents failed iterations and error traces from consuming your main context.

## Supported Languages

| Language | Detection Files | Error Patterns |
|----------|-----------------|----------------|
| Python | `pyproject.toml`, `*.py` | ~10 patterns |
| TypeScript | `tsconfig.json`, `*.ts` | ~12 patterns |
| Go | `go.mod`, `*.go` | ~12 patterns |
| Java | `pom.xml`, `*.java` | ~10 patterns |
| C# | `*.csproj`, `*.cs` | ~10 patterns |
| Ruby | `Gemfile`, `*.rb` | ~10 patterns |
| PHP | `composer.json`, `*.php` | ~10 patterns |
| Rust | `Cargo.toml`, `*.rs` | ~10 patterns |
| Swift | `Package.swift`, `*.swift` | ~10 patterns |
| Kotlin | `*.kt`, `build.gradle.kts` | ~10 patterns |
| C/C++ | `CMakeLists.txt`, `*.cpp` | ~11 patterns |

**Total: 11 languages, 100+ error patterns**

## How It Works

### Phase 1: Planning (Main Context)

1. **Dependency Analysis** - Which files need to exist before others?
2. **Team Assignment** - Which roles should review? (Security, Backend, SRE, etc.)
3. **Validation Generation** - What commands prove it works?
4. **Devil's Advocate** - Are the validations complete?
5. **→ User approves action plan**

### Phase 2: Execution (Shadow Context)

1. **Shadow Sync** - `rsync` project to `/tmp/vbw-shadow/` (secrets excluded)
2. **Git Init** - Fresh repo in shadow for iteration tracking
3. **Implement** - Make the requested changes
4. **Validate** - Run all validation commands
5. **On Failure** - Diagnose → classify → fix → retry (max 5 iterations)
6. **→ User reviews results**

### Phase 3: Commit (Requires Explicit Approval)

1. **→ User approves copy** via AskUserQuestion prompt
2. **Copy** - Validated files from shadow to project
3. **→ User approves cleanup** of shadow directory

## Targeted Reflection

When validation fails, the subagent performs structured diagnosis:

```
FAIL → Parse Error → Classify Type → Lookup Fix Strategy → Apply → Retry
```

### Error Categories

| Category | Examples | Fix Approach |
|----------|----------|--------------|
| Environment | Module in deps but not found | Use `uv run` / `npm install` |
| Import | Cannot find module, wrong path | Fix import path, check `__init__.py` |
| Syntax | IndentationError, missing colon | Fix code syntax |
| Type | Type mismatch, wrong arguments | Fix types, match signatures |
| Test | Assertion failed, fixture missing | Fix test logic or add fixture |
| Build | Dockerfile error, compile failure | Fix build configuration |

### Diagnosis in Commit Messages

Each retry iteration records what was diagnosed and fixed:

```
VBW: Iter 1 - Initial implementation
VBW: Iter 2 - [ImportError] Fixed module path src.services.auth_service
VBW: Iter 3 - [SyntaxError] Added missing colon after function def
VBW: Iter 4 - [AssertionError] Fixed expected value in test
```

## Configuration

Edit `.claude/settings/vbw.json` after install:

```json
{
  "vbw": {
    "shadow_path": "/tmp/vbw-shadow",
    "max_iterations": 5,
    "parallel_execution": false,
    "auto_cleanup": true,
    "verbose_logging": true,
    "excluded_patterns": [
      ".git", ".env", ".env.*", "*.env",
      "credentials*", "secrets*",
      "*.pem", "*.key", "*.p12", "*.pfx",
      "__pycache__", ".venv", "node_modules",
      ".pytest_cache", ".mypy_cache",
      "dist", "build", "target", "vendor"
    ]
  }
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `shadow_path` | `/tmp/vbw-shadow` | Where shadow copy is created |
| `max_iterations` | `5` | Max retry attempts before failing |
| `parallel_execution` | `false` | Reserved for future parallel validation |
| `auto_cleanup` | `true` | Prompt to remove shadow after completion |
| `verbose_logging` | `true` | Enable detailed execution logging |
| `excluded_patterns` | (see above) | Files/dirs never copied to shadow |

## Troubleshooting

### Installation Issues

**Command not recognized after install**
```
Unknown command: /vbw-implement
```
→ Verify files exist: `ls .claude/commands/vbw-implement.md`
→ Restart Claude Code session

### Shadow Sync Issues

**Source directory does not exist**
```
ERROR: Source directory does not exist: /path/to/project
```
→ Run `/vbw-implement` from your project root, not a subdirectory

### Validation Issues

**ModuleNotFoundError during validation**
```
ModuleNotFoundError: No module named 'mypackage'
```
→ VBW uses `uv run` for Python. Ensure deps are in `pyproject.toml`
→ Run `uv sync` in your project first

**Tests pass locally but fail in shadow**
→ Shadow excludes `.venv`. Run `uv sync` or `npm install` in shadow
→ Check if test relies on files in `excluded_patterns`

### Safety Violations

**PATH VIOLATION error**
```
PATH VIOLATION: /real/project/path is outside shadow directory
```
→ This is correct behavior—subagent refused unsafe operation
→ Check if your task description uses absolute paths

### Context Issues

**Subagent seems to lose context**
→ Subagent has its own context window (by design)
→ All necessary info must be in the task prompt passed to it

### Hook Issues

**"VBW Execution Gate FAILED: No build/test commands detected"**
```
VBW requires at least one of:
  - docker build
  - pytest / npm test / cargo test / go test
  - uv run <command>
```
→ This is correct behavior—VBW requires actual code execution
→ Syntax checks (`python -m py_compile`) are not sufficient
→ Ensure your task includes running tests or building

**"VBW Copy Gate BLOCKED: Attempting to copy from shadow to project"**
```
You must use AskUserQuestion to get explicit user approval
```
→ This is correct behavior—files can't be copied without your approval
→ Claude must ask you first via AskUserQuestion
→ If you see this, Claude tried to skip the approval step

**Hooks not firing**
→ Verify hooks are installed: `ls .claude/hooks/vbw-*.sh`
→ Verify settings.json has hook config: `cat .claude/settings.json`
→ Check hooks are executable: `ls -la .claude/hooks/`
→ Re-run installer: `npx github:DavidKinter/vbw-claude --local --with-hooks`

**Hooks blocking normal (non-VBW) operations**
→ Hooks only activate when `/tmp/vbw-shadow/.vbw-gate-required` exists
→ This marker is created by `/vbw-implement` and removed on cleanup
→ If stuck, manually remove: `rm /tmp/vbw-shadow/.vbw-gate-required`

## Results

Tested on Python/Docker project (5 tasks):

| Metric | Baseline | With VBW | Improvement |
|--------|----------|----------|-------------|
| Mean iterations to pass | 1.4 | 1.0 | 28.6% fewer |
| Code validated before commit | Sometimes | Always | ✓ |
| Diagnosis accuracy | — | 100% | ✓ |
| Validation bypasses | — | 0 | ✓ |

## License

MIT

---

*VBW Claude: Because code should work before it lands in your project.*
