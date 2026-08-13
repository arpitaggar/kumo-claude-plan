# lib/features/auth

Added 2026-08-12 — loads only when working under lib/features/auth/. Covers the 18+ age gate for Captain/Crew accounts. See `docs/ARCHITECTURE.md`'s "Trip Roles: Captain / Crew / Hitchhiker, and the 18+ Age Gate" section for the full regulatory rationale (COPPA/UK AADC/GDPR) — this file is the implementation reference.

### Server-side age gate

**Migration:** `docs/supabase_migrations/stage44_age_gate.sql`
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### What it does

- Adds `profiles.age_verified_at timestamptz` — null means "not yet verified," never derived from a stored date of birth.
- `enforce_signup_age_gate()` — `BEFORE INSERT ON auth.users`. Reads `date_of_birth` from the signup call's metadata, rejects the INSERT outright (`raise exception`) if it implies under 18, and — on success — strips `date_of_birth` back out of `raw_user_meta_data` before the row is ever persisted, recording only a boolean pass/fail in `raw_app_meta_data->>'age_verified'`.
- `handle_new_user()` reissued to stamp `profiles.age_verified_at = now()` when that flag is set. Also restores a pending-invitations auto-join loop that a later migration (`stage21_trip_segments.sql`) had accidentally dropped when it redefined this same function for the premium-trial feature — found while tracing the current definition for this change, unrelated to the age gate itself.
- `confirm_age_and_finish_signup(p_date_of_birth date) returns text` (`'verified' | 'rejected_underage'`) — the invite-path completion gate, see below.

#### Why two different enforcement paths

Direct signup (`supabase.auth.signUp()`) supplies DOB in the same call that creates the account, so the `BEFORE INSERT` trigger can reject the row before it's ever written — no account, full stop.

Invite-created accounts (`supabase.auth.admin.inviteUserByEmail()`, called from `supabase/functions/invite-email`) are different: the `auth.users` row is created by the **inviter**, server-side, before the invitee has interacted with anything — there is no DOB to check yet at that INSERT. These rows are allowed through with `age_verified_at` left null, and the app refuses real access until the invitee completes `confirm_age_and_finish_signup()`. If they're under 18, that RPC **deletes the account** (can't raise-then-delete in the same transaction — raising would roll back the delete too, so it returns `'rejected_underage'` as data instead) rather than raising. Same end state as the direct-signup path (no account), reached one step later because the platform's invite mechanics require the row to exist first.

#### Flutter layer

- **Signup:** `presentation/pages/signup_page.dart` — mandatory DOB field (`showDatePicker`), gates the submit button alongside the existing consent checkbox. `domain/validators/auth_validators.dart`'s `validateAge18Plus()` is a client-side mirror only — fast, friendly error before ever hitting the network; the Postgres trigger is the actual security boundary.
- **`domain/repositories/auth_repository.dart`** — `signUp()` now requires `dateOfBirth`; new `confirmAge(DateTime)` for the invite-completion path.
- **`presentation/providers/age_gate_provider.dart`** — `AgeGateNotifier`/`ageGateProvider`, mirrors `OnboardingNotifier`'s pattern (`lib/features/onboarding/presentation/providers/onboarding_provider.dart`) but is server-derived (`profiles.age_verified_at` via `userProfileRepositoryProvider`), not device-local — a device-local value would be trivially bypassable by reinstalling the app. **Caveat (`docs/SECURITY_AUDIT.md` SEC-033, 2026-08-13):** this is the *only* enforcement of the invite-path gate — no RLS policy or RPC anywhere else checks `age_verified_at`, so it currently blocks the Flutter UI, not a scripted/API client calling Supabase directly. Flagged, not fixed; see that finding before treating this as a hard security boundary the way the direct-signup trigger is.
- **`presentation/pages/confirm_age_page.dart`** (route `/confirm-age`) — the one-time completion screen for invite-created accounts. Direct signup can never reach this screen.
- **`lib/config/router.dart`** — `needsAgeConfirmation` check takes priority over every other authenticated route, including onboarding and deep links (`kumo://join`); placed before those checks in `_RouterNotifier.redirect`.

### Key design decisions

- **No raw DOB persisted anywhere, ever.** Only `profiles.age_verified_at` (a timestamp, not a date of birth) and, transiently during the signup transaction only, `auth.users.raw_app_meta_data->>'age_verified'` (a boolean). If a real product need for DOB ever emerges (birthday reminders, etc.), that's a new, explicit, minimized field — not a reason to stop scrubbing it here.
- **Reject, don't downgrade.** An under-18 signup never produces a limited/restricted account — no account is created (direct path) or the just-created one is deleted (invite path). See Hitchhiker (`lib/features/hitchhiker/`) for how minors actually participate instead.
