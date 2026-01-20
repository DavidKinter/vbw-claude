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

## Supported Languages

| Language | Detection Files | Error Patterns |
|----------|-----------------|----------------|
| Python | `pyproject.toml`, `*.py` | 10 patterns |
| TypeScript | `tsconfig.json`, `*.ts` | 12 patterns |
| Go | `go.mod`, `*.go` | 12 patterns |
| Java | `pom.xml`, `*.java` | 10 patterns |
| C# | `*.csproj`, `*.cs` | 10 patterns |
| Ruby | `Gemfile`, `*.rb` | 10 patterns |
| PHP | `composer.json`, `*.php` | 10 patterns |
| Rust | `Cargo.toml`, `*.rs` | 10 patterns |
| Swift | `Package.swift`, `*.swift` | 10 patterns |
| Kotlin | `*.kt`, `build.gradle.kts` | 10 patterns |
| C/C++ | `CMakeLists.txt`, `*.cpp` | 11 patterns |

**Total: 11 languages, 115 error patterns**

## How It Works

1. rsync project to `/tmp/vbw-shadow/` (secrets excluded)
2. Make changes in shadow
3. Run validations (syntax, imports, tests)
4. If validation fails → **Diagnose → Fix → Retry** (up to 5 iterations)
5. If all pass, copy back to real project

## Targeted Reflection (v1.1.0)

When validation fails, the execution subagent now performs structured diagnosis:

```
FAIL → Parse Error → Classify Type → Apply Fix Strategy → Retry
```

### Error Categories (All Languages)

| Category | Examples | Fix Approach |
|----------|----------|--------------|
| Environment | Missing deps, wrong runtime | Install deps, use correct runtime |
| Import/Module | Cannot find module, undefined | Fix import path, install package |
| Syntax | Invalid syntax, unexpected token | Fix code syntax |
| Type | Type mismatch, wrong arguments | Fix types, match signatures |
| Test | Assertion failed, fixture missing | Fix test logic or setup |
| Build | Dockerfile error, compile error | Fix build configuration |

See `settings/vbw-error-patterns-{language}.json` for language-specific patterns.

### Diagnosis in Commit Messages

Failed iterations include diagnosis tags:
```
VBW: Iter 2 - [ImportError] Fixed module path src.services.auth_service
VBW: Iter 3 - [SyntaxError] Added missing colon after function def
```

### Results

- **28.6% iteration reduction** (1.4 → 1.0 mean iterations)
- **100% diagnosis accuracy** across tested error types
- **Zero validation bypasses** (safety maintained)

See `docs/26-01-20_vbw-targeted-reflection-playbook.md` for implementation details.

## Config

Edit `.claude/settings/vbw.json` after install.
