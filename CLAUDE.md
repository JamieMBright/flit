# CLAUDE.md - Flit Project Guidelines

## Core Principles

### Run to Completion
- Never leave tasks incomplete. Finish what you start.
- If blocked, document the blocker and propose solutions before stopping.
- All changes must pass all test suites before considering work done.

### Context Management
- Keep context lean. Spawn agents for discrete tasks.
- Always defer to AGENTS.md when handling multiple tasks.
- Tasks must be context-bound and executed in parallel where possible.
- Summarize learnings; don't carry raw data through conversation.

---

## Project Identity

### Domain
- **Game Development** - We are building an immersive game experience
- **Geography-Based** - Leveraging open-source, open-license geographic data (OSM, Natural Earth, etc.)

### Aesthetic
- **Low-Fi Visual Style** - Intentionally lo-fi, not low-effort
- **Beauty Through Simplicity** - Every pixel serves the immersion
- **Immersive Experience** - The app should feel like a world, not a tool

---

## Platform Requirements

### Cross-Platform First
- **NEVER edit code for just one platform** - Always consider minimum 2 platforms
- Target platforms: iOS, Android, Web
- All UI must use **relative positioning only** - no absolute values
- Test on all platforms before any merge

### Performance
- **Hyper-performant builds are mandatory**
- Profile before and after changes
- No frame drops, no jank, no memory leaks
- Bundle size budgets must be respected

---

## Testing Requirements

All tests must pass before commit. Run in this order:

### 1. Unit Tests
```bash
# Run unit tests with coverage
npm run test:unit -- --coverage
```

### 2. Security Tests
```bash
# Security audit and SAST
npm run test:security
```

### 3. Integration Tests
```bash
# Must cover ALL platforms
npm run test:integration:ios
npm run test:integration:android
npm run test:integration:web
```

### 4. Deployment Tests
```bash
# Simulate deployment to catch issues pre-push
npm run test:deploy
```

### Pre-Commit Checklist
- [ ] All unit tests pass
- [ ] Security scan clean
- [ ] Integration tests pass on iOS, Android, AND Web
- [ ] Deployment simulation successful
- [ ] Linting passes with zero warnings
- [ ] No platform-specific code without cross-platform equivalent

---

## Code Quality

### Linting
- Lint ALWAYS before commit
- Zero warnings policy - warnings are errors
- Use project ESLint/Prettier config

```bash
npm run lint
npm run lint:fix
```

### Style
- Prefer composition over inheritance
- Small, focused functions
- Descriptive naming over comments
- Types everywhere (TypeScript strict mode)

---

## Agent Usage

### When to Use Agents
- Multiple independent tasks - spawn parallel agents
- Deep exploration of codebase
- Complex multi-step implementations
- Cross-platform testing coordination

### Agent Delegation Rules
1. Check AGENTS.md for appropriate agent type
2. Provide clear, bounded context to each agent
3. Run independent agents in parallel
4. Aggregate results before proceeding

---

## Geographic Data Sources (Open License)

Approved data sources:
- **OpenStreetMap (ODbL)** - Base map data
- **Natural Earth (Public Domain)** - Country/region boundaries
- **SRTM/ASTER (Public)** - Elevation data
- **GeoNames (CC-BY)** - Place names

Never use:
- Google Maps data
- Proprietary datasets
- Scraped data without license verification

---

## Build Commands

```bash
# Development
npm run dev              # Start dev server
npm run dev:ios          # iOS simulator
npm run dev:android      # Android emulator

# Testing (run ALL before commit)
npm run test             # All tests
npm run test:unit        # Unit only
npm run test:security    # Security audit
npm run test:integration # All platform integration
npm run test:deploy      # Deployment simulation

# Production
npm run build            # Production build (all platforms)
npm run build:profile    # Build with performance profiling

# Quality
npm run lint             # Check linting
npm run lint:fix         # Auto-fix linting issues
npm run typecheck        # TypeScript validation
```

---

## Commit Protocol

1. Run full test suite: `npm run test`
2. Run linting: `npm run lint`
3. Run typecheck: `npm run typecheck`
4. Verify cross-platform: integration tests for 2+ platforms
5. Commit with descriptive message
6. Push only after all checks pass

---

## Red Lines (Never Do)

- Never skip tests to "save time"
- Never use absolute positioning in UI
- Never add platform-specific code without cross-platform support
- Never commit with linting warnings
- Never use non-open-license geographic data
- Never sacrifice performance for convenience
- Never leave an agent task incomplete
