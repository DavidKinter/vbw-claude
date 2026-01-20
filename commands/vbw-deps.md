# VBW Dependency Resolver

Determine the correct order to validate files based on import dependencies.

## Input
- List of files to be modified
- Task description

## Analysis Steps
1. For each file, identify imports
2. Build dependency graph
3. Topological sort for validation order
4. Identify files that can be validated in parallel

## Output Format
```json
{
  "validation_order": [
    {
      "layer": 0,
      "files": ["src/services/__init__.py"],
      "parallel": false,
      "rationale": "Package init must exist before service imports"
    },
    {
      "layer": 1,
      "files": ["src/services/user_service.py"],
      "parallel": false,
      "rationale": "Service depends on init"
    },
    {
      "layer": 2,
      "files": ["src/routers/users.py", "tests/test_users.py"],
      "parallel": true,
      "rationale": "Both depend on service, independent of each other"
    }
  ],
  "dependency_graph": {
    "src/routers/users.py": ["src/services/user_service.py"],
    "src/services/user_service.py": ["src/services/__init__.py"],
    "tests/test_users.py": ["src/services/user_service.py"]
  }
}
```

## Dependency Detection Rules

### Python Files
- Scan for `from X import Y` and `import X`
- Map relative imports to absolute paths
- Track `__init__.py` files as implicit dependencies

### Configuration Files
- `pyproject.toml` depends on nothing
- `compose.yml` depends on Dockerfile
- Test configs depend on source configs

### Test Files
- Always depend on their target modules
- Fixtures may create additional dependencies

## Constraints
- Layer 0 files have no internal dependencies
- Circular dependencies must be flagged as errors
- Parallel validation only for same-layer files
