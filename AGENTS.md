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
- "How does the shader pipeline work?"
- "What files relate to the rendering system?"

---

### `test-runner` - Test Execution Agent
**Use for:** Running test suites, validating changes

**Responsibilities:**
- Execute unit tests with coverage reporting
- Run shader compilation tests across platforms
- Run security scans
- Execute platform-specific integration tests
- Run deployment simulations
- Report failures with actionable context

**Spawn for:**
- Pre-commit validation
- CI simulation
- Platform-specific test runs (can run iOS/Android/Web in parallel)
- Shader compilation verification

---

### `platform-validator` - Cross-Platform Checker
**Use for:** Ensuring changes work across all platforms

**Responsibilities:**
- Verify no platform-specific regressions
- Check relative positioning compliance
- Validate responsive behavior
- **Verify shader compilation** on iOS (Metal), Android (Vulkan/GLES), Web (WebGL)
- Test on iOS, Android, and Web simultaneously

**Critical Rule:** Never validate just one platform. Minimum 2.

---

### `security-auditor` - Security Analysis Agent
**Use for:** Security validation before commits

**Responsibilities:**
- Dependency vulnerability scanning
- SAST (Static Application Security Testing)
- Secrets detection (API keys, tokens in source)
- Input validation review
- API security checks
- **Telemetry endpoint security** (Vercel error API key management)

---

### `performance-profiler` - Performance Agent
**Use for:** Ensuring 60fps and optimal resource usage

**Responsibilities:**
- **Shader performance profiling** (GPU timing per platform)
- Bundle size analysis (< 50MB asset budget)
- Runtime performance profiling (CPU + GPU)
- Memory leak detection (texture disposal, shader cleanup)
- Frame rate validation (60fps sustained)
- **Texture resolution tradeoff testing** (1024 vs 2048 vs 4096)
- Load time benchmarking

**Threshold enforcement:**
- 60fps minimum on all platforms
- Bundle size within 50MB budget
- No memory growth over time
- Shader compile time < 500ms

---

### `geo-data-validator` - Geographic Data & Asset Agent
**Use for:** Validating geographic data sources, processing texture assets

**Responsibilities:**
- License compliance verification (NASA, ETOPO, Natural Earth = public domain)
- **Asset pipeline processing:**
  - Download and resize satellite imagery (NASA Blue Marble)
  - Process heightmaps (ETOPO → normalized grayscale)
  - Generate shore distance textures (Jump Flood Algorithm)
  - Process city lights texture (NASA Earth at Night)
- Data source validation
- Coordinate system verification
- Texture format and resolution validation
- **Channel packing** (combining maps into RGBA textures)

**Asset sources (all open license):**
| Asset | Source | License |
|-------|--------|---------|
| Satellite imagery | NASA Blue Marble | Public Domain |
| Heightmap | ETOPO1/ETOPO2022 | Public Domain |
| City lights | NASA Earth at Night | Public Domain |
| Country polygons | Natural Earth | Public Domain |
| Place names | GeoNames | CC-BY |

---

### `shader-validator` - Shader Code Agent
**Use for:** Validating and debugging GLSL fragment shaders

**Responsibilities:**
- GLSL syntax validation (matching braces, valid types, no undefined variables)
- **Sampler count audit** (max 4 per shader pass)
- Uniform contract verification (Dart ↔ GLSL alignment)
- Cross-platform compatibility checks (WebGL GLSL ES 1.0 restrictions)
- Performance complexity estimation (loop counts, texture samples per pixel)
- Visual correctness review (projection math, UV mapping, lighting)

**Critical checks:**
- No `texture2D` on Web (use `texture()` in modern GLSL)
- No `highp` assumptions on all platforms
- No dynamic loops (some WebGL drivers don't support)
- Verify all uniforms match between Dart `shader.setFloat()` calls and GLSL declarations

---

### `lint-fixer` - Code Quality Agent
**Use for:** Automated code quality fixes

**Responsibilities:**
- Run dart format with auto-fix
- Apply flutter_lints rules
- Dart strict mode validation
- Import organization
- **GLSL formatting** (consistent indentation in shader files)

---

### `build-validator` - Build Verification Agent
**Use for:** Validating production builds

**Responsibilities:**
- Build all platform targets
- Verify bundle contents and sizes
- Check for build warnings
- Validate output artifacts
- **Verify shader assets included** in build output
- **Verify texture assets** bundled at correct resolution

---

### `telemetry-validator` - Error Pipeline Agent
**Use for:** Validating the runtime error telemetry system

**Responsibilities:**
- Verify Vercel endpoint accepts POST and serves GET
- Test error payload schema compliance
- Verify DevOverlay renders correctly in debug mode
- Confirm DevOverlay is tree-shaken from release builds
- Test GitHub Action error fetch workflow
- Verify error batching and retry logic
- Test offline error queueing

---

## Parallel Execution Patterns

### Pre-Commit Validation (Parallel)
Spawn these agents simultaneously:
```
1. test-runner (unit tests)
2. shader-validator (GLSL syntax + sampler audit)
3. security-auditor
4. lint-fixer (check mode)
5. platform-validator (shader compile on iOS + Android + Web)
```

Wait for all. Proceed only if all pass.

### Shader Development (Sequential + Parallel)
```
1. implement shader change - SEQUENTIAL
2. PARALLEL:
   - shader-validator (syntax + uniforms)
   - platform-validator (compile on all 3 targets)
   - performance-profiler (GPU timing)
3. test-runner (visual regression) - SEQUENTIAL
4. lint-fixer (final cleanup) - SEQUENTIAL
```

### Asset Pipeline (Parallel)
```
PARALLEL:
- geo-data-validator (download + process Blue Marble)
- geo-data-validator (download + process ETOPO heightmap)
- geo-data-validator (download + process Earth at Night)
- geo-data-validator (generate shore distance texture)

SEQUENTIAL:
- geo-data-validator (channel pack into RGBA textures)
- build-validator (verify assets in build)
- performance-profiler (bundle size check)
```

### Feature Implementation (Sequential + Parallel)
```
1. explore (understand context) - SEQUENTIAL
2. implement changes - SEQUENTIAL
3. PARALLEL:
   - test-runner
   - shader-validator (if shader changed)
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
- telemetry-validator (error pipeline end-to-end)
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
- Shader/texture context if relevant
```

### Agent Results
Each agent must return:
- Status: pass/fail
- Summary: 1-3 sentences
- Details: expandable findings
- Blockers: if any
- Performance metrics: if applicable (FPS, bundle size, GPU ms)

### Aggregation
Orchestrator must:
1. Wait for all parallel agents
2. Synthesize results
3. Identify conflicts (e.g., shader passes platform-validator but fails performance-profiler)
4. Make go/no-go decision
5. Report to user

---

## Context Boundaries

### What Agents Should Know
- Their specific task scope
- Relevant file paths
- Platform targets
- Performance budgets (60fps, 50MB bundle)
- Sampler limits (4 per pass)
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

### Shader Compilation Failure
1. Identify which platform(s) failed
2. Check for WebGL GLSL ES restrictions
3. Check for sampler count violations
4. Report exact error with line numbers
5. Suggest fix before re-running

### Performance Threshold Failure
1. Report exact metrics vs. target (e.g., "42fps vs 60fps target on iPhone 12")
2. Identify shader complexity hotspot
3. Suggest optimization (reduce iterations, lower texture res, simplify math)
4. Re-profile after fix

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
| Shader validation | shader-validator | Yes |
| Security check | security-auditor | Yes |
| Performance check | performance-profiler | Yes |
| Lint/format | lint-fixer | N/A |
| Cross-platform verify | platform-validator | Yes (by platform) |
| Asset processing | geo-data-validator | Yes (by asset) |
| Error pipeline | telemetry-validator | Yes |
| Pre-commit | ALL | Yes |
| Build verify | build-validator | Yes (by platform) |
