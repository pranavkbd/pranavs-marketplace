# assistant / worker launchers for the assistant-worker plugin. Source from ~/.zshrc.
# Sessions are named after the git checkout's top folder (assistant-<dir>, worker-<dir>) so a
# pair started in the same checkout finds each other. Outside git: the current folder's name.
_claude_pair_dir() {
  local top; top=$(git rev-parse --show-toplevel 2>/dev/null) || top=$PWD
  local d=${top:t}; print -r -- "${d// /-}"
}
assistant() { claude --agent assistant --name "assistant-$(_claude_pair_dir)" "$@"; }
# `worker` is thread A (worker-<dir>); `worker C` is thread C (worker-<dir>-c).
worker() {
  local name="worker-$(_claude_pair_dir)"
  if [[ $1 == [A-Za-z] ]]; then
    [[ ${1:l} != a ]] && name+="-${1:l}"
    shift
  fi
  claude --agent worker --name "$name" "$@"
}
