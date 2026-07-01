# Research Dashboard

A minimal research progress tracking system for advisor review.

Goal: let an advisor understand the current state of the research in 1–3 minutes.

---

## Current Snapshot

| Field | Current |
|---|---|
| Research Question | _What is the central question right now?_ |
| Current Stage | `Planning / Experiment / Analysis / Writing / Review` |
| Status | `On Track / At Risk / Blocked` |
| Latest Evidence | _Figure, result, issue, or notebook link_ |
| Main Blocker | _What prevents progress?_ |
| Next Objective | _What happens next?_ |
| Advisor Decision Needed | _Yes / No — specific decision if needed_ |
| Last Updated | YYYY-MM-DD |

---

## Current Flow

```text
Idea → Experiment → Result → Decision → Paper
```

Only track items that affect the research story. Avoid task clutter.

---

## Minimal GitHub Project Setup

Create one GitHub Project and add issues from this repository.

Recommended columns:

```text
Ideas → Current → Need Advisor → Done
```

Keep `Current` to 1–3 items max.

Recommended views:

1. **Advisor View** — filter open issues, show only current work and advisor-needed items.
2. **Timeline View** — group by research stage or milestone.
3. **Archive View** — closed issues only.

---

## Issue Types

Use only three issue types:

| Type | Purpose |
|---|---|
| Experiment | Track one research test or result |
| Weekly Update | Summarize weekly/biweekly progress |
| Decision | Record why the direction changed |

---

## Operating Rule

Every week, update only three things:

1. Current result
2. Current blocker
3. Next objective

If a PI opens this repo, the README should explain the current state immediately. Issues provide the evidence trail.