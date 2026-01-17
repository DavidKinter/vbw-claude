# VBW Team Generator

Given a task description, identify the review perspectives needed.

## Input
- Task description
- File types involved (Dockerfile, Python, YAML, etc.)
- Change scope (single file, multi-file, structural)

## Output Format
```json
{
  "task_type": "docker|python|config|test|mixed",
  "roles": [
    {
      "name": "Platform Engineer",
      "focus": "Build optimization, caching, image size",
      "validation_type": "build_success|size_check|performance"
    },
    {
      "name": "Security Engineer",
      "focus": "Base image, secrets, permissions",
      "validation_type": "user_check|secret_scan|vulnerability"
    }
  ]
}
```

## Role Library

### For Dockerfile changes:
- Platform Engineer (build, caching, size)
- Security Engineer (base image, USER, secrets)
- SRE (health checks, restart policy)

### For Python code changes:
- Backend Engineer (imports, syntax, logic)
- QA Engineer (testability, edge cases)
- Security Engineer (input validation, injection)

### For Test changes:
- QA Engineer (coverage, assertions)
- Backend Engineer (fixture usage, mocking)

### For Config changes (YAML, TOML, JSON):
- Platform Engineer (syntax, schema)
- SRE (environment handling)
