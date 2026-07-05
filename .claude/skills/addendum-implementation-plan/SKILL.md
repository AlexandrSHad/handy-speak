---
name: addendum-implementation-plan
description: Turns a HandySpeak design addendum (design/handoffs/ADDENDUM-*.md, from Claude Design) plus the current design/handoffs/HandySpeak-handoff.zip into a verified, aligned implementation plan for this Flutter repo. Use this any time the user mentions an addendum, a new handoff, "implement this design change," or references files under design/handoffs/ — even if they don't say "skill" or "plan" explicitly. Always run this before writing any Flutter code for a design-driven change. Do not skip straight to coding from an addendum.
---

# Implement Addendum

HandySpeak (`d:\pet-projects\handy-speek\`) receives incremental design
changes as **addendum** documents from Claude Design, paired with a
regenerated full handoff zip. This skill turns that pair into an
implementation plan grounded in this repo's actual source — **the repo is
the source of truth**, not the addendum's assumptions about it.

This is a two-phase process. **Do not skip phase 1.** A plan file must
never be written while anything is unresolved.

---

## Phase 1 — Analyze and align (no files written yet)

### 1. Identify the addendum to implement

- If the user names a specific addendum, use that one.
- Otherwise, look in `design/handoffs/` for `ADDENDUM-<NN>_*.md` files and
  check `planning/` for a matching `*-plan.md`. The addendum with no
  corresponding plan file is the one to implement. If more than one
  qualifies, ask the user which one, don't guess.

### 2. Read both inputs fully

- The addendum markdown doc — this is the semantic spec: what changed, why,
  which surfaces are affected, i18n strings, acceptance criteria, and
  anything explicitly deferred.
- `design/handoffs/HandySpeak-handoff.zip` — current visual/structural
  reference. Unzip and inspect; treat its HTML/CSS/JS as reference only,
  never as importable code (this project is Flutter/Dart, not React).
- Check the addendum for its scope-confirmation line (something like *"the
  new design was diffed against the old prototype — it changes nothing
  beyond these N features: ..."*). If it's present, trust the stated scope.
  If it's missing or vague, that's itself a gap to raise with the user in
  step 4 — don't silently re-derive scope yourself from the zip.

### 3. Cross-reference against the actual repo

For every surface, setting, or behavior the addendum describes:
- Find the real file(s) and line(s) in this Flutter codebase it maps to.
  Follow the existing pattern of similar prior features (e.g. how an
  existing parent setting is wired end-to-end: state controller → ARB
  strings → settings UI → consuming widgets) rather than inventing a new
  pattern.
- Check every color/spacing/typography value against `lib/core/theme.dart`
  (or wherever this repo's design tokens live). Reuse existing tokens;
  never plan to inline a new raw value if an equivalent token already
  exists.
- Note where the addendum assumes a UI surface that doesn't exist yet in
  this Flutter app (e.g. the addendum references a POC/web surface with no
  Flutter equivalent) — that's a gap, not something to invent silently.

### 4. Check feasibility — report before proceeding if ANY of these are true

Stop and report to the user, in plain language, rather than guessing or
proceeding, if you find:
- **A conflict or contradiction** — e.g. the addendum's described behavior
  contradicts how an existing, related feature already works in this repo.
- **Something unclear or underspecified** — e.g. a setting's default isn't
  stated, or "affected surfaces" doesn't obviously map onto real widgets.
- **Something that isn't doable as described** — e.g. it assumes a
  capability the current architecture doesn't support, or a referenced
  file/surface doesn't exist in this Flutter codebase.
- **A missing or vague scope-confirmation line** in the addendum (see
  step 2).

When reporting, be specific: name the exact section of the addendum, what
you found (or didn't find) in the repo, and what you need from the user to
resolve it (a decision, a clarification, or confirmation that a gap is
acceptable to defer). **Do not proceed to Phase 2 until the user has
responded and everything is aligned.**

If everything checks out cleanly, say so briefly and move to Phase 2
without waiting for a confirmation round-trip.

---

## Phase 2 — Write the plan (only once aligned)

### 5. Write the plan file

- Location: `planning/`
- Filename: the addendum's base name with `-plan` appended before the
  extension — e.g. addendum `ADDENDUM-01_big-letters-phrase-strip.md`
  becomes `planning/ADDENDUM-01_big-letters-phrase-strip-plan.md`.
  (If you actually want the plan named some other way — e.g. `-plan`
  as a prefix instead of a suffix — say so and this skill should be
  updated to match.)
- Structure: see `references/plan-template.md` for the exact shape to
  follow (context, per-file implementation steps with concrete code
  references, commit sequence, risks, a verification checklist grounded in
  what's actually testable in this environment, and a critical-files list).
  This structure previously produced a high-quality, directly actionable
  plan for this repo — keep following it.
- Every plan must include:
  - File:line-level implementation steps, not vague descriptions.
  - An AAC checklist pass: contrast, shape simplicity, no realistic faces,
    touch target size.
  - A Czech + English pass for anything touching text or input.
  - Explicit test requirements (widget tests / golden tests for UI,
    unit tests for logic, test-first for any bugfix bundled in).
  - A note on anything deferred, matching what the addendum explicitly
    deferred.

### 6. Confirm with the user

After writing the plan file, tell the user where it is and give a short
summary of what it covers — don't just silently write it and stop.
