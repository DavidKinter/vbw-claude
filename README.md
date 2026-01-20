# VBW Claude

Validate-Before-Write framework for Claude Code. Executes code changes in a sandbox, validates, then copies to real project.

## Install

```bash
# From GitHub (private repo)
npx github:DavidKinter/vbw-claude --local

# Or clone and run directly
git clone git@github.com:DavidKinter/vbw-claude.git
node vbw-claude/bin/install.js --local
```

## Flags

- `--local` - Install to current project's `.claude/commands/` (default)
- `--global` - Install to `~/.claude/commands/`

## Commands

After install, these slash commands are available in Claude Code:

| Command | Description |
|---------|-------------|
| `/vbw-implement` | Generate action plan for task |
| `/vbw-execute` | Run in sandbox with validation |
| `/vbw-team` | Multi-role validation perspectives |
| `/vbw-validate` | Generate validation commands |
| `/vbw-advocate` | Devil's advocate review |
| `/vbw-deps` | Dependency order resolution |
| `/vbw-report` | Aggregate validation report |

## How It Works

1. rsync project to `/tmp/vbw-shadow/`
2. Make changes in shadow
3. Run validations (syntax, imports, tests)
4. If validation fails → **Diagnose → Fix → Retry** (up to 5 iterations)
5. If all pass, copy back to real project

## Targeted Reflection (v1.1.0)

When validation fails, the execution subagent now performs structured diagnosis:

```
FAIL → Parse Error → Classify Type → Apply Fix Strategy → Retry
```

### Supported Error Types

| Error Type | Pattern | Fix Strategy |
|------------|---------|--------------|
| ImportError | `ModuleNotFoundError` | Check import path, verify file exists |
| SyntaxError | `IndentationError`, `invalid syntax` | Fix indentation, check colons/brackets |
| FixtureError | `fixture '...' not found` | Use correct fixture name from conftest.py |
| AssertionError | `assert ... == ...` | Check expected vs actual values |
| BuildError | Docker build failures | Check Dockerfile syntax and paths |
| ConfigError | YAML/JSON parse errors | Fix indentation, check syntax |

### Diagnosis in Commit Messages

Failed iterations include diagnosis tags:
```
VBW: Iter 2 - [ImportError] Fixed module path src.services.pantry_ai
VBW: Iter 3 - [SyntaxError] Added missing colon after function def
```

### Results

- **28.6% iteration reduction** (1.4 → 1.0 mean iterations)
- **100% diagnosis accuracy** across tested error types
- **Zero validation bypasses** (safety maintained)

See `docs/26-01-20_vbw-targeted-reflection-playbook.md` for implementation details.

## Config

Edit `.claude/settings/vbw.json` after install.
