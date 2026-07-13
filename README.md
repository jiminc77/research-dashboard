# Research Dashboard

A minimal, GitHub-native workspace for running research. It tracks research **state and decisions** — not implementation tasks. Code and experiments live in a separate repository; this repo is the management layer on top of them.

Reusable across projects. Currently hosting one project: **DGCC** (Deformation-Grounded Contact Critics).

- **Live dashboard:** https://jiminc77.github.io/research-dashboard/dashboard/
- **User guide:** https://jiminc77.github.io/research-dashboard/guide/
- **DGCC research plan:** https://jiminc77.github.io/research-dashboard/projects/dgcc/research/DGCC_research_plan.html

---

## Operating model

```text
Docs   = Knowledge      (plans, specs, reports — the "why" and "what")
Issues = State          (one issue per milestone; labels are the state machine)
Labels = Flow           (ready → running → verify → done)
Code   = Evidence       (implementation + reproducible outputs, in the code repo)
```

The rule of thumb: **docs, issues, and code stay separate and never mix responsibilities.** An issue records *where a milestone is*, not how it was built.

---

## Repositories

| Repo | Role |
|---|---|
| **research-dashboard** (this) | Management: research plans, specs, milestone & decision issues, phase reports, references, and the dashboard pipeline. |
| **[DGCC](https://github.com/jiminc77/DGCC)** | Implementation: environment/RL code, configs, run outputs, metrics, plots, and evidence reports. |

This repo contains no implementation code.

---

## Current status

The live dashboard and `projects/dgcc/research/status.json` are the source of truth. At a glance:

| Phase | Scope | Status |
|---|---|---|
| **P0** | Environment & pilot: two-simulator bring-up, δm pipeline, G1/G2 gates, constants lock | ✅ Done — GO, signed off 2026-07-03 |
| **P1** | Baseline: HACMan-style black-box contact critic, T1/T2 training, latent-extraction API | 🔵 In progress |
| **P2** | Probing gate: frozen-critic probe suite + Controls A–F, Go/Pivot decision | ⚪ Next |
| **P3** | Structure-comparison gate: V1/V2/V3 variants vs. required controls | ⚪ Backlog |
| **P4** | Main training of the selected variant across T1–T3 | ⚪ Backlog |
| **P5** | Mechanism analysis: stationarity, probe transfer, reward-free adaptation | ⚪ Backlog |
| **P6** | OOD (primary axis: length) and ablations; kill-criterion decision | ⚪ Backlog |
| **P7** | Writing and submission (target: CoRL 2027) | ⚪ Backlog |

Milestones are pre-registered: every gate threshold, prediction, and kill criterion is fixed in the research plan *before* results are seen. Thresholds are never changed to pass a gate; changing one requires a separate **Decision** issue.

---

## How it works

**Phases and milestones.** Work is organised as phases `P0`–`P7`. Each phase is broken into milestones (`P{k}-M{n}`), and each milestone is one issue in the DGCC code repo. The implementing agent executes a milestone; a report/evidence commit closes it.

**Label state machine.** Every development issue carries exactly one `state:` label:

```text
ready → running → verify → done
             │
             ├── blocked-human   (waiting on a HUMAN GATE verdict)
             └── blocked-tech    (CI failure / 3-strike)
```

**Human gates.** At a gate, the agent posts a `GATE REQUEST` and the issue moves to `blocked-human`. Only the human owner resolves it, by posting a `GATE VERDICT` comment (with an explicit `choice:`) from their own account. Verdicts written by any non-human account are automatically rejected. A watcher daemon then signals the live agent session to fetch and re-verify the verdict — it never injects the verdict text itself.

**Issue types.** Only three:

| Type | Use for |
|---|---|
| Milestone | One research milestone |
| Decision | A direction decision (GO / PIVOT / NO-GO, or a pre-registered value change) |
| Experiment Result | A result that drives a decision |

Weekly progress is a comment inside the active milestone issue, not a new item:

```text
State:
Blocker:
Next:
```

**Dashboard pipeline.** `.github/workflows/dashboard-data.yml` runs every 15 minutes (and on `projects/**` changes). It scans each `projects/*/project.yml`, pulls all issues from that project's management and code repos via the GitHub API, and bakes a snapshot to `dashboard/data.json` on the `data` branch. The static dashboard reads that snapshot instead of calling the GitHub API on every page load, falling back to a live API call only if the snapshot is missing or stale.

---

## Layout

```text
projects/
  _template.yml                 # template for a new project
  dgcc/
    project.yml                 # registry: owner, repos, docs base, phase status
    research/                   # research plan (.md/.html) + status.json overlay
    reports/                    # phase reports and gate decisions
    implementation/             # implementation & phase specs
    references/                 # papers
research-ops/                   # reusable kit
  ORCHESTRATOR.md, PROTOCOL.md, SESSION_B.md
  scripts/                      # bootstrap, phase setup, linters, safe-comment
  templates/                    # issue / spec / report / plan templates
  workflows/                    # gate-notify, evidence-verify, phase-transition, pr-verify
  gate-watcher/                 # daemon that relays gate verdicts to the agent session
dashboard/                      # static dashboard app (reads data.json)
guide/                          # user guide
```

---

## Starting a new project

1. Copy `projects/_template.yml` to `projects/<slug>/project.yml` and fill in owner, management repo, and code repo.
2. Add the project's research plan under `projects/<slug>/research/`.
3. Copy the `research-ops/workflows/` kit into the code repo.

The dashboard picks up the new project automatically on the next run.
