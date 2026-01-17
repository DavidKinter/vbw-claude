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
4. If all pass, copy back to real project

## Config

Edit `.claude/settings/vbw.json` after install.
