#!/bin/sh
# Install the conventional-commits commit-msg hook into the git repo in the current directory.
# Respects core.hooksPath. Refuses to replace a commit-msg hook it did not install.
set -e
src="$(cd "$(dirname "$0")" && pwd)/commit-msg"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not inside a git repository" >&2; exit 1; }
hooks=$(git rev-parse --git-path hooks)
dest="$hooks/commit-msg"
mkdir -p "$hooks"
if [ -e "$dest" ] && ! grep -q '^# conventional-commits:' "$dest"; then
  echo "a different commit-msg hook already exists at $dest; not replacing it" >&2
  exit 2
fi
cp "$src" "$dest"
chmod +x "$dest"
echo "installed $dest"
