# VBW Implement Command

Implements a task using Validate-Before-Write protocol.

## Usage
/vbw:implement {task description}

## Workflow
1. Create action plan with validation commands
2. Get user approval
3. Spawn execution subagent in shadow project
4. Report results for user approval
5. Copy validated files to real codebase
