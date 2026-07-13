# Research Dashboard

A minimal, GitHub-native framework for managing research **state and decisions** — not implementation tasks. Each project keeps its code and experiments in its own repository; this repo is the management layer on top.

- **Live dashboard:** https://jiminc77.github.io/research-dashboard/dashboard/
- **User guide:** https://jiminc77.github.io/research-dashboard/guide/

---

## Operating model

```text
Docs   = Knowledge      (plans, specs, reports — the "why" and "what")
Issues = State          (one issue per milestone; labels are the state machine)
Labels = Flow           (ready → running → verify → done)
Code   = Evidence       (implementation + reproducible outputs, in the code repo)
```

Rule of thumb: **docs, issues, and code stay separate.** An issue records *where a milestone is*, not how it was built.

---

## Repository split

Each project uses two repositories:

| Repo | Role |
|---|---|
| **research-dashboard** (this) | Management: research plans, specs, milestone & decision issues, phase reports, references, and the dashboard pipeline. |
| **project code repo** | Implementation: code, configs, run outputs, metrics, plots, and evidence reports. |

This repo contains no implementation code.

---

## How it works

**Phases and milestones.** A project's work is organised as phases (`P0`, `P1`, …). Each phase is split into milestones (`P{k}-M{n}`), and each milestone is one issue in that project's code repo. An agent executes the milestone; a report/evidence commit closes it. Gate thresholds and predictions are fixed in the project's plan up front — changing one requires a separate **Decision** issue, not a quiet edit.

**Label state machine.** Every development issue carries exactly one `state:` label:

```text
ready → running → verify → done
             │
             ├── blocked-human   (waiting on a HUMAN GATE verdict)
             └── blocked-tech    (CI failure / 3-strike)
```

**Human gates.** At a gate, the agent posts a `GATE REQUEST` and the issue moves to `blocked-human`. Only the human owner resolves it, by posting a `GATE VERDICT` comment (with an explicit `choice:`) from their own account; verdicts from any non-human account are automatically rejected. A watcher daemon then signals the live agent session to fetch and re-verify the verdict — it never injects the verdict text itself.

**Issue types.** Only three:

| Type | Use for |
|---|---|
| Milestone | One research milestone |
| Decision | A direction decision (GO / PIVOT / NO-GO, or a pre-registered value change) |
| Experiment Result | A result that drives a decision |

Progress updates are comments inside the active milestone issue, not new items:

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
  <slug>/
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

## Projects

Registered projects live under `projects/<slug>/`. See the live dashboard for current status.

| Project | Description |
|---|---|
| [DGCC](projects/dgcc/) | Deformation-Grounded Contact Critics — how value functions should represent contact actions for deformable-object manipulation. [Research plan](https://jiminc77.github.io/research-dashboard/projects/dgcc/research/DGCC_research_plan.html) |

---

## Adding a project

1. Copy `projects/_template.yml` to `projects/<slug>/project.yml` and fill in owner, management repo, and code repo.
2. Add the project's research plan under `projects/<slug>/research/`.
3. Copy the `research-ops/workflows/` kit into the project's code repo.

The dashboard picks up the new project automatically on its next run.
