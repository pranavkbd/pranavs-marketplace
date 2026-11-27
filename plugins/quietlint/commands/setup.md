---
description: Add a pre-commit hook to this repo that formats and lints the staged files
allowed-tools: Bash, Read, Edit, Write
---

Add a pre-commit hook to the git repository in the current directory that **formats, then
lints, only the staged files**, using the project's own formatter and linter and whatever way of
sharing git hooks fits this project. The hook should be committed so every clone gets it.

What the hook must do:
- Run the formatter on staged files and **re-stage what it changed**, so the commit holds the
  formatted code. Tools like lint-staged and pre-commit do this; a plain script must `git add`
  the files again.
- Then run the linter on the same files and fail the commit on errors (not warnings).
- Touch only staged files, so it stays fast and never pulls unrelated changes into the commit.

## 1. Find the tools

Look at the repo for the formatter and linter it already uses (config files, dev dependencies,
build plugins). Use those. If it has none, suggest the usual pair for its language and ask
before adding them:

| Language | Formatter | Linter |
|---|---|---|
| JavaScript / TypeScript | prettier, or biome | eslint, or biome |
| Python | ruff format | ruff check |
| Go | gofmt | go vet |
| Rust | cargo fmt | cargo clippy |
| Java / Kotlin | spotless (google-java-format, ktlint) | spotless or checkstyle |
| Shell | shfmt | shellcheck |

## 2. Wire it up

Use what the repo already has, in this order: husky (`.husky/`), lefthook, pre-commit
(`.pre-commit-config.yaml`), or a `core.hooksPath` folder. Add to an existing pre-commit hook
rather than replacing it.

If there is none, pick by ecosystem. **Adding a dependency or changing build files needs a yes
from the user first:** say what you'd add and why, then ask.

| Project | Usual choice |
|---|---|
| npm (`package.json`) | husky + lint-staged: `"prepare": "husky"`, `.husky/pre-commit` running `npx lint-staged`, and a `lint-staged` entry mapping globs to the formatter and linter. |
| Python | pre-commit with the `ruff-format` and `ruff` hooks from `astral-sh/ruff-pre-commit`. Each clone runs `pre-commit install` once. |
| Java / Kotlin with Gradle or Maven | spotless, with `spotlessApply` on staged files from a committed `.githooks/pre-commit`, and a build step that sets `git config core.hooksPath .githooks`. |
| Go, Rust, or several languages | lefthook with `{staged_files}` and `stage_fixed: true`, or a committed `.githooks/pre-commit`. |
| Anything else, or no new tools | A committed `.githooks/pre-commit` script, then `git config core.hooksPath .githooks`, plus one README line telling others to run it after cloning. |

Example of a plain `.githooks/pre-commit` for a project using ruff, to show the shape:

```sh
#!/bin/sh
files=$(git diff --cached --name-only --diff-filter=ACMR -- '*.py')
[ -z "$files" ] && exit 0
echo "$files" | xargs ruff format --quiet || exit 1
echo "$files" | xargs git add
echo "$files" | xargs ruff check --quiet || exit 1
```

## 3. Check it and report

Stage a scratch file with a small formatting problem and run the hook script directly (a dry-run
commit doesn't run hooks) to confirm it formats, re-stages and passes. Then unstage and delete
the scratch file. Say in one or two lines what you set up, what files changed, and
anything each clone still has to run once. Don't commit unless asked.
