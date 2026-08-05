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

