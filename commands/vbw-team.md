# VBW Team Generator

Given a task description, evaluate which engineering roles should review this change.

## Approach

**Do NOT use static file-type mappings.** Instead, reason about the task:

> "Which roles at a pre-IPO scale-up would typically work on designing, implementing, and testing this kind of change?"

Consider:
- **Nature of the change**: Infrastructure? Feature? Bug fix? Security patch? Performance optimization?
- **Risk profile**: Does it touch auth, payments, PII, public APIs, or data persistence?
- **Scope**: Single file tweak or cross-cutting architectural change?
- **Blast radius**: What breaks if this is wrong?

## Input
- Task description
- Files being modified (for context, not for extension mapping)
- Change scope

## Evaluation Process

1. **Read the task** - What is actually being changed?
2. **Assess risk** - What could go wrong? Who cares if it breaks?
3. **Identify expertise** - Who would catch issues that automated tests might miss?
4. **Select 2-4 roles** - Lean team, no bureaucracy. Only roles that add distinct value.

## Output Format
```json
{
  "task_summary": "Brief description of what's changing",
  "risk_assessment": "low|medium|high",
  "rationale": "Why these specific roles were selected",
  "roles": [
    {
      "name": "Role title",
      "focus": "What specifically they should look for in this change",
      "validation_type": "What kind of validation they would perform"
    }
  ]
}
```

## Role Selection Guidelines

**Keep it lean.** A pre-IPO scale-up doesn't have unlimited reviewers. Select roles based on:

- **Who would own this in production?** (SRE for infra, Backend Engineer for services)
- **Who would get paged if it breaks?** (That person should review)
- **What's the specialized risk?** (Security Engineer for auth, Data Engineer for migrations)
- **Who writes the tests?** (QA Engineer for complex test logic)

**Typical combinations:**

| Change Type | Likely Roles | Why |
|-------------|--------------|-----|
| Simple bug fix | 1-2 roles | Low risk, quick review |
| New feature | 2-3 roles | Needs design + test perspective |
| Security-sensitive | 2-3 roles, must include Security | Non-negotiable |
| Infrastructure | 2-3 roles, must include SRE/Platform | They own production |
| Data/schema change | 2-3 roles, must include Data/Backend | Migration risk |

## Example Evaluation

**Task**: "Add rate limiting to the /api/login endpoint"

**Reasoning**:
- This is security-sensitive (auth endpoint, abuse prevention)
- Affects production traffic patterns (SRE cares)
- Needs correct implementation (Backend owns the code)
- No complex test fixtures needed (QA not required)

**Output**:
```json
{
  "task_summary": "Add rate limiting to login endpoint",
  "risk_assessment": "high",
  "rationale": "Auth endpoint with abuse prevention - needs security review and SRE sign-off on traffic handling",
  "roles": [
    {
      "name": "Security Engineer",
      "focus": "Rate limit bypass vectors, timing attacks, account enumeration",
      "validation_type": "security_review"
    },
    {
      "name": "Backend Engineer",
      "focus": "Implementation correctness, error responses, header handling",
      "validation_type": "code_review"
    },
    {
      "name": "SRE",
      "focus": "Production traffic impact, monitoring, alerting thresholds",
      "validation_type": "operational_review"
    }
  ]
}
```
