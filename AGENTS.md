# The Living World: authority and workflow

The user (Meshal) and ChatGPT exclusively own all game design, mechanics, class identities, progression, balance, controls, UI behavior, and art direction.
Claude Code is the implementation agent only. Implement explicit approved specifications. Never invent, redesign, or silently fill design gaps. Existing implementation is evidence of current behavior, not proof of design approval.

## Before changing anything
1. Read this file, CLAUDE.md, collaboration/STATUS.md, and the specific task.
2. Run git status. Preserve other work; never reset, clean, overwrite unrelated changes, or force push.
3. A gameplay change requires a task marked APPROVED with the user's or ChatGPT's explicit specification and acceptance criteria. Agents cannot approve their own tasks.
4. Missing mechanics, numbers, bindings, visual behavior, or conflicting requirements: record a question in collaboration/DESIGN_QUESTIONS.md and stop only the dependent change. Do not guess.
5. Use a task branch. Keep commits focused. No automatic merges or publication.

## Implementation and verification
- Work directly in this checkout; no ZIP handoff for routine development.
- Preserve the project Godot version (4.7.2); no engine migration without approval.
- Run tools/dev/Test.ps1 for relevant suites. Report exact commands, exit codes, counts, failures, and untested behavior. Never claim human playtesting from automated checks.
- Do not modify tests merely to make behavior pass, or weaken assertions without an approved reason.
- Report completion in collaboration/results/<task-id>.md, using the result template.
- Keep credentials outside Git. Do not add API keys, personal saves, .godot caches, or screenshots to commits.
- Shared task files are the handoff mechanism. They do not create a live connection between ChatGPT and Claude or grant background access to chats.

## Design status
Historical reports contain provisional interpretations. See collaboration/DESIGN_QUESTIONS.md. Do not treat them as newly approved.
