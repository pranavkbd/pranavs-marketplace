#!/usr/bin/env bash
# quietlint: lint the file Claude just edited with the project's own linter.
# Silent when the file is clean or no linter applies, so it costs no tokens.
# On lint errors it prints them (capped) to stderr and exits 2, which Claude Code shows to Claude.
#
# Linters it looks for (only ones the project already has, never downloaded):
#   .js .jsx .ts .tsx .mjs .cjs .vue .svelte  biome (biome.json) or eslint (node_modules/.bin/eslint)
#   .py                                       ruff (ruff config or .venv/bin/ruff)
#   .sh .bash                                 shellcheck (on PATH)
# Any other file type, or a different linter: add .claude/quietlint.json to the project, mapping
# a filename glob to a command, with {file} for the edited file. It is run from the project root.
#   { "*.java": "./gradlew -q checkstyleMain", "*.go": "go vet ./{dir}" }
# The command fails (non-zero exit) to report errors. {dir} is the file folder, relative to root.

MAX_LINES=40

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] && [ -f "$file" ] || exit 0
file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
base=$(basename "$file")

# nearest ancestor folder of the file that contains any of the given names
up() {
  local d; d=$(dirname "$file")
  while [ "$d" != "/" ]; do
    for n in "$@"; do [ -e "$d/$n" ] && { printf '%s' "$d"; return 0; }; done
    d=$(dirname "$d")
  done
  return 1
}

report() {  # $1 = linter name, $2 = output
  {
    printf 'quietlint: %s found errors in %s\n' "$1" "$file"
    printf '%s\n' "$2" | sed '/^[[:space:]]*$/d' | head -n "$MAX_LINES"
    n=$(printf '%s\n' "$2" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    [ "$n" -gt "$MAX_LINES" ] && printf '... %d more lines\n' "$((n - MAX_LINES))"
  } >&2
  exit 2
}

# 1. project override
if root=$(up .claude/quietlint.json); then
  cfg="$root/.claude/quietlint.json"
  while IFS= read -r glob; do
    # shellcheck disable=SC2053
    if [[ $base == $glob ]]; then
      cmd=$(jq -r --arg g "$glob" '.[$g]' "$cfg")
      rel=${file#"$root"/}; dir=$(dirname "$rel")
      cmd=${cmd//\{file\}/$(printf '%q' "$file")}
      cmd=${cmd//\{dir\}/$(printf '%q' "$dir")}
      out=$(cd "$root" && bash -c "$cmd" 2>&1) || report "quietlint.json ($glob)" "$out"
      exit 0
    fi
  done < <(jq -r 'keys[]' "$cfg" 2>/dev/null)
fi

# 2. built-in linters
case "$base" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte)
    if root=$(up biome.json biome.jsonc) && [ -x "$root/node_modules/.bin/biome" ]; then
      out=$(cd "$root" && node_modules/.bin/biome lint --diagnostic-level=error --colors=off "$file" 2>&1)
      [ $? -eq 1 ] && report biome "$out"
    elif root=$(up node_modules/.bin/eslint); then
      out=$(cd "$root" && node_modules/.bin/eslint --quiet "$file" 2>&1)
      [ $? -eq 1 ] && report eslint "$out"   # 2 means eslint itself broke: stay quiet
    fi ;;
  *.py)
    if root=$(up .venv/bin/ruff); then ruff="$root/.venv/bin/ruff"
    elif root=$(up ruff.toml .ruff.toml) || { root=$(up pyproject.toml) && grep -q '^\[tool\.ruff' "$root/pyproject.toml"; }; then
      ruff=$(command -v ruff) || exit 0
    else exit 0; fi
    out=$(cd "$root" && "$ruff" check --quiet --output-format concise "$file" 2>&1)
    [ $? -eq 1 ] && report ruff "$out" ;;
  *.sh|*.bash)
    command -v shellcheck >/dev/null || exit 0
    out=$(shellcheck --severity=error --format=gcc "$file" 2>&1)
    [ $? -eq 1 ] && report shellcheck "$out" ;;
esac
exit 0
