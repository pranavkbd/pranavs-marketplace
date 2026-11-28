---
description: Set this repo up for quietlint - turn-end checks on the files Claude edits, and format plus lint at commit
allowed-tools: Bash, Read, Edit, Write
---

Set up quietlint in the git repository in the current directory. When you're done:

- `.claude/quietlint.json` lists the checks (lint plus type checks) that run on the files a
  Claude session edited, when its turn ends.
- A committed pre-commit hook formats the staged files, re-stages them, then lints them.
- `CLAUDE.md` has a short section saying what is checked and when.

Keep it minimal. Most repos already lint: **find and reuse what's there, and ask questions only
where nothing is set up.** Never add a dependency or change build files without a yes.

## 1. Detect

List the languages in the repo (`git ls-files` by extension, ignoring vendored and generated
folders). For each, find the tools it already uses: config files (`eslint.config.*`,
`biome.json`, `tsconfig.json`, `pyproject.toml` `[tool.ruff]`/`[tool.mypy]`, `.golangci.*`,
`.markdownlint*`, ...), dev dependencies, lint scripts in `package.json`/`Makefile`/CI, and
existing git hooks. In a monorepo, each package with its own config is its own `cwd`.

Turn-end checks (lint and type check; never formatters, never tests):

| Language | Lint | Type check (whole project, output filtered) |
|---|---|---|
| JS / TS | `node_modules/.bin/eslint --max-warnings 0 --no-warn-ignored {files}` or `node_modules/.bin/biome lint --error-on-warnings --no-errors-on-unmatched --colors=off {files}` | `node_modules/.bin/tsc --noEmit --pretty false` (per tsconfig; `-p` for others) |
| Python | `ruff check --quiet --output-format concise {files}` | `mypy {files}` or `pyright {files}` if configured |
| Go | `golangci-lint run {dirs}` if configured | `go vet {dirs}` |
| Rust | `cargo clippy --quiet --message-format short -- -D warnings` | (clippy covers `cargo check`) |
| Shell | `shellcheck --format=gcc {files}` | |
| Markdown | `markdownlint-cli2 {files}` | |
| Other | the repo's own linter, on `{files}` where it accepts files | the repo's compiler or checker |

Rules for the commands:
- **Warnings fail.** Use the flag that makes the tool exit non-zero on warnings (as above).
- Prefer the repo's own binary (`node_modules/.bin/...`, `.venv/bin/...`, `./gradlew`) over
  `npx`/global tools, and keep each command fast: they all run at every turn end.
- Use the repo's own settings (for example the tags or build flags its `go vet` already uses).
- A tool that only takes the whole project (tsc, cargo) has no `{files}`; quietlint then keeps
  only output lines naming the session's files. That needs one `path:line` per problem, so pick
  a one-line output format (`--pretty false`, `--message-format short`).
- Run each command once by hand on one real file to make sure it runs.

**Markdown:** lint it too where a linter fits. If the repo has one, use it. If not, suggest
markdownlint-cli2 (an npm dev dependency in npm repos, otherwise `npx markdownlint-cli2`) with
a `.markdownlint.jsonc` turning off rules that fight existing docs (`MD013` line length is the
usual one), and ask.

**Nothing set up for a language:** suggest the usual tools from the table and ask once for all
of them together. Skip a language the user says no to.

## 2. Write `.claude/quietlint.json`

```json
{
  "checks": [
    { "name": "eslint", "files": ["ui/*.ts", "ui/*.tsx"], "cwd": "ui",
      "run": "node_modules/.bin/eslint --max-warnings 0 --no-warn-ignored {files}" },
    { "name": "tsc", "files": ["ui/*.ts", "ui/*.tsx"], "cwd": "ui",
      "run": "node_modules/.bin/tsc --noEmit --pretty false" },
    { "name": "go vet", "files": ["*.go"], "run": "go vet {dirs}" },
    { "name": "markdownlint", "files": ["*.md"], "run": "npx markdownlint-cli2 {files}" }
  ]
}
```

- `files`: globs on the path from the repo root; `*` also matches `/`.
- `cwd`: folder to run in, relative to the root (default the root). Only files under it are
  passed in.
- `run`: fails (non-zero exit) on problems. `{files}` and `{dirs}` (as `./dir`) are relative
  to `cwd`.
- `filter`: optional. Default true when `run` has no `{files}`.

If the file exists in an older format (a map from glob to command), replace it.

## 3. Pre-commit: format, re-stage, lint

Add a pre-commit hook that **formats, then lints, only the staged files**, with the repo's own
formatter and linter, committed so every clone gets it.

- Run the formatter on staged files and **re-stage what it changed**. Tools like lint-staged
  and pre-commit do this; a plain script must `git add` the files again.
- Then lint the same files and fail the commit on problems, with the same warning setting as
  the turn-end checks.
- Touch only staged files, so it stays fast and never pulls unrelated changes into the commit.

If the repo already formats and lints at commit, leave it alone. Otherwise use the hook setup
it already has, in this order: husky (`.husky/`), lefthook, pre-commit
(`.pre-commit-config.yaml`), or a `core.hooksPath` folder. Add to an existing pre-commit hook
rather than replacing it. If there is none, pick by ecosystem and ask before adding anything:

| Project | Usual choice |
|---|---|
| npm | husky + lint-staged: `"prepare": "husky"`, `.husky/pre-commit` running `npx lint-staged`, and a `lint-staged` entry mapping globs to formatter then linter. |
| Python | pre-commit with the `ruff-format` and `ruff` hooks from `astral-sh/ruff-pre-commit`. Each clone runs `pre-commit install` once. |
| Java / Kotlin | spotless, with `spotlessApply` on staged files from a committed `.githooks/pre-commit`, and a build step that sets `git config core.hooksPath .githooks`. |
| Go, Rust, or several languages | lefthook with `{staged_files}` and `stage_fixed: true`, or a committed `.githooks/pre-commit`. |
| Anything else | A committed `.githooks/pre-commit`, then `git config core.hooksPath .githooks`, plus one README line telling others to run it after cloning. |

Formatters: prettier or biome (JS/TS), `ruff format`, `gofmt`, `cargo fmt`, `shfmt`, and
prettier or `markdownlint-cli2 --fix` for Markdown.

A plain `.githooks/pre-commit` for ruff, to show the shape:

```sh
#!/bin/sh
files=$(git diff --cached --name-only --diff-filter=ACMR -- '*.py')
[ -z "$files" ] && exit 0
echo "$files" | xargs ruff format --quiet || exit 1
echo "$files" | xargs git add
echo "$files" | xargs ruff check --quiet || exit 1
```

Test it: stage a scratch file with a formatting problem, run the hook script directly (a
dry-run commit doesn't run hooks), confirm it formats, re-stages and passes, then unstage and
delete the scratch file.

## 4. Add the CLAUDE.md section

Add this to the repo's `CLAUDE.md` (create it if missing), filled in from what you set up. If a
`<!-- quietlint -->` section is already there, replace it.

```markdown
<!-- quietlint -->
## Checks (quietlint)

- When your turn ends, the files you edited are checked with: <eslint, tsc, go vet, ...>.
  Warnings fail too. Problems come back to you, and you fix them before finishing.
- Formatting is done at commit (<formatter>), so don't format by hand or fix style by eye.
- Write code that passes the first time: no unused code, no lint-disable comments to get past
  a check, no `any` or skipped type errors.
<!-- /quietlint -->
```

## 5. Report

Say in a few lines what was detected, the checks in `.claude/quietlint.json`, how commit-time
formatting is wired, and anything each clone still has to run once. Don't commit unless asked.
