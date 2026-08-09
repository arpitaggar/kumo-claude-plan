# scripts/

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under scripts/.

### Icon & Asset Generation Script

**File:** `scripts/gen_icons.py`

Run to regenerate all icon assets after changing source SVGs or theme colours:

```bash
python3 scripts/gen_icons.py
```

`generate_alternate_icons()` produces per-theme:
- `drawable-{mdpi…xxxhdpi}/ic_launcher_foreground_{theme}.png` — adaptive icon foreground at 108–432 px
- `drawable/ic_launcher_background_{theme}.xml` — per-theme gradient XML
- `mipmap-anydpi-v26/ic_launcher_{theme}.xml` — adaptive icon descriptor
- `mipmap-{mdpi…xxxhdpi}/ic_launcher_{theme}.png` — plain PNG fallback for API < 26

The default launcher icon (`ic_launcher`) remains Deep Voyage; alternate assets exist in the resource tree but are not activated at runtime.

### Git Hooks

**Files:** `scripts/hooks/pre-commit`, `scripts/install-git-hooks.sh`

git never syncs `.git/hooks/` from the repo, so the root CLAUDE.md's "Pre-commit hooks: `dart format`, `flutter analyze`" line was aspirational until this existed (2026-08-09 audit remediation) — the hook script is tracked here and has to be installed once per clone:

```bash
./scripts/install-git-hooks.sh
```

It copies `scripts/hooks/*` into `.git/hooks/` and makes them executable. The `pre-commit` hook fails the commit if `dart format --set-exit-if-changed lib/ test/` finds unformatted files or `flutter analyze --no-fatal-infos` reports any warning/error. Two deliberate deviations from the "obvious" invocation: `dart format` is scoped to `lib/`/`test/`, not `.`, because the repo root also contains the gitignored `build/` directory once you've run a native build, and that holds CocoaPods-vendored copies of pub packages (e.g. `firebase_messaging`) that aren't this project's source to format; `--no-fatal-infos` is required because `flutter analyze` is otherwise fatal on info-level issues too, and this project knowingly tolerates a baseline of those (e.g. the deliberate `one_member_abstracts` pattern, see [[feedback-single-method-abstractions]]).

