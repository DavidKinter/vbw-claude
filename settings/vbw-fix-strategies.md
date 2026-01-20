# VBW Fix Strategy Reference

Version: 1.0.0
Created: 2026-01-20
Baseline Reference: baseline/results.md

---

## Level 0: Environment Errors (Most Common in Baseline)

### ValidationEnvironment: WrongPython

**Pattern**: `ModuleNotFoundError: No module named '(\w+)'` + module exists in pyproject.toml

**Root Cause**:
- Validation command ran with system Python instead of project venv
- Common when using `python -c "..."` instead of `uv run python -c "..."`

**Fix Strategy**:
1. Check if module is listed in pyproject.toml dependencies
2. If yes: This is an environment error, not a code error
3. Prefix all Python validation commands with `uv run`

**Example**:
```bash
# ERROR: ModuleNotFoundError: No module named 'sqlalchemy'
# DIAGNOSIS: Environment error - sqlalchemy is in pyproject.toml

# BEFORE (wrong):
python -c "from src.helpers.data_helpers import get_user_stats"

# AFTER (correct):
uv run python -c "from src.helpers.data_helpers import get_user_stats"
```

**Baseline Frequency**: 60% of tasks (3/5)

---

### ValidationEnvironment: MissingDevDeps

**Pattern**: `ModuleNotFoundError: No module named 'pytest'`

**Root Cause**:
- Dev dependencies not installed (only main dependencies)
- Common in fresh venv or after `uv sync` without `--extra dev`

**Fix Strategy**:
1. Check if module is in `[project.optional-dependencies.dev]`
2. Run `uv sync --extra dev` to install dev dependencies
3. Retry validation

**Example**:
```bash
# ERROR: ModuleNotFoundError: No module named 'pytest'
# DIAGNOSIS: Dev dependency not installed

# FIX:
uv sync --extra dev

# THEN retry:
uv run pytest tests/test_analytics.py --collect-only
```

---

## Level 1: Python Errors

### ImportError: ModuleNotFoundError (Path)

**Pattern**: `ModuleNotFoundError: No module named 'src.services.(\w+)'`

**Root Cause**:
- Internal module path incorrect
- File doesn't exist at expected location
- Typo in module name

**Fix Strategy**:
1. Verify the file exists: `ls src/services/`
2. Check exact filename (case-sensitive)
3. Verify `__init__.py` exists in parent directories
4. Correct the import path

**Example**:
```python
# ERROR: ModuleNotFoundError: No module named 'src.services.auth'
# DIAGNOSIS: Wrong filename - file is auth_service.py not auth.py

# BEFORE (wrong):
from src.services.auth import AuthManager

# AFTER (correct):
from src.services.auth_service import AuthManager
```

---

### ImportError: NameNotExported

**Pattern**: `cannot import name '(\w+)' from '([^']+)'`

**Root Cause**:
- Name not defined in target module
- Name not exported in `__init__.py`
- Typo in import name

**Fix Strategy**:
1. Open the source module
2. Search for the expected name
3. Check if name is in `__all__` (if defined)
4. Verify spelling matches exactly

**Example**:
```python
# ERROR: cannot import name 'DataHelper' from 'src.helpers.data_helpers'
# DIAGNOSIS: Typo in class name

# BEFORE (wrong):
from src.helpers.data_helpers import DataHelper

# AFTER (correct):
from src.helpers.data_helpers import DataHelpers
```

---

### ImportError: CircularImport

**Pattern**: `cannot import name '(\w+)' from partially initialized module`

**Root Cause**:
- Module A imports Module B, and Module B imports Module A
- Creates circular dependency at import time

**Fix Strategy**:
1. Identify the circular dependency chain
2. Move shared code to a third module
3. Use late imports (import inside function)
4. Restructure module hierarchy

**Example**:
```python
# ERROR: cannot import name 'User' from partially initialized module 'src.models'
# DIAGNOSIS: Circular import between models.py and auth.py

# FIX OPTION 1: Late import
def get_user(user_id):
    from src.models import User  # Import inside function
    return User.query.get(user_id)

# FIX OPTION 2: Extract to base module
# Create src/models/base.py with shared definitions
```

---

### SyntaxError: IndentationError

**Pattern**: `IndentationError: (unexpected indent|expected an indented block)`

**Root Cause**:
- Inconsistent indentation (4 spaces vs 2 spaces)
- Missing indentation after colon
- Extra indentation

**Fix Strategy**:
1. Find the line number from error
2. Check indentation of surrounding lines
3. Ensure consistent use of spaces (4 per level)
4. Verify block structure (after if/for/def/class)

**Example**:
```python
# ERROR: IndentationError: expected an indented block after function definition on line 5
# DIAGNOSIS: Missing indentation in function body

# BEFORE (wrong):
def get_stats():
pass  # No indentation

# AFTER (correct):
def get_stats():
    pass  # 4 spaces
```

---

### SyntaxError: General

**Pattern**: `SyntaxError: (invalid syntax|unexpected EOF|unterminated string)`

**Root Cause**:
- Missing colon after if/for/def/class
- Unclosed parentheses/brackets/braces
- Unterminated string literal
- Invalid Python syntax

**Fix Strategy**:
1. Go to exact line:column from error
2. Check for missing colons
3. Count parentheses/brackets/braces
4. Verify string quotes are matched

**Example**:
```python
# ERROR: SyntaxError: invalid syntax at line 10
# DIAGNOSIS: Missing colon after if statement

# BEFORE (wrong):
if user.is_admin
    return True

# AFTER (correct):
if user.is_admin:
    return True
```

---

### NameError: Undefined

**Pattern**: `NameError: name '(\w+)' is not defined`

**Root Cause**:
- Variable used before assignment
- Missing import
- Typo in variable name

**Fix Strategy**:
1. Search file for variable definition
2. Check imports at top of file
3. Verify variable is in scope
4. Check for typos

**Example**:
```python
# ERROR: NameError: name 'db' is not defined
# DIAGNOSIS: Missing parameter in function signature

# BEFORE (wrong):
def get_user_count():
    return db.query(User).count()

# AFTER (correct):
def get_user_count(db: Session):
    return db.query(User).count()
```

---

### TypeError: Arguments

**Pattern**: `TypeError: (\w+)\(\) takes (\d+) positional arguments? but (\d+) (was|were) given`

**Root Cause**:
- Wrong number of arguments passed to function
- Missing self parameter in method
- Extra arguments passed

**Fix Strategy**:
1. Find function definition
2. Count expected parameters
3. Check call site arguments
4. Add/remove arguments to match

**Example**:
```python
# ERROR: TypeError: get_stats() takes 1 positional argument but 2 were given
# DIAGNOSIS: Forgot self is passed implicitly for methods

# BEFORE (wrong):
class StatsService:
    def get_stats(db):
        pass

# AFTER (correct):
class StatsService:
    def get_stats(self, db):
        pass
```

---

### AssertionError: ValueMismatch

**Pattern**: `AssertionError: assert .+ == .+` or `AssertionError: .+ != .+`

**Root Cause**:
- Expected value doesn't match actual value
- Logic error in code
- Incorrect test expectation

**Fix Strategy**:
1. Print actual value to understand behavior
2. Check if expectation is correct
3. Trace code logic
4. Fix code or update expectation

**Example**:
```python
# ERROR: AssertionError: assert 5 == 3
# DIAGNOSIS: Code returns wrong count

# DEBUG:
result = get_active_count()
print(f"DEBUG: result = {result}")  # Shows 5

# FIX (if logic is wrong):
def get_active_count():
    return db.query(Item).filter(Item.active == True).count()  # Was missing filter
```

---

## Level 2: Test Errors

### FixtureError: NotFound

**Pattern**: `fixture '(\w+)' not found`

**Root Cause**:
- Fixture not defined in conftest.py
- Typo in fixture name
- conftest.py not in correct directory

**Fix Strategy**:
1. Check test file for fixture parameter name
2. Search conftest.py for fixture definition
3. Verify conftest.py is in tests/ directory
4. Add missing fixture or fix typo

**Example**:
```python
# ERROR: fixture 'test_db' not found
# DIAGNOSIS: Fixture named 'db' in conftest.py, not 'test_db'

# BEFORE (wrong):
def test_user_count(test_db):
    pass

# AFTER (correct):
def test_user_count(db):  # Match conftest.py fixture name
    pass
```

---

### CollectionError: NoTestsFound

**Pattern**: `no tests ran` or `collected 0 items`

**Root Cause**:
- Test functions don't start with `test_`
- Test file doesn't match `test_*.py` pattern
- Tests are in wrong directory

**Fix Strategy**:
1. Verify file name starts with `test_`
2. Verify function names start with `test_`
3. Check pytest.ini or pyproject.toml for test paths

**Example**:
```python
# ERROR: collected 0 items
# DIAGNOSIS: Function not prefixed with test_

# BEFORE (wrong):
def check_user_count(db):
    assert get_count(db) > 0

# AFTER (correct):
def test_user_count(db):
    assert get_count(db) > 0
```

---

## Level 3: Build Errors

### DockerBuildError: SyntaxError

**Pattern**: `dockerfile parse error` or `unknown instruction`

**Root Cause**:
- Invalid Dockerfile instruction
- Typo in instruction name
- Missing required arguments

**Fix Strategy**:
1. Check instruction spelling (COPY not copy)
2. Verify instruction syntax
3. Check for missing backslash in multi-line

**Example**:
```dockerfile
# ERROR: unknown instruction: HEALTCHECK
# DIAGNOSIS: Typo in HEALTHCHECK

# BEFORE (wrong):
HEALTCHECK CMD curl localhost:8000

# AFTER (correct):
HEALTHCHECK CMD curl localhost:8000
```

---

### ComposeError: SyntaxError

**Pattern**: `yaml.scanner.ScannerError` or `yaml: line`

**Root Cause**:
- Invalid YAML syntax
- Wrong indentation
- Missing colon after key

**Fix Strategy**:
1. Validate YAML with `python -c "import yaml; yaml.safe_load(open('compose.yml'))"`
2. Check indentation (2 spaces for YAML)
3. Ensure colons after all keys

**Example**:
```yaml
# ERROR: yaml.scanner.ScannerError: mapping values are not allowed here
# DIAGNOSIS: Missing space after colon

# BEFORE (wrong):
services:
  api:
    ports:
      -"8000:8000"

# AFTER (correct):
services:
  api:
    ports:
      - "8000:8000"
```

---

## Quick Reference Table

| Error Pattern | Type | Primary Fix |
|--------------|------|-------------|
| `ModuleNotFoundError` + in pyproject.toml | Environment | Use `uv run` prefix |
| `ModuleNotFoundError: pytest` | Environment | `uv sync --extra dev` |
| `ModuleNotFoundError: src.X` | ImportError | Check file path |
| `cannot import name` | ImportError | Check export exists |
| `IndentationError` | SyntaxError | Fix indentation |
| `SyntaxError` | SyntaxError | Check colons/parens |
| `NameError: name 'X'` | NameError | Add import or define |
| `TypeError: takes N args` | TypeError | Match argument count |
| `AssertionError` | AssertionError | Check logic/expectation |
| `fixture 'X' not found` | FixtureError | Add to conftest.py |
| `collected 0 items` | CollectionError | Prefix with `test_` |
| `dockerfile parse error` | BuildError | Check instruction syntax |
| `yaml.scanner.ScannerError` | ComposeError | Fix YAML indentation |
