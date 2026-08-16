# Kumo

A collaborative travel planning super-app: shared itineraries, real-time trip
chat and private messaging, expense splitting, a social feed, AI-assisted
itinerary generation, and a minimal Work Mode for org travel — built with
Flutter, Riverpod, and Supabase.

## Architecture

Clean Architecture per feature, under `lib/features/<feature>/`:

- `domain/` — entities, repository interfaces, usecases. No framework or
  external-library dependencies.
- `data/` — models, datasources, repository implementations.
- `presentation/` — pages, widgets, Riverpod providers.

Shared, cross-feature code lives in `lib/core/` (e.g. accommodation search,
geocoding, crash reporting) and `lib/shared/` (reusable widgets). Routing is
GoRouter (`lib/config/router.dart`); the backend is Supabase (Postgres +
Realtime + Storage + Edge Functions).

## Documentation

This project keeps three different kinds of documentation, each answering a
different question — start with the one that matches what you're asking:

| Question | Where |
|---|---|
| "What shipped, and why?" (dated history, verification counts) | `docs/Checklist.md` |
| "Why does this feature work this way?" (design rationale for one feature) | `lib/features/<feature>/CLAUDE.md`, `lib/core/<module>/CLAUDE.md` |
| "What's this class/function's API?" (mechanically generated from `///` comments) | `dart doc .` → `doc/api/` (gitignored, regenerate locally) |
| Project-wide conventions (error handling, state management, git workflow) | root `CLAUDE.md` |

Run `dart doc .` to generate a browsable API reference at `doc/api/index.html`
from the in-code doc comments — the Dart/Flutter equivalent of Doxygen.
`dartdoc_options.yaml` holds its config.

## Getting started

```
flutter pub get
flutter run
```

`flutter analyze` and `dart format --set-exit-if-changed .` are enforced by a
pre-commit hook — run `./scripts/install-git-hooks.sh` once per clone (see
`scripts/CLAUDE.md`).
