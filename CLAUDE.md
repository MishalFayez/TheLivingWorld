@AGENTS.md

# Claude Code implementation contract
Read AGENTS.md and obey the ownership boundary. You implement code only; Meshal and ChatGPT decide the game.

Start with collaboration/STATUS.md. Work only on an approved task in collaboration/tasks/. If none exists, summarize readiness and blockers without modifying gameplay.

For every implementation task:
1. Confirm approved scope and acceptance criteria; list design gaps before coding.
2. Inspect git status, create a task branch, and preserve existing changes.
3. Implement the minimum approved change directly in this project.
4. Run the relevant existing Godot suites with tools/dev/Test.ps1.
5. Write collaboration/results/<task-id>.md with changed files, test evidence, risks, pending design questions, and Git commit.
6. Return control for ChatGPT/user review. Do not approve your own work or merge main.

Do not generate new mechanics, change balance, controls, progression, class identity, or art direction to resolve ambiguity. Record a precise question instead. No permission bypass flags.
