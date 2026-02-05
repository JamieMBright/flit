# AGENTS.md - Task Delegation Framework

## Agent Philosophy

When facing multiple tasks, **always spawn agents**. Keep the main context lean. Agents handle bounded work; the orchestrator synthesizes results.

---

## Agent Types

### `explore` - Codebase Explorer
**Use for:** Understanding code structure, finding implementations, mapping dependencies

```
subagent_type: Explore
thoroughness: quick | medium | very thorough
```

**When to use:**
- "Where is X implemented?"
- "How does Y work?"
- "What files relate to Z?"

---

### `test-runner` - Test Execution Agent
**Use for:** Running test suites, validating changes

**Responsibilities:**
- Execute unit tests with coverage reporting
- Run security scans
- Execute platform-specific integration tests
- Run deployment simulations
- Report failures with actionable context

**Spawn for:**
- Pre-commit validation
- CI simulation
- Platform-specific test runs (can run iOS/Android/Web in parallel)

---

### `platform-validator` - Cross-Platform Checker
**Use for:** Ensuring changes work across all platforms

**Responsibilities:**
- Verify no platform-specific regressions
- Check relative positioning compliance
- Validate responsive behavior
- Test on iOS, Android, and Web simultaneously

**Critical Rule:** Never validate just one platform. Minimum 2.

---

### `security-auditor` - Security Analysis Agent
**Use for:** Security validation before commits

**Responsibilities:**
- Dependency vulnerability scanning
- SAST (Static Application Security Testing)
- Secrets detection
- Input validation review
- API security checks

---

### `performance-profiler` - Performance Agent
**Use for:** Ensuring hyper-performant builds

**Responsibilities:**
- Bundle size analysis
- Runtime performance profiling
- Memory leak detection
- Frame rate validation
- Load time benchmarking

**Threshold enforcement:**
- 60fps minimum on all platforms
- Bundle size within budget
- No memory growth over time

---

### `geo-data-validator` - Geographic Data Agent
**Use for:** Validating geographic data sources and usage

**Responsibilities:**
- License compliance verification
- Data source validation (OSM, Natural Earth, etc.)
- Coordinate system verification
- Data freshness checks

---

### `lint-fixer` - Code Quality Agent
**Use for:** Automated code quality fixes

**Responsibilities:**
- Run ESLint with auto-fix
- Apply Prettier formatting
- TypeScript strict mode validation
- Import organization

---

### `build-validator` - Build Verification Agent
**Use for:** Validating production builds

**Responsibilities:**
- Build all platform targets
- Verify bundle contents
- Check for build warnings
- Validate output artifacts

---

## Parallel Execution Patterns

### Pre-Commit Validation (Parallel)
Spawn these agents simultaneously:
```
1. test-runner (unit tests)
2. security-auditor
3. lint-fixer (check mode)
4. platform-validator (iOS + Android + Web)
```

Wait for all. Proceed only if all pass.

### Feature Implementation (Sequential + Parallel)
```
1. explore (understand context) - SEQUENTIAL
2. implement changes - SEQUENTIAL
3. PARALLEL:
   - test-runner
   - platform-validator
   - performance-profiler
4. lint-fixer - SEQUENTIAL (final cleanup)
```

### Pre-Deploy Validation (Parallel)
```
PARALLEL:
- test-runner (full suite)
- security-auditor (deep scan)
- build-validator (all platforms)
- performance-profiler (production build)
```

---

## Agent Communication Protocol

### Spawning Agents
```
Task tool with:
- Clear, bounded objective
- Specific success criteria
- Platform requirements (always 2+)
- Performance expectations
```

### Agent Results
Each agent must return:
- Status: pass/fail
- Summary: 1-3 sentences
- Details: expandable findings
- Blockers: if any

### Aggregation
Orchestrator must:
1. Wait for all parallel agents
2. Synthesize results
3. Identify conflicts
4. Make go/no-go decision
5. Report to user

---

## Context Boundaries

### What Agents Should Know
- Their specific task scope
- Relevant file paths
- Platform targets
- Performance budgets
- Success criteria

### What Agents Should NOT Carry
- Full conversation history
- Unrelated codebase context
- Previous agent results (unless dependency)

---

## Failure Handling

### Agent Fails
1. Capture failure reason
2. Determine if retry is appropriate
3. If persistent, escalate to orchestrator
4. Never silently swallow failures

### Multiple Agent Failures
1. Halt remaining dependent work
2. Report all failures together
3. Prioritize fixes by dependency order
4. Re-run failed agents after fixes

---

## Quick Reference

| Task Type | Agent(s) | Parallel? |
|-----------|----------|-----------|
| Find code | explore | N/A |
| Run tests | test-runner | Yes (by platform) |
| Security check | security-auditor | Yes |
| Performance check | performance-profiler | Yes |
| Lint/format | lint-fixer | N/A |
| Cross-platform verify | platform-validator | Yes (by platform) |
| Pre-commit | ALL | Yes |
| Build verify | build-validator | Yes (by platform) |
