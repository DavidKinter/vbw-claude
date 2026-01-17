# VBW Validation Generator

Given a role and task, generate specific validation commands.

## Input
- Role name and focus area
- Task description
- Files being modified
- Current codebase context

## Output Format
```json
{
  "role": "Platform Engineer",
  "validations": [
    {
      "description": "Verify Dockerfile syntax",
      "command": "docker build --check .",
      "expected_output": "exit code 0, no error text",
      "rationale": "Docker BuildKit syntax validation"
    },
    {
      "description": "Verify image size acceptable",
      "command": "docker images --format '{{.Size}}' myimage:prod",
      "expected_output": "< 500MB",
      "rationale": "Production images should be optimized"
    }
  ]
}
```

## Validation Command Reference

| File Type | Validation | Command | Expected |
|-----------|------------|---------|----------|
| Python | Syntax | `python -m py_compile {file}` | No output, exit 0 |
| Python | Import | `python -c "from {module} import {name}"` | No output, exit 0 |
| Dockerfile | Syntax | `docker build --check .` | No error text |
| Dockerfile | Build | `docker build --target {stage} .` | "Successfully built" |
| YAML | Syntax | `python -c "import yaml; yaml.safe_load(open('{file}'))"` | No output, exit 0 |
| JSON | Syntax | `python -c "import json; json.load(open('{file}'))"` | No output, exit 0 |
| pytest | Collect | `pytest --collect-only {file}` | "X items collected" |
| pytest | Run | `pytest {file}` | "X passed" |

## Constraints
- Expected outputs must be verifiable via string matching
- Use documented tool behavior only (no guessing)
- Include command that can be copy-pasted
