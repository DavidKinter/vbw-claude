# VBW Environment Detector

Claude-driven analysis of project environment requirements for validation.

## Purpose

Analyze project manifest files to determine:
1. What ecosystems/languages are present
2. What lockfiles need to be generated
3. What tools are required
4. What functional validations are possible

## Usage

Invoked automatically by vbw-implement during the planning phase, or manually:
```
/vbw-environment [project_path]
```

## Input

Project directory contents, specifically:
- Manifest files (pyproject.toml, package.json, Cargo.toml, etc.)
- Existing lockfiles (uv.lock, package-lock.json, etc.)
- Configuration files (Dockerfile, docker-compose.yml, etc.)
- Optional: `.vbw/environment.yaml` user override

## Detection Process

### Step 1: Check for User Override

```
IF .vbw/environment.yaml exists:
    Parse as base configuration
    User config takes precedence over auto-detection
ELSE:
    Proceed with full auto-detection
```

### Step 2: Scan for Manifest Files

Read project root and identify manifest files:

| File | Ecosystem | Possible Variants |
|------|-----------|-------------------|
| `pyproject.toml` | Python | uv, poetry, setuptools, flit |
| `requirements.in` | Python | pip-compile |
| `Pipfile` | Python | pipenv |
| `package.json` | Node | npm, yarn, pnpm |
| `Cargo.toml` | Rust | cargo |
| `go.mod` | Go | go |
| `Gemfile` | Ruby | bundler |
| `pom.xml` | Java | maven |
| `build.gradle` / `build.gradle.kts` | Java/Kotlin | gradle |
| `*.csproj` | C# | dotnet |
| `composer.json` | PHP | composer |
| `Package.swift` | Swift | spm |
| `mix.exs` | Elixir | mix |
| `build.sbt` | Scala | sbt |

### Step 3: Determine Variant Within Ecosystem

For each detected ecosystem, analyze manifest content to determine variant:

**Python Detection Logic**:
```
IF pyproject.toml exists:
    content = read pyproject.toml
    IF "[tool.uv]" in content OR uv.lock exists:
        variant = "uv"
        lockfile = "uv.lock"
        command = "uv lock"
    ELIF "[tool.poetry]" in content OR poetry.lock exists:
        variant = "poetry"
        lockfile = "poetry.lock"
        command = "poetry lock"
    ELIF "[build-system]" contains "setuptools":
        variant = "setuptools"
        lockfile = null  # No standard lockfile
        command = null
    ELSE:
        variant = "unknown"
        confidence = "low"
```

**Node Detection Logic**:
```
IF package.json exists:
    IF pnpm-lock.yaml exists:
        variant = "pnpm"
    ELIF yarn.lock exists:
        variant = "yarn"
    ELIF package-lock.json exists:
        variant = "npm"
    ELSE:
        # Check for packageManager field in package.json
        content = read package.json
        IF "packageManager" contains "pnpm":
            variant = "pnpm"
        ELIF "packageManager" contains "yarn":
            variant = "yarn"
        ELSE:
            variant = "npm"  # Default assumption
            confidence = "medium"
```

### Step 4: Check Tool Availability

For each detected ecosystem, verify the tool is available:

```bash
# Check commands
uv --version
poetry --version
npm --version
yarn --version
pnpm --version
cargo --version
go version
bundle --version
docker --version
```

### Step 5: Determine What's Missing

Compare required lockfiles against existing files:

```
FOR each ecosystem:
    IF lockfile.expected AND NOT lockfile.exists:
        missing_lockfiles.append({
            manifest: ecosystem.manifest,
            lockfile: lockfile.expected,
            generation_command: lockfile.command
        })
```

### Step 6: Assess Functional Validation Possibilities

Based on environment state, determine what validations can run:

| Validation | Requires | Blocked If |
|------------|----------|------------|
| docker build | Dockerfile + lockfile (if COPY) | lockfile missing |
| pytest | .venv or uv sync | No Python env |
| npm test | node_modules | No npm install |
| cargo test | Cargo.lock | No dependencies |

## Output Format

```json
{
  "detected_ecosystems": [
    {
      "ecosystem": "python",
      "variant": "uv",
      "manifest": "pyproject.toml",
      "lockfile": {
        "expected": "uv.lock",
        "exists": false,
        "generation_command": "uv lock"
      },
      "tool": {
        "name": "uv",
        "check_command": "uv --version",
        "available": true,
        "version": "0.5.10",
        "install_hint": "curl -LsSf https://astral.sh/uv/install.sh | sh"
      },
      "confidence": "high"
    },
    {
      "ecosystem": "node",
      "variant": "npm",
      "manifest": "package.json",
      "lockfile": {
        "expected": "package-lock.json",
        "exists": true,
        "generation_command": "npm install --package-lock-only"
      },
      "tool": {
        "name": "npm",
        "check_command": "npm --version",
        "available": true,
        "version": "10.2.0",
        "install_hint": "Install Node.js from https://nodejs.org"
      },
      "confidence": "high"
    },
    {
      "ecosystem": "docker",
      "variant": "dockerfile",
      "manifest": "Dockerfile",
      "lockfile": null,
      "tool": {
        "name": "docker",
        "check_command": "docker --version",
        "available": true,
        "version": "24.0.7",
        "install_hint": "Install Docker Desktop from https://docker.com"
      },
      "confidence": "high"
    }
  ],
  "unrecognized_files": [
    {
      "file": "custom-build.xml",
      "suggestion": "Might be Apache Ant build file - add to .vbw/environment.yaml if needed"
    }
  ],
  "functional_validations_possible": {
    "docker_build": {
      "possible": false,
      "blocked_by": "uv.lock missing",
      "unblocks_if": "Run 'uv lock' first"
    },
    "pytest": {
      "possible": true,
      "requires": ["pyproject.toml", "uv.lock or .venv"]
    },
    "npm_test": {
      "possible": true,
      "requires": ["package.json", "package-lock.json"]
    }
  },
  "recommended_prep_commands": [
    {
      "command": "uv lock",
      "purpose": "Generate Python lockfile for reproducible builds",
      "ecosystem": "python"
    }
  ],
  "user_config_applied": false,
  "warnings": [
    "Python ecosystem detected but lockfile missing - functional validations will be blocked"
  ]
}
```

## Confidence Levels

| Level | Meaning | Action |
|-------|---------|--------|
| high | Clear indicators present (lockfile exists, [tool.X] in manifest) | Proceed automatically |
| medium | Reasonable inference (default tool for ecosystem) | Proceed with note |
| low | Ambiguous indicators, multiple possible interpretations | Flag as unrecognized, ask user |

**When confidence is "low"**:
- Add to `unrecognized_files` array
- Include suggestion for user action
- Do NOT generate prep commands (could be wrong tool)

## User Config: .vbw/environment.yaml

Optional file to override or extend auto-detection:

```yaml
# .vbw/environment.yaml
# Optional: Override or extend VBW's automatic environment detection

# Lockfile generation (overrides auto-detection)
lockfiles:
  # Standard format
  - manifest: pyproject.toml
    lockfile: uv.lock
    command: uv lock

  # Custom/nested paths (monorepo)
  - manifest: frontend/package.json
    lockfile: frontend/pnpm-lock.yaml
    command: cd frontend && pnpm install --lockfile-only

  # Explicitly skip lockfile generation
  - manifest: legacy/requirements.txt
    skip: true
    reason: "Legacy code, managed manually"

# Tool requirements (VBW will check availability)
tools:
  - name: uv
    check: uv --version
    required: true  # Fail if not available

  - name: docker
    check: docker --version
    required: false  # Warn but continue if not available

# Functional validations (overrides auto-detection)
functional_validations:
  - name: docker_build
    command: docker build --target dev .
    requires: [Dockerfile, uv.lock]

  - name: pytest
    command: uv run pytest tests/
    requires: [pyproject.toml, uv.lock]

  # Custom validation
  - name: custom_lint
    command: ./scripts/lint.sh
    requires: []

# Skip auto-detection for these files
ignore:
  - legacy/old-build.xml
  - vendor/
  - third_party/

# Force specific ecosystem detection
force:
  - file: custom-deps.toml
    ecosystem: python
    variant: uv
    lockfile: uv.lock
```

### Config Merge Rules

1. **User config takes precedence** over auto-detection
2. **Explicit skip** prevents lockfile generation for that manifest
3. **Ignore list** excludes files from analysis
4. **Force list** overrides detection logic for specific files

## Constraints

- **Read-only**: This command only analyzes, never executes commands
- **No network**: Does not fetch or download anything
- **Deterministic**: Same project state = same output
- **Fast**: Should complete in <5 seconds for typical projects

## Error Handling

| Error | Response |
|-------|----------|
| Manifest file unreadable | Add to warnings, skip that ecosystem |
| Unknown manifest format | Add to unrecognized_files |
| Tool check fails | Set tool.available = false, include install_hint |
| .vbw/environment.yaml invalid | Return error, do not proceed |

## Integration with vbw-implement

vbw-implement calls vbw-environment as first step:

```
1. Run vbw-environment
2. Display environment summary to user
3. If prep commands needed:
   a. Show commands that will run
   b. Get user confirmation
   c. Pass prep commands to shadow sync
4. Proceed with validation planning
```

## Example Scenarios

### Scenario 1: Python/uv Project Without Lockfile

**Project files**:
- pyproject.toml (contains [tool.uv])
- src/main.py
- Dockerfile (COPY uv.lock ...)

**Output**:
```json
{
  "detected_ecosystems": [{
    "ecosystem": "python",
    "variant": "uv",
    "lockfile": {"expected": "uv.lock", "exists": false, "generation_command": "uv lock"}
  }],
  "functional_validations_possible": {
    "docker_build": {"possible": false, "blocked_by": "uv.lock missing"}
  },
  "recommended_prep_commands": [
    {"command": "uv lock", "purpose": "Generate Python lockfile"}
  ]
}
```

### Scenario 2: Monorepo with Multiple Ecosystems

**Project files**:
- pyproject.toml (root - Python backend)
- frontend/package.json (React frontend)
- docker-compose.yml

**Output**:
```json
{
  "detected_ecosystems": [
    {"ecosystem": "python", "variant": "uv", "manifest": "pyproject.toml"},
    {"ecosystem": "node", "variant": "npm", "manifest": "frontend/package.json"},
    {"ecosystem": "docker", "variant": "compose", "manifest": "docker-compose.yml"}
  ],
  "recommended_prep_commands": [
    {"command": "uv lock", "ecosystem": "python"},
    {"command": "cd frontend && npm install --package-lock-only", "ecosystem": "node"}
  ]
}
```

### Scenario 3: Unknown Ecosystem

**Project files**:
- build.sbt (Scala - less common)
- src/main/scala/Main.scala

**Output**:
```json
{
  "detected_ecosystems": [{
    "ecosystem": "scala",
    "variant": "sbt",
    "confidence": "medium",
    "lockfile": {"expected": null, "note": "SBT has no standard lockfile"}
  }],
  "unrecognized_files": [],
  "warnings": [
    "Scala/SBT detected but lockfile support is limited. Consider adding .vbw/environment.yaml for custom configuration."
  ]
}
```
