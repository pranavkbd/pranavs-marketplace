---
description: Add a commit-msg check to this repo that rejects non-Conventional Commits messages
allowed-tools: Bash, Read, Edit, Write
---

Add a `commit-msg` check to the git repository in the current directory, using whatever way of
sharing git hooks fits this project. The goal is a check that is committed, so every clone gets
it, and that runs the same logic as the reference script.

**Reference script:** `${CLAUDE_PLUGIN_ROOT}/git-hooks/commit-msg`. Read it first. It takes the
message file path as `$1`, skips comments and blank lines, lets through messages git writes
itself (`Merge …`, `Revert "…"`, `fixup! …`, `squash! …`, `amend! …`), and exits 1 with a short
explanation unless the first line matches `<type>[optional scope][!]: <description>` with the
types it lists. Copy it into the repo as `scripts/commit-msg` (or the project's usual scripts
folder) and call it from the hook. Don't rewrite the logic unless the ecosystem needs it in
another language.

## 1. Look at the repo

Check what it already uses, in this order, and use the first match:

| Found | Do this |
|---|---|
| `.husky/` | Add `sh scripts/commit-msg "$1"` to `.husky/commit-msg`. |
| `lefthook.yml` / `.lefthook.yml` | Add a `commit-msg` command: `run: sh scripts/commit-msg {1}`. |
| `.pre-commit-config.yaml` | Add a `local` hook with `stages: [commit-msg]`, `entry: sh scripts/commit-msg`, `language: system`. Remind the user that `pre-commit install --hook-type commit-msg` is needed once per clone. |
| commitlint config | A commit-msg check already exists. Tell the user and stop unless they want this one too. |
| `core.hooksPath` set to a folder in the repo | Put the hook in that folder. |

## 2. No hook setup yet: pick by ecosystem

Pick what the project's language and build tool normally use. **Adding a dependency or changing
build files needs a yes from the user first:** say what you'd add and why, then ask.

| Project | Usual choice |
|---|---|
| JavaScript / TypeScript (`package.json`) | husky: add it as a dev dependency with the project's package manager, set `"prepare": "husky"`, and create `.husky/commit-msg`. |
| Python (`pyproject.toml`, `requirements*.txt`) | pre-commit: add `.pre-commit-config.yaml` with a `local` commit-msg hook as above. |
| Java / Kotlin with Gradle | A committed `.githooks/commit-msg`, plus a Gradle task that runs `git config core.hooksPath .githooks`, wired to run before `build` or `compileJava`. |
| Java with Maven | A committed `.githooks/commit-msg`, plus a step that sets `core.hooksPath` during `initialize` (for example `exec-maven-plugin` running `git config core.hooksPath .githooks`). |
| Go, Rust, or several languages | lefthook if the user is happy to add it; otherwise a committed `.githooks/` folder. |
| Anything else, or the user says no to new tools | A committed `.githooks/commit-msg`, then run `git config core.hooksPath .githooks`, and add one line to the README telling others to run it once after cloning. |

Make the hook file executable and commit-ready, but don't commit it yourself unless asked.

## 3. Just this clone

If the user only wants the check locally, run `sh "${CLAUDE_PLUGIN_ROOT}/git-hooks/install.sh"`.
It copies the reference script into the repo's hooks folder (respecting `core.hooksPath`). If it
exits 2, a different commit-msg hook is already there: show it to the user and ask before
chaining or replacing it.

## 4. Check it and report

Test the hook directly: `printf 'bad message\n' > /tmp/m && <hook> /tmp/m` should fail, and
`printf 'feat: test\n' > /tmp/m && <hook> /tmp/m` should pass. Then say in one or two lines what
you set up, what files changed, and anything each clone still has to run once.
