# conventional-commits

Keeps commit messages in the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>
```

with these types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `ci`,
`build`, `revert`. For example `feat(skyline): add a spacer above the chart`.

It does two things:

1. **Tells Claude the rule.** A `SessionStart` hook adds [`hooks/rule.md`](hooks/rule.md) to every
   session, the same way a CLAUDE.md rule is read, so Claude writes the right format the first
   time. Plugins can't edit CLAUDE.md, so this is how the rule gets in.
2. **Enforces it in git.** `/conventional-commits:setup` adds a `commit-msg` hook to the repo you
   are in. It rejects any commit whose first line isn't in the format, from Claude or from you,
   and prints what was wrong. Messages git writes itself (`Merge …`, `Revert "…"`, `fixup! …`,
   `squash! …`) are let through.

## Install

```
/plugin install conventional-commits@pranavs-marketplace
/conventional-commits:setup      # in each repo where you want the check
```

Setup adds the check the way the project already shares git hooks (husky, lefthook, pre-commit,
`core.hooksPath`). If it has none, it picks what that ecosystem usually uses: husky for npm,
pre-commit for Python, a committed `.githooks/` folder wired up from Gradle or Maven for Java, and
so on, using [`git-hooks/commit-msg`](git-hooks/commit-msg) as the reference script. It asks
before adding a new dependency, and it can also install into just your clone if you prefer.

The list of types lives in two places: [`hooks/rule.md`](hooks/rule.md) for Claude and
[`git-hooks/commit-msg`](git-hooks/commit-msg) for the check. Change both together.
