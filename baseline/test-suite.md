# Baseline Test Suite

## Purpose
Establish current iteration patterns before implementing targeted reflection.

> **Note**: These are example tasks used for VBW framework testing. Adapt task descriptions to match your project's structure.

---

## Task 1: Dockerfile Modification (Single File)
- Add health check to Dockerfile
- Expected iterations: 1-3
- *Example: Any single-file infrastructure change*

## Task 2: Python Service (Import Dependencies)
- Create new helper function with imports
- Expected iterations: 2-4
- *Example: Any new module with cross-file dependencies*

## Task 3: Test File (Fixture Dependencies)
- Add new pytest test with fixtures
- Expected iterations: 2-5
- *Example: Any test requiring shared fixtures*

## Task 4: Multi-File Change (Dependencies)
- Add router endpoint + test
- Expected iterations: 3-6
- *Example: Any feature spanning implementation + tests*

## Task 5: Configuration Change (Validation-Heavy)
- Update compose.yml with new service
- Expected iterations: 2-4
- *Example: Any infrastructure config with syntax validation*
