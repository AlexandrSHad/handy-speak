Documents reflecting the continuous improvement process of the application.

Improvement types:
- architecture

General process:
The round is run by an agent team, defined in `.claude/agents/`: the **conductor** (orchestrates the round, owns this process doc), the **surveyor** (S1), the **cross-examiner** (S2), the **builder** (S3 implementation), and the **gatekeeper** (S3 review, two axes). Each definition is the single source of truth for its role's prompt — the steps below say who does what and which artifacts move between them.

- create a folder for the current improvement round `<round-number>-<improvement-type>`
- S1 — perform a review of a requested type via the **surveyor**; if type is not specified ask user, if type is not defined say to user and stop → `S1-<improvement-type>-review.md`
- S2 — analyze first three critical issues (or less if their number is smaller) and perform a deep analysis via the **cross-examiner** → one `S02-issue-<issue-number>.md` per issue + `S02-issues-implementation-sequence.md` (order, parallelism/worktree plan, merge protocol)
- S3 — the **conductor** runs the implementation loop over the sequence, one issue per branch/PR, repeating until the sequence is exhausted:
  - the **builder** implements the next not-yet-implemented issue: branch `r<round-number>/c<issue-number>-<short-slug>` off the up-to-date `main` (R1 precedent: `r1/c1-phrase-model`), implement exactly per the `S02-issue-<issue-number>.md` file, run the local gate — `puro flutter analyze` + `puro flutter test`, with M8/CI deferred it is the only gate — write `S3-issue-<issue-number>-pr-summary.md`, and create the PR with the gh CLI: title `<type>(r<round-number>): <one-line summary of the change> (C<issue-number>)` (R1 precedent: `refactor(r1): move Phrase to lib/data/phrase.dart + layering guard (C1)`), the pr-summary file as the PR description
  - the **gatekeeper** reviews the PR along two axes — **Spec** (the diff against the S02 issue file and the pr-summary description, including claims the code must back) and **Standards** (the repo's documented conventions) — and posts findings; the builder addresses them on the branch, re-runs the gate after every review round, and records the rounds in the pr-summary; the gatekeeper is a fresh instance per PR — the author never reviews their own work
  - the human merges — the merge authority while M8/CI is deferred
  - after the PR merges: the conductor runs the sequence's integration checklist (gate re-run on the combined `main`); the next issue branches off the updated `main`

Folder structure
./R<round-number>-<improvement-type>/
   S1-<improvement-type>-review.md
   S02-issue-<issue-number>.md
   S02-issues-implementation-sequence.md
   S3-issue-<issue-number>-pr-summary.md
