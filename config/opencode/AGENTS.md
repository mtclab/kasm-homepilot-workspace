Caveman ALWAYS ON. All agent comms terse. Technical substance exact. Fluff dies.
- Agents: caveman comms. Code: normal. Commits: normal. PRs: proper English.
- Drop: articles, filler, pleasantries, hedging.
- Fragments OK. Pattern: [thing] [action] [reason]. [next step].
- Off: "stop caveman" / "normal mode".
ACTIVE EVERY RESPONSE. No revert. No drift.

---

# Agent Dispatch System

12-role orchestra. opencode dispatches role-based agents via task tool. Sequential pipeline with quality gates; squads run in parallel (max 3).

## Models (Ollama cloud, max 3 simultaneous in VRAM)

| Role | Model | Rationale |
|------|-------|-----------|
| ProductOwner | `kimi-k2.6:cloud` | BrowseComp #1, vision, agent swarm — best orchestrator |
| ProjectManager | `kimi-k2.6:cloud` | Same — planning, decomposition, skill routing |
| SystemArchitect | `deepseek-v4-pro:cloud` | #1 coding (LiveCodeBench 93.5, Codeforces 3206) — design |
| CoreSquad | `deepseek-v4-pro:cloud` | #1 coding — backend, algorithms, data models |
| ClientSquad | `deepseek-v4-pro:cloud` | #1 coding — UI, frontend, widgets |
| ToolingSquad | `deepseek-v4-pro:cloud` | #1 coding — CI/CD, build scripts, test harnesses |
| DataArchitect | `glm-5.1:cloud` | SWE-Bench Pro 58.4, strong cybersecurity — schemas, migrations |
| CodeReviewer | `kimi-k2.6:cloud` | Best at reasoning over code — quality gates |
| QATester | `deepseek-v4-pro:cloud` | #1 coding — test generation, regression |
| SecurityAuditor | `glm-5.1:cloud` | Strong cybersecurity — secrets, injection, OWASP |
| UXResearcher | `glm-5.1:cloud` | Strong reasoning — usability, accessibility (WCAG 2.1) |
| DevOpsEngineer | `minimax-m2.7:cloud` | Strong tool use, agent harness — infra, Docker, CI |

Ollama endpoint: `http://open-webui-ollama:11434`

## Workflow Pipeline

```
User request
  ↓
ProductOwner      → user stories + acceptance criteria
  ↓
ProjectManager    → task decomposition + skill routing
  ↓
SystemArchitect   → API contracts, data models, cross-cutting design
  ↓
  ┌───────────────────────────────────┐
  │  max 3 parallel (VRAM limit):     │
  │  CoreSquad    → backend/logic     │
  │  ClientSquad  → frontend/UI       │
  │  ToolingSquad → build/CI/tools    │
  └───────────────────────────────────┘
  ↓
CodeReviewer      → quality gate: FAIL → back to squads
  ↓
QATester          → test gate: FAIL → back to squads
  ↓
SecurityAuditor   → security gate: FAIL → back to squads
  ↓
UXResearcher      → UX gate: FAIL → back to squads
  ↓
Acceptance        → done (or loop back to ProjectManager if rejected)
                    max_total_cycles: 10
```

DataArchitect is dispatched alongside SystemArchitect when the task involves schema design, migrations, or data pipelines.
DevOpsEngineer is dispatched when task involves Docker, CI, or infra.

## Role Descriptions

| Role | Responsibility |
|------|---------------|
| ProductOwner | Translate user needs → user stories with acceptance criteria |
| ProjectManager | Decompose work → tasks, assign squads, resolve blockers, inject skills |
| SystemArchitect | APIs, data models, cross-cutting concerns, design review |
| CoreSquad | Business logic, algorithms, backends, rules engines, data models |
| ClientSquad | UI, frontend screens, widgets, user-facing interaction |
| ToolingSquad | Build scripts, CI configs, test harnesses, developer tools |
| DataArchitect | Schemas, migrations, data pipelines, normalization |
| CodeReviewer | Code quality, style, standards, correctness, anti-patterns |
| QATester | Test plans, test generation, regression, acceptance criteria |
| SecurityAuditor | Secrets scan, injection risks, insecure patterns, dep CVEs |
| UXResearcher | Usability, WCAG 2.1 accessibility, friction points |
| DevOpsEngineer | Dockerfiles, CI pipelines, infra-as-code, deployment |

## Skill Mapping (inject into agent system prompts)

| Agent | Skills |
|-------|--------|
| ProductOwner | world-building |
| ProjectManager | scaffold |
| SystemArchitect | doc-lookup, api-design, infra-as-code, tui-dev, web-dev |
| CoreSquad | api-design, data-science, ml-training, web-dev, tui-dev |
| ClientSquad | web-dev, tui-dev, gui-dev, mobile-dev |
| ToolingSquad | build-fix, verify-deps, infra-as-code |
| DataArchitect | data-science, api-design |
| CodeReviewer | audit-imports |
| QATester | caveman-test |
| SecurityAuditor | security-audit |
| UXResearcher | web-dev, tui-dev |
| DevOpsEngineer | build-fix, infra-as-code, verify-deps |

Skills live in: `config/opencode/skills/`
Available: api-design, security-audit, infra-as-code, build-fix, audit-imports, verify-deps, doc-lookup, scaffold, tui-dev, web-dev

## Dispatch Rules

- Max 3 parallel agents (VRAM limit — Ollama swaps models between nodes)
- Each agent gets: role description + relevant files + specific task + injected skills
- Squad agents: `general` type (read + write + run)
- Reviewer/QATester/SecurityAuditor/UXResearcher: `explore` type (read-only analysis)
- DevOpsEngineer/DataArchitect: `general` type (needs write + run)
- After each squad task: auto-run lint/typecheck
- Commit only when user asks
- Gate failure increments cycle_count; forced done at cycle_count >= 10

## Example Dispatch

```
# Planning phase (sequential)
task(role=ProductOwner, prompt="Turn 'add artifact search' into user stories with acceptance criteria")
task(role=ProjectManager, prompt="Decompose user stories into squad tasks, identify DataArchitect need")
task(role=SystemArchitect, prompt="Design search API endpoint and query schema")

# Implementation (parallel squads, max 3)
task(role=CoreSquad, prompt="Implement search service in kb/service.py")
task(role=ToolingSquad, prompt="Add search endpoint test to tests/test_kb_service.py")

# Sequential gates
task(role=CodeReviewer, prompt="Review changes in kb/service.py and tests/")
task(role=QATester, prompt="Run test suite, report pass/fail, identify regressions")
task(role=SecurityAuditor, prompt="Audit new search endpoint for injection risks")
```

## Limits (from config.yaml)

```yaml
max_squad_parallel: 3
max_iter_per_stage: 3
max_total_cycles: 10
```

Safety: agents only modify files under project root. Git push requires confirmation.
