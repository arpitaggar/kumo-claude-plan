#!/usr/bin/env bash
# Installs Kumo's tracked git hooks (scripts/hooks/) into .git/hooks/, which
# git itself never syncs from the repo. Run once per clone:
#   ./scripts/install-git-hooks.sh
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_src="$repo_root/scripts/hooks"
hooks_dst="$repo_root/.git/hooks"

for hook in "$hooks_src"/*; do
  name="$(basename "$hook")"
  cp "$hook" "$hooks_dst/$name"
  chmod +x "$hooks_dst/$name"
  echo "Installed $name -> .git/hooks/$name"
done
