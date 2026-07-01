# GitHub Project Setup

Use GitHub Projects only as a simple visual flow tracker.

---

## Create Project

1. Open the repository.
2. Go to **Projects**.
3. Create a new project.
4. Choose **Board** or **Table**.
5. Add issues from this repository.

---

## Recommended Columns

```text
Ideas → Current → Need Advisor → Done
```

Column meaning:

| Column | Meaning |
|---|---|
| Ideas | Possible directions, readings, experiments |
| Current | Active work only; keep 1–3 issues max |
| Need Advisor | Requires feedback, decision, resource, or review |
| Done | Completed, rejected, or archived |

---

## Minimal Fields

If using Table view, add only these fields:

| Field | Type | Purpose |
|---|---|---|
| Stage | Single select | Planning / Experiment / Analysis / Writing / Review |
| Status | Single select | On Track / At Risk / Blocked |
| Updated | Date | Last meaningful update |
| Advisor | Checkbox | Needs advisor attention |

Avoid adding more fields until the workflow feels stable.

---

## Advisor View

Filter:

```text
is:open
```

Sort:

```text
Advisor desc, Updated desc
```

Show only:

- Title
- Stage
- Status
- Updated
- Advisor

---

## Rule

A good Project view should show the research flow, not every task.

If the board has more than 10 active items, close or archive aggressively.