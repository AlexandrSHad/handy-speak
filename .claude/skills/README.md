# Skills live in `.agents/skills/`

This repo's agent skills moved to [.agents/skills/](../../.agents/skills/) — the
cross-agent standard home read natively by DSH and pi.

Claude Code reads only `.claude/skills/`. The planned symlink bridge into this
folder is deferred (needs Windows Developer Mode); until it exists, point Claude
Code sessions at the skill bodies directly: `.agents/skills/<name>/SKILL.md`.
