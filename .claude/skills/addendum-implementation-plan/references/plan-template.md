# Plan file template

This is the shape a `planning/*-plan.md` file should follow. It's modeled
on a plan that worked well for this repo — concrete enough for an agent (or
you) to implement directly without re-deriving context.

```markdown
# HandySpeak — <Addendum title>

## Context

Summarize what the addendum specifies, in your own words. Name the exact
addendum file and full handoff zip this plan is derived from. Repeat the
addendum's scope-confirmation statement here so the plan is self-contained.
Note any decisions already agreed with the user during Phase 1 alignment
(e.g. "spec surfaces absent from the Flutter app are N/A, skip").

Note key codebase facts relevant to implementation — framework quirks,
existing patterns being followed, file locations that matter.

## Implementation steps

Organize by file. For each file touched:

### N. <short description> — `path/to/file.dart`

Concrete instructions: what to add/change, referencing existing patterns
in this codebase by name (e.g. "mirror the `_kHaptics` pattern"). Include
line numbers where known. Include code snippets for anything non-obvious
(e.g. a new extension method, a tricky layout calculation).

## Commit sequence

A short ordered list of logical commits (e.g. additive state/i18n changes
first, then UI wiring, then behavior changes), so implementation can
proceed incrementally with `flutter analyze` (or repo-appropriate lint/
build check) after each step.

## Risks

Call out the highest-risk parts of the implementation explicitly — e.g.
"passing the wrong value to onTap could leak into stored text/TTS." Note
anything that needs a deliberate design tradeoff (e.g. stale toggle state
edge cases) so it isn't discovered as a surprise during review.

## Verification

A checkbox list, split by feature, of what to manually or automatically
verify — grounded in what's actually testable in the current dev
environment (e.g. web/Chrome only if no Android SDK is available locally).
Include both languages (EN/CS) explicitly wherever text or input is
involved, and confirm persistence/settings behavior where relevant.
Split this section in the following categoreis:
 - Unit tests
 - Integration tests
 - Manual checks (avoid manual checks if possible)

## Critical files

A flat list of every file this plan touches, for quick review reference.
```
