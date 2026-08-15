#!/usr/bin/env bash
# SEC-033 future-proofing (see docs/supabase_migrations/
# stage46_age_gate_db_enforcement.sql's header for the finding and the
# guarded-table rationale).
#
# stage46 attached the require_age_verified() trigger to every table that
# mattered *at the time*. Nothing stops a later migration from adding a new
# table that should also be gated and just... not doing it, since nothing
# else in this project has a CI service to catch that (see CLAUDE.md — solo
# dev, no PR review). This script is that catch: it fails the commit if a
# staged/modified migration file creates a new public table with neither a
# require_age_verified() trigger nor an explicit exemption comment in the
# same file. Run from scripts/hooks/pre-commit.
#
# Scoped to *staged* migration files only, not the whole migrations/
# history — tables created before this convention existed aren't
# retroactively required to annotate themselves.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
failures=()

staged_migrations=$(git diff --cached --name-only --diff-filter=ACM -- 'docs/supabase_migrations/*.sql' || true)

# One SQL statement per record (split on ';') so a table name mentioned in
# one CREATE TRIGGER statement can't accidentally "cover" an unrelated
# table just because require_age_verified appears somewhere else in the
# same file. Assumes this project's own lowercase-keyword SQL convention
# (checked throughout docs/supabase_migrations/) rather than doing
# case-insensitive matching, since macOS's built-in awk has no IGNORECASE.
_table_is_guarded() {
  local file="$1" table="$2"
  awk -v RS=';' -v t="$table" '
    $0 ~ /create trigger/ &&
    $0 ~ ("on public\\." t "([^a-z0-9_]|$)") &&
    $0 ~ /require_age_verified/ { found = 1 }
    END { exit !found }
  ' "$file"
}

_table_is_exempted() {
  local file="$1" table="$2"
  grep -qE -- "age-gate-exempt:[[:space:]]*public\\.${table}([^a-zA-Z0-9_]|\$)" "$file"
}

for file in $staged_migrations; do
  full_path="$repo_root/$file"
  [ -f "$full_path" ] || continue

  while IFS= read -r table; do
    [ -z "$table" ] && continue
    if _table_is_guarded "$full_path" "$table"; then
      continue
    fi
    if _table_is_exempted "$full_path" "$table"; then
      continue
    fi
    failures+=("$file: public.$table")
  done < <(grep -oE 'create table( if not exists)? public\.[a-z_][a-z0-9_]*' "$full_path" \
             | grep -oE '[a-z_][a-z0-9_]*$')
done

if [ "${#failures[@]}" -gt 0 ]; then
  echo "pre-commit: age-gate coverage check failed (SEC-033 future-proofing)." >&2
  echo "New table(s) with no require_age_verified trigger and no exemption comment:" >&2
  for f in "${failures[@]}"; do
    echo "  - $f" >&2
  done
  echo >&2
  echo "Either attach the trigger (copy the pattern in" >&2
  echo "docs/supabase_migrations/stage46_age_gate_db_enforcement.sql), or add a line:" >&2
  echo "  -- age-gate-exempt: public.<table> — <reason>" >&2
  exit 1
fi
