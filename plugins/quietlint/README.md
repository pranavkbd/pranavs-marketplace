# quietlint

Linting that costs Claude no tokens. Every time Claude edits a file, quietlint runs your
project's own linter on that one file. If it's clean, nothing is printed and Claude never hears
about it. If there are errors, they go straight back to Claude (errors only, capped at 40 lines),
while it is still working on that file. Claude doesn't have to remember to lint or spend a turn
doing it.

Formatting waits until commit time: `/quietlint:setup` adds a pre-commit hook that formats and
lints the staged files, so Claude never spends effort on formatting while it works.

## Install

```
/plugin install quietlint@pranavs-marketplace
/quietlint:setup      # in each repo where you want format + lint on commit
```

The lint-on-edit hook needs `jq` and works as soon as the plugin is installed.

## Linting on edit

quietlint only uses linters your project already has. It never downloads one.

| Files | Linter | Used when |
|---|---|---|
| `.js .jsx .ts .tsx .mjs .cjs .vue .svelte` | biome | `biome.json` and `node_modules/.bin/biome` exist |
| same | eslint | `node_modules/.bin/eslint` exists |
| `.py` | ruff | `.venv/bin/ruff`, or a ruff config with `ruff` on your PATH |
| `.sh .bash` | shellcheck | `shellcheck` is on your PATH |

For anything else, or to use a different linter, add `.claude/quietlint.json` to the project.
It maps a filename glob to a command, run from the project root, that fails when there are
errors. `{file}` is the edited file and `{dir}` its folder:

```json
{
  "*.java": "./gradlew -q checkstyleMain",
  "*.go": "go vet ./{dir}",
  "*.rb": "bundle exec rubocop --fail-level error {file}"
}
```

A matching entry replaces the built-in linter for those files. Keep the commands fast: they run
after every edit, with a 30-second limit. Slow whole-project checks (type checks, tests) belong
in the pre-commit hook instead.

## Format and lint on commit

`/quietlint:setup` adds a pre-commit hook that formats the staged files, re-stages them, then
lints them and blocks the commit on errors. It uses the hook setup the repo already has (husky,
lefthook, pre-commit, `core.hooksPath`), or the usual one for the ecosystem: husky with
lint-staged for npm, pre-commit with ruff for Python, spotless for Java, and so on. It asks
before adding a new dependency.
