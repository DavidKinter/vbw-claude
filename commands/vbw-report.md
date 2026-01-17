# VBW Aggregate Reporter

Combine validation results from multiple files into unified report.

## Input
- List of per-file validation results

## Output Format
```json
{
  "overall_status": "PASS|PARTIAL|FAIL",
  "summary": {
    "total_files": 3,
    "passed": 2,
    "failed": 1,
    "total_validations": 12,
    "validations_passed": 10,
    "validations_failed": 2
  },
  "by_file": [
    {
      "file": "src/services/pantry_ai.py",
      "status": "PASS",
      "validations": [...]
    },
    {
      "file": "tests/test_ai.py",
      "status": "FAIL",
      "validations": [...],
      "failure_reason": "Import error: module not found"
    }
  ],
  "blocking_failures": [
    "tests/test_ai.py cannot import src.services.pantry_ai"
  ],
  "recommendation": "Fix pantry_ai.py import path, then re-run test validation"
}
```

## Status Rules
- PASS: All files pass all validations
- PARTIAL: Some files pass, some fail (may be acceptable)
- FAIL: Critical files fail or blocking dependencies unmet

## Blocking vs Non-Blocking Failures

### Blocking (prevents commit)
- Syntax errors in any file
- Import failures in production code
- Security validation failures
- Build failures

### Non-Blocking (warn but allow)
- Style/lint warnings
- Test coverage below threshold
- Documentation gaps
- Performance benchmarks

## Recommendation Generation

Based on failure patterns, suggest:
1. Which file to fix first (dependency order)
2. What type of fix is needed (syntax, import, logic)
3. Whether partial commit is safe (passed files only)
