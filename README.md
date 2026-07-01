# DGCC Research OS

Minimal GitHub-based research management workspace for DGCC.

This repository tracks **research state**, not implementation tasks.

```text
Docs = Knowledge
Issues = State
Project = Flow
Code repo = Evidence
```

---

## Current Snapshot

| Field | Current |
|---|---|
| Current Milestone | [Go/No-Go 0 — Rope Response Probe](https://github.com/jiminc77/research-dashboard/issues/5) |
| Phase | A — Task Feasibility |
| Decision | Pending |
| Main Question | Does a standard black-box Bellman critic already encode contact-induced deformation response? |
| Next | Finish Phase A task specification and implementation gate |
| Manual | [`docs/research_ops_manual.html`](docs/research_ops_manual.html) |

---

## Repository Split

Use two repositories.

| Repo | Purpose |
|---|---|
| `research-dashboard` | Research management, docs, milestone issues, decisions, reports, references |
| `dgcc` | Implementation code, configs, branches, PRs, outputs, metrics, plots |

This repo should not contain main implementation code.

---

## Project Setup

Create one GitHub Project named:

```text
DGCC Research
```

Columns:

```text
Backlog → Current → Blocked → Done
```

Fields:

```text
Status
Phase
Decision
Doc
Updated
```

Do not use a `Stage` field. The Project item itself is the milestone.

---

## Milestone Issues

| Issue | Status |
|---|---|
| [DGCC Research Blueprint](https://github.com/jiminc77/research-dashboard/issues/4) | Done |
| [Go/No-Go 0 — Rope Response Probe](https://github.com/jiminc77/research-dashboard/issues/5) | Current |
| [Go/No-Go 1 — Architecture Constraint](https://github.com/jiminc77/research-dashboard/issues/6) | Backlog |

Decision record:

- [Use minimal rope_response_probe for GNG-0](https://github.com/jiminc77/research-dashboard/issues/7)

---

## Issue Types

Use only three active templates:

| Type | Use when |
|---|---|
| Milestone | Tracking one major research milestone |
| Decision | Recording a research direction decision |
| Experiment Result | Recording a result that affects a decision |

Weekly updates should be comments inside the active milestone issue, not separate Project items.

```text
State:
Blocker:
Next:
```
