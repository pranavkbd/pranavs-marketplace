# quietlint

Set a repo up once, and Claude never spends context thinking about linting.

- **At the end of each turn**, the files Claude edited in that session are linted and type
  checked with the repo's own tools. If they pass, nothing is printed. If not, the problems
  (capped at 40 lines) go back to Claude and it fixes them before it finishes. Warnings fail
  too.
- **At commit**, a pre-commit hook formats the staged files, re-stages them, then lints them.

Nothing runs while Claude is editing. Each edit only records the file's path.

## Install

```
/plugin install quietlint@pranavs-marketplace
/quietlint:setup      # once in each repo
```

The hooks need `jq`. They do nothing in a repo until `/quietlint:setup` has written
`.claude/quietlint.json`.

## Setup

`/quietlint:setup` is meant for repos that already lint. It finds the linters, type checkers
and formatter the repo uses and reuses them. It asks questions only for a language that has no
tools set up, and before adding any dependency. It then:

1. Writes `.claude/quietlint.json` with the turn-end checks.
2. Adds a pre-commit hook that formats, re-stages and lints the staged files, using the hook
   setup the repo already has (husky, lefthook, pre-commit, `core.hooksPath`) or the usual one
   for its ecosystem.
3. Adds a short section to `CLAUDE.md` saying what is checked and when, and that warnings fail,
   so Claude writes code that passes the first time.

Markdown is linted too where a linter fits (markdownlint-cli2 if the repo has nothing).

## Turn-end checks

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

| Key | Meaning |
|---|---|
| `files` | Globs on the path from the repo root (`*` also matches `/`). A check runs only if this session edited a matching file. |
| `cwd` | Folder to run in, relative to the root. Default: the root. Only files under it are passed in. |
| `run` | Shell command that exits non-zero on problems. `{files}` is the matched files, `{dirs}` their folders (`./dir`), relative to `cwd`. |
| `filter` | Keep only output lines naming this session's files. Default: on when `run` has no `{files}`. |

How it works:

- A PostToolUse hook on `Edit|Write|MultiEdit|NotebookEdit` appends the file's path to
  `<git dir>/quietlint/<session id>`. It runs nothing and prints nothing.
- A Stop hook takes that list, clears it, and runs the checks whose `files` match. Clearing
  first means a failure can't loop: a file is checked again only if Claude edits it again.
- Only this session's files are checked, never everything uncommitted, because other agents
  may be editing other files in the same checkout. Whole-project tools like tsc and
  `go vet ./pkg` report every file they see, so their output is filtered to this session's
  files. A check that fails without naming any file is reported as broken, so a wrong command
  doesn't go silent.
- Git-ignored and deleted files are skipped. Edits in a repo other than the one the session
  started in are not checked.
- The Stop hook has a 5-minute limit for all checks together.
