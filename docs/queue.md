# Task queue

Linear is the queue. Git is the reasoning. This file is the protocol every
agent and interface follows; the short version is in
[`agent-context/AGENTS.md`](../agent-context/AGENTS.md), which is the file
agents actually load.

## Shape

- Workspace `lacopadeeuropa`, one team: **`PER`**.
- **Projects**: one per active repo, plus `Fleet` (hosts, not repos) and
  `No repo`.
- **Statuses**: `Backlog → Todo → In Progress → Done`. `Todo` is the queue and
  the whole of it. `Backlog` is shelved on purpose and is not read.
- **No project = untriaged.** That is the intake state, and it is queryable —
  which is what makes it a state rather than a hope.

## Who may close what

| Label | Means | May an agent close it? |
|---|---|---|
| `agent/fleet` | machine-owned, reconciled from host state | yes — on N consecutive clear sweeps, never one |
| `agent/sec` | machine-owned, reconciled from scanner state | yes — same rule |
| `needs:choco` | blocked on Ignacio: a decision, or something physical | no |
| *(no label)* | his | **no** |

Removing an `agent/*` label is the **adopt** gesture: it moves the issue from
the machine to a human and auto-close stops applying.

`agent/*` issues **never notify**. `#home-alerts` pages; the tracker does not.

## Writing an issue

Three to five lines plus a pointer to the repo, and **never the prose**. The
write-up belongs in the repo's `docs/` — `TODO.md`,
`ARCHITECTURE_DECISIONS.md`, `archive/DONE.md`. If an issue needs reading
twice, it is too long.

**Carry the do-nots.** Most items in this queue exist because something was
once done in the wrong direction. An issue that omits what not to do invites
the same mistake.

Due dates replace "review on or after" prose. Priority maps to the bands:
Urgent = hurting now, High = known risk, Medium/Low = improvement.

A queue is for **actions, not findings**. A finding with no next action goes to
the repo's `DONE.md` with its reopen condition, or onto the idea shelf — not
into `Todo`, where it becomes something to read past forever.

## Queries

Intake sweep — untriaged and still open. **Raw GraphQL only; the Linear MCP
server cannot express this filter:**

```graphql
issues(filter: {
  project: { null: true },
  state:   { type: { nin: ["completed", "canceled"] } }
})
```

The `state` clause is not optional. Without it, closed and cancelled intake
keeps matching forever — the same never-retracts failure in a different shape.

The queue itself is `state = Todo`, ordered by priority. For "what can I pick
up right now", exclude `needs:choco`.

## Working an item

1. Take it from `Todo`; move it to `In Progress`.
2. **Read the git pointer first.** The issue is deliberately not
   self-contained.
3. Work on a branch.
4. **Verify by forcing the condition.** A check that stopped complaining is
   not a check that works.
5. Write the reasoning to the repo, not to Linear.
6. Close it — or hand it back, stating plainly what was not verified.

## Unattended work

Fine: research, investigation, and writing — anything whose deliverable is a
verdict or a document.

Not fine: anything whose acceptance criterion is a forced failure against a
live host. Most fleet items say so explicitly. An agent that cannot run the
check cannot honestly close the issue, so it hands back the finding instead.

## Not built yet

Recorded so no agent assumes otherwise:

- **Nothing writes to this queue automatically.** There is no agent-lxc sweep
  and no scanner reconciliation. Every issue was created by hand.
- Auto-close, the key→issue map in `~/.agent/`, and the per-run heartbeat
  (`swept N, opened M, closed K`) are designed and unbuilt.
- Scanner intake will be **poll-and-reconcile, never push**. An event cannot
  retract, and a finding that outlives its condition is the exact failure this
  system exists to prevent.
- Linear holds **no logic**, deliberately — the key→issue map lives on the
  box. That is what keeps the exit cheap.
