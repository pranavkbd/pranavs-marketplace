#!/usr/bin/env bash
# quietlint Stop hook: when a turn ends, runs the repo's checks on the files this session edited.
#
# Reads the session's list (written by record-edit.sh) and clears it before checking, so a
# failure can't loop: Claude gets the errors, and a file is checked again only if Claude edits
# it again. Files other sessions edited are never checked.
#
# Checks come from .claude/quietlint.json:
#   { "checks": [
#       { "name": "eslint", "files": ["*.ts", "*.tsx"], "cwd": "ui",
#         "run": "node_modules/.bin/eslint --max-warnings 0 --no-warn-ignored {files}" },
#       { "name": "tsc", "files": ["ui/*.ts", "ui/*.tsx"], "cwd": "ui",
#         "run": "node_modules/.bin/tsc --noEmit --pretty false" },
#       { "name": "go vet", "files": ["*.go"], "run": "go vet {dirs}" } ] }
#
#   files   globs matched against the path from the repo root; * also matches /
#   cwd     folder to run in, relative to the repo root (default: the root). Only files under it
#           are passed to the check.
#   run     shell command; a non-zero exit means problems. {files} is the matched files and
#           {dirs} their folders (as ./dir), both relative to cwd and shell-quoted.
#   filter  keep only output lines that name one of this session's files (plus their indented
#           continuation lines). Default: true when run has no {files}, as for whole-project
#           tools like tsc whose output covers every file.
#
# Silent when everything passes. Otherwise prints the problems (capped at 40 lines) and exits 2,
# which keeps Claude working until they are fixed.

MAX_LINES=40

input=$(cat)
session=$(jq -r '.session_id // "unknown"' <<<"$input" 2>/dev/null | tr -c 'A-Za-z0-9_.\n-' '_')
[ -n "$session" ] || session=unknown
start=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)}
root=$(git -C "${start:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
cfg="$root/.claude/quietlint.json"
[ -f "$cfg" ] || exit 0
list="$(git -C "$root" rev-parse --absolute-git-dir)/quietlint/$session"
[ -s "$list" ] || exit 0

# claim the list atomically, so edits made while we check are kept for the next turn
claimed="$list.checking.$$"
mv "$list" "$claimed" 2>/dev/null || exit 0
mapfile -t files < <(sort -u "$claimed")
rm -f "$claimed"

cd "$root" || exit 0
existing=()
for f in "${files[@]}"; do [ -f "$f" ] && existing+=("$f"); done
[ ${#existing[@]} -gt 0 ] || exit 0
# drop git-ignored files (build output, dependencies)
mapfile -t ignored < <(printf '%s\n' "${existing[@]}" | git check-ignore --stdin 2>/dev/null)
files=()
for f in "${existing[@]}"; do
  skip=; for i in "${ignored[@]}"; do [ "$f" = "$i" ] && skip=1 && break; done
  [ -z "$skip" ] && files+=("$f")
done
[ ${#files[@]} -gt 0 ] || exit 0

# keep lines naming one of the given paths, plus indented lines that follow them
filter_output() {  # stdin: output; args: paths to look for
  awk -v pats="$(printf '%s\n' "$@")" '
    BEGIN { n = split(pats, p, "\n") }
    function names(line,   i, s, at, before, after, rest) {
      for (i = 1; i <= n; i++) {
        if (p[i] == "") continue
        rest = line; s = 0
        while ((at = index(rest, p[i])) > 0) {
          before = substr(line, s + at - 1, 1)
          after = substr(line, s + at + length(p[i]), 1)
          # a whole path: starts the line or follows a space, quote, "(", ":" or "./"
          # (absolute paths match anywhere), and is not followed by more of a name
          if ((substr(p[i], 1, 1) == "/" || s + at == 1 || before ~ /[[:space:]"'"'"'(:]/ ||
               substr(line, s + at - 2, 2) == "./") && after !~ /[A-Za-z0-9_]/)
            return 1
          s += at; rest = substr(line, s + 1)
        }
      }
      return 0
    }
    names($0) { print; keep = 1; next }
    keep && /^[ \t]/ { print; next }
    { keep = 0 }'
}

report=""
while IFS= read -r check; do
  name=$(jq -r '.name // .run' <<<"$check")
  run=$(jq -r '.run // empty' <<<"$check")
  cwd=$(jq -r '.cwd // "." | sub("/+$"; "")' <<<"$check")
  filter=$(jq -r 'if has("filter") then .filter else "auto" end' <<<"$check")
  mapfile -t globs < <(jq -r '.files // ["*"] | if type == "string" then [.] else . end | .[]' <<<"$check")
  [ -n "$run" ] && [ -d "$cwd" ] || continue

  matched=() pats=()
  for f in "${files[@]}"; do
    if [ "$cwd" = "." ]; then r=$f; else r=${f#"$cwd"/}; [ "$r" != "$f" ] || continue; fi
    for g in "${globs[@]}"; do
      # shellcheck disable=SC2053
      if [[ $f == $g ]]; then matched+=("$r"); pats+=("$r" "$f" "$root/$f"); break; fi
    done
  done
  [ ${#matched[@]} -gt 0 ] || continue

  q_files=$(printf '%q ' "${matched[@]}")
  q_dirs=$(for m in "${matched[@]}"; do printf './%s\n' "$(dirname "$m")"; done | sed 's|^\./\.$|.|' | sort -u |
    while IFS= read -r d; do printf '%q ' "$d"; done)
  cmd=${run//\{files\}/$q_files}
  cmd=${cmd//\{dirs\}/$q_dirs}
  [ "$filter" = auto ] && { [[ $run == *"{files}"* ]] && filter=false || filter=true; }

  out=$(cd "$cwd" && NO_COLOR=1 FORCE_COLOR=0 bash -c "$cmd" 2>&1) && continue
  out=$(printf '%s\n' "$out" | sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g' | sed '/^[[:space:]]*$/d')
  if [ "$filter" = true ]; then
    kept=$(printf '%s\n' "$out" | filter_output "${pats[@]}")
    # problems only in other files: not ours. No file:line anywhere: the tool itself broke.
    if [ -z "$kept" ] && ! grep -qE '[A-Za-z0-9_]\.[A-Za-z0-9]+[:(][0-9]' <<<"$out"; then
      kept="the check failed without naming a file (is it set up right in .claude/quietlint.json?):"$'\n'$(head -n 5 <<<"$out")
    fi
    out=$kept
  fi
  [ -n "$out" ] || continue
  where=""; [ "$cwd" != "." ] && where=" (in $cwd)"
  report+="$name$where:"$'\n'"$out"$'\n'
done < <(jq -c '.checks[]?' "$cfg" 2>/dev/null)

[ -n "$report" ] || exit 0
{
  echo "quietlint: checks found problems in files you edited this turn. Fix them before finishing (warnings count; formatting is handled at commit):"
  printf '%s' "$report" | head -n "$MAX_LINES"
  total=$(printf '%s' "$report" | wc -l)
  [ "$total" -gt "$MAX_LINES" ] && echo "... $((total - MAX_LINES)) more lines"
} >&2
exit 2
