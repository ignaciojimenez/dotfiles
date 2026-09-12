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

### The three states, and why intake is not `Triage`

`Backlog` carries two meanings, told apart by the project field — so read both:

| Status | Project | Means |
|---|---|---|
| `Todo` | set | the queue |
| `Backlog` | **none** | **untriaged intake** — captured, not yet judged |
| `Backlog` | set | shelved on purpose, not read |

**Untriaged is defined by having no project, not by a status.** The intake sweep
below keys on `project: null` and ignores status, so an item captured from a
phone lands wherever the capturing client puts it and is still found.

🔴 **Do not enable Linear's Triage feature to "fix" this.** Verified working
2026-09-06: an issue captured from the Claude mobile app landed in `Backlog`
with no project and the sweep returned it. Triage would add a dependency for
something already solved, and Linear holding no logic is what keeps the exit
cheap.

## The label contract

Three groups, each answering a different question. Groups are mutually exclusive
in Linear, which is the point: an issue has one owner, one current blocker, one
kind.

### `agent/*` — who may close it

| Label | Means | May an agent close it? |
|---|---|---|
| `agent/fleet` | machine-owned, reconciled from host state | yes — on N consecutive clear sweeps, never one |
| `agent/sec` | machine-owned, reconciled from scanner state | yes — same rule |
| *(neither)* | Ignacio's | **no** |

Removing an `agent/*` label is the **adopt** gesture: it moves the issue from the
machine to a human and auto-close stops applying.

`agent/*` issues **never notify**. `#home-alerts` pages; the tracker does not.

### `needs/*` — what blocks it right now

| Label | Means | Doable from a phone? |
|---|---|---|
| `needs/decision` | blocked on Ignacio's judgement | **yes** |
| `needs/hands` | blocked on physical access to hardware | no, and no agent will ever do it |
| `needs/laptop` | blocked on a real working session — shell, repo, tests | not today; an agent with a shell satisfies it |
| *(none)* | nothing blocking | yes |

🔴 It records what blocks it **now**, not everything it will eventually need. An
issue awaiting sign-off is `needs/decision` even though the work then wants a
laptop; the label changes when the decision lands.

📌 `needs/laptop` is a statement about the *work*, not about who is available.
When an executor has a shell of its own it satisfies that requirement without
anything being relabelled.

### `kind/*` — what sort of work

`broken` · `risk` · `debt` · `new` · `improvement`

Orthogonal to priority: a broken thing can be low priority and a new capability
can be urgent. It matters most to an executor, because **a fix has an obvious
acceptance test — the broken thing works — and a new capability does not.**
`risk` is the one that is easy to miss: works today, known weakness or
unverified control.

### Size

**Not a label.** `effort` is a reserved name in Linear because estimates are a
first-class field; the team uses t-shirt estimates, which sort and filter
without spending labels.

### Addressing grouped labels

Linear stores a grouped label's name *without* its group, so a bare `decision`
or `new` is ambiguous across groups. Everywhere above the tracker adapter,
labels are written as `parent/child` — `agent/fleet`, `needs/laptop`. The
adapter composes on read and resolves on write.

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
up right now", exclude `needs/decision` and `needs/hands`; add
`estimate: {lte: 2}` for what fits an hour.

## Working an item

1. Take it from `Todo`; move it to `In Progress`.
2. **Read the git pointer first.** The issue is deliberately not
   self-contained.
3. Work on a branch.
4. **Verify by forcing the condition.** A check that stopped complaining is
   not a check that works.
5. Write the reasoning to the repo, not to Linear.
6. Close it — or hand it back, stating plainly what was not verified.

## Finishing something you may not close

An agent that verifies a human-owned issue is done and then says nothing leaves the
queue stale — which is the disease this system exists to cure, arriving by the back
door. Silence is not deference.

So there are three outcomes, not two:

| Situation | Do |
|---|---|
| `agent/*` issue, condition clear N sweeps running | close it |
| Human-owned issue, acceptance criterion **met** | **comment with the evidence, move to `In Review`** |
| Anything you could not verify | say so, leave it in `Todo` |

`In Review` means *an agent believes this is done and a human has not confirmed it.*
It is the only use of that status. Closing stays with whoever owns the issue.

🔴 The comment must carry **the evidence and its limits**, not a verdict. "Pushed at
20:33 per the local reflog; that proves the push happened, it is not a live read of
the remote" is useful. "Done ✅" is not.

## Unattended work

Fine: research, investigation, and writing — anything whose deliverable is a
verdict or a document.

Not fine, **today**: anything whose acceptance criterion is a forced failure
against a live host. Most fleet items say so explicitly. An agent that cannot
run the check cannot honestly close the issue, so it hands back the finding
instead.

### Where this is going

The target is that an executor takes an issue from `Todo` and carries it all
the way to a tested change on a branch, then hands it back at `In Review` for a
human to read the diff, tap, and deploy. Only three things stay human, and only
one of them is a limitation:

| Stays human | Why |
|---|---|
| `needs/decision` | it is a judgement, not a task. An agent researches and recommends; the call is Ignacio's |
| `needs/hands` | nothing else can stand at the cabinet with a tape measure |
| the deploy tap | by design — every command gated by an `ask` *and* a biometric tap. One signature means one human was present |

🔴 **`needs/laptop` is not on that list, and that is the point.** It says the
work needs a shell, a checkout and a test — not that it needs *Ignacio*. An
executor with its own shell satisfies it, and nothing has to be relabelled for
that to become true.

📌 **The container rig is what unlocks this, which makes it a prerequisite
rather than hygiene.** "Force the condition and watch the alert fire" is
unrunnable for an agent against production and perfectly runnable against a
container it can create and destroy. Until that exists, every fleet issue has
to be verified by a human, so an executor can draft but never finish. The
operator-mode design already assumes it: approval means seeing a diff **and** a
container test result, never a command that has run nowhere.

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
