# AGENTS.md

For any AI assistant working in this repo (Codex, Cursor, Copilot, Gemini, ChatGPT and others).

1. **First, brief your user.** Read **Project status** and **Latest activity** in [`README.md`](README.md), or run `scripts/status.sh`. Tell them in about five lines: the last change and who made it, the next deadline, what's done, and what's left.
2. **Then follow [`CLAUDE.md`](CLAUDE.md).** Its rules apply to every AI tool here, not just Claude.
3. **Keep the status current.** When you finish or start a task, update **Project status** in `README.md` in the same commit. Don't edit "Latest activity"; it updates itself on every push to `main`.
4. **Setup is `./setup.sh`.** If it fails for your user, fix the script instead of adding manual steps.
