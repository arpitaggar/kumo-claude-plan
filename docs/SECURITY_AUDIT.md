# Continuous Security & Privacy Audit Log

## Executive Summary

- **Last Updated:** 2026-08-09
- **Overall Posture:** Action Required — remediation applied, one item needs manual follow-up
- **Open Critical/High Issues:** 0 code-fixable (30 of 31 findings resolved across the 2026-08-05 and 2026-08-09 remediation passes; SEC-014 remains open pending a manual Firebase console action — key rotation can't be done from a code change)
- **2026-08-09 update:** A security review of the work-mode/org feature (stages 28-30, shipped 2026-08-08) and the current uncommitted diff found and fixed 6 new findings — SEC-026 through SEC-031 — covering an RLS self-recursion bug, an unauthenticated trip-email-alias IDOR, a cross-tenant expense-injection path, an over-broad org-admin SELECT grant, an information-disclosure nit in the new startup-failure screen, and a non-constant-time secret comparison in `inbound-trip-email`. See those entries below.
- **2026-08-11 spot-check:** Reviewed the new client-side Work Mode toggle feature (personal/work theme + trip-visibility split, no new tables/RLS/endpoints). Two things worth recording, neither a live vulnerability:
  1. **Verified, not assumed:** `CreateItineraryPage` now derives `org_id` for a new trip from client state (`currentWorkOrgProvider`) instead of a picker, and passes it straight to the insert. Confirmed this is still RLS-enforced, not just UI-restricted — `itineraries_owner_all` (`stage31_fix_org_members_rls_recursion.sql:168-173`) requires `owner_id = auth.uid() and (org_id is null or is_org_member(org_id))` on `with check`, so a tampered client sending an `org_id` the caller doesn't belong to is rejected at the database, not just hidden by the UI.
  2. **Corrected a stale reference introduced by the same feature:** a code comment in `visibleItinerariesProvider` (and the matching `Checklist.md` entry) cited `org_admin_trip_visibility_select` as a still-active RLS grant that the client-side filter needed to defend against. That policy was already dropped in SEC-029 (2026-08-09, before Work Mode was written) and replaced with the narrow `fetch_org_pending_approvals` RPC — org admins have had zero direct table-level SELECT into other members' trips since then. The client-side ownerId/member recheck in `visibleItinerariesProvider` is harmless (defense-in-depth, matches the product's confirmed Work Mode scope) but its original justification was inaccurate; both the code comment and Checklist.md have been corrected to state the real, current rationale.
- **2026-08-11 deployment update:** every SQL migration through `stage39_department_overrides.sql` has now been run against the live database, including `stage23_security_hardening.sql` — closing the deployment gap this doc had been flagging since 2026-08-05. Edge Function redeployment and the `--dart-define-from-file` build switch (items 2–3 below) are still outstanding.

**⚠️ Partially deployed.** All 25 findings below were audited and 24 fixed in code/migrations on 2026-08-05. Since then:
1. ✅ **Run (2026-08-11):** `docs/supabase_migrations/stage23_security_hardening.sql` — and every migration after it — is now live against the Supabase project. The two Critical privilege-escalation fixes and the GDPR-erasure fix are protected in production.
2. **Still outstanding:** redeploy the three Edge Functions (`generate-itinerary`, `invite-email`, `send-message-push`) and set the `ALLOWED_ORIGIN` secret.
3. **Still outstanding:** ship a Flutter build using `--dart-define-from-file=env.local.json` (see SEC-002) — the old `.env`-asset build path no longer works.

Scope: full `lib/` tree, all `supabase/functions/*`, all `docs/supabase_migrations/*.sql` + `kumo_schema.sql`, `pubspec.yaml`/`pubspec.lock`, `.gitignore`/native key handling. Audited across five parallel passes (secrets/dependencies, auth/session/GDPR lifecycle, PII exposure across features, Supabase RLS/SQL policies, OWASP logic flaws/edge functions), then deduplicated, consolidated, and remediated below. Every finding is annotated with a **Status** line; see [Resolved Findings](#resolved-findings) for the full remediation summary.

---

## Active Remediation Log

### [SEC-001] Any trip editor can seize permanent ownership of another user's itinerary

- **Category:** Security Flaw
- **Severity:** Critical
- **Status:** ✅ Resolved (2026-08-05) — `docs/supabase_migrations/stage23_security_hardening.sql` (`guard_owner_id_change` trigger).
- **Location:** `docs/supabase_migrations/stage12_fix_member_visibility.sql:33-52` (`itineraries_member_update` policy — currently active, never redefined in any later migration through stage22)
- **1. Cause:** The policy's `with check` clause is `owner_id = auth.uid() OR <caller has an editor entry in the NEW row>`, evaluated purely against the *proposed* row. It never compares `NEW.owner_id` to `OLD.owner_id`. An editor can run `UPDATE itineraries SET owner_id = '<own-uid>' WHERE id = X` directly via the Supabase REST API (no app modification needed) — it passes `using()` (they're an editor on the *current* row) and passes `with check()` trivially (`owner_id = auth.uid()` is now true for the row they just wrote). No trigger or constraint prevents a non-owner from changing `owner_id`.
- **2. Impact:** Any collaborator invited as an `editor` — the default role for anyone helping plan a trip — can permanently transfer ownership of the entire trip to themselves with one API call. This locks the real owner out of `itineraries_owner_all`'s full delete/edit rights, and cascades: expense/rating/packing-item DELETE policies key off `owner_id`, so the attacker inherits real deletion rights over the original owner's financial and personal data. This is a full authorization-boundary bypass and would be a Critical finding in any external pentest or SOC2/ISO27001 review.
- **3. Remediation:**
  ```sql
  -- docs/supabase_migrations/stage23_fix_owner_takeover.sql
  create or replace function public.prevent_unauthorized_owner_change()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
  begin
    if new.owner_id is distinct from old.owner_id
       and old.owner_id <> auth.uid() then
      raise exception 'Only the current owner may transfer ownership of this trip';
    end if;
    return new;
  end;
  $$;

  drop trigger if exists guard_owner_id_change on public.itineraries;
  create trigger guard_owner_id_change
    before update on public.itineraries
    for each row execute function public.prevent_unauthorized_owner_change();
  ```
- **4. Resolution Mechanism:** RLS's `with check` can only reason about the final row state — exactly the gap being exploited. A `BEFORE UPDATE` trigger has access to both `OLD` and `NEW` and independently re-verifies that whoever is changing `owner_id` was already the row's owner *before* the write, closing the escalation path regardless of which client or API call attempts it.

---

### [SEC-002] Secrets bundled into the compiled app binary via `pubspec.yaml` assets

- **Category:** Security Flaw
- **Severity:** Critical
- **Status:** ✅ Resolved (2026-08-05) — `.env`/`.env.development` removed from `pubspec.yaml` assets; `lib/config/environment.dart` now reads only `String.fromEnvironment`; build via `--dart-define-from-file=env.local.json` (see `env.example.json`).
- **Location:** `pubspec.yaml:58-59` (asset declarations), `lib/main.dart:24` (`dotenv.load()`), `lib/config/environment.dart:20-26`
- **1. Cause:** `.env`/`.env.development` are declared under `flutter: assets:`, bundling their raw contents verbatim into every compiled APK/IPA (`assets/flutter_assets/.env`) — debug, staging, and release alike. Being gitignored only keeps them out of source control; it does nothing to stop them reaching the shipped binary, which is trivially unzippable by anyone with the installer.
- **2. Impact:** Today's `.env` only holds the intentionally-public Supabase URL/anon key (see SEC-code below on why that's fine), so current blast radius is low — but the *mechanism* is the vulnerability: the file has a slot for `ANTHROPIC_API_KEY`, and there is no build-time guard stopping a developer from populating it locally and shipping a release build with a real secret embedded. There is no CI check that would catch this.
- **3. Remediation:**
  ```diff
  // pubspec.yaml
  flutter:
    assets:
  -   - .env
  -   - .env.development
      - assets/images/
      - assets/icons/
  ```
  ```diff
  // lib/config/environment.dart
  - import 'package:flutter_dotenv/flutter_dotenv.dart';
    static String get supabaseUrl =>
  -     dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');
  +     const String.fromEnvironment('SUPABASE_URL');
    static String get supabaseAnonKey =>
  -     dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? const String.fromEnvironment('SUPABASE_ANON_KEY');
  +     const String.fromEnvironment('SUPABASE_ANON_KEY');
  ```
  ```diff
  // lib/main.dart
  - try { await dotenv.load(); } catch (e) { AppLogger.warning('Could not load .env file: $e'); }
  + // Values are injected at build time via --dart-define-from-file=env.local.json
  + // (gitignored, never referenced in pubspec.yaml assets).
  ```
- **4. Resolution Mechanism:** `--dart-define-from-file` resolves values into the Dart constant pool at build time from a file that lives outside the asset bundle, removing the pattern that lets an unreviewed local `.env` get silently packaged into every build by default.

---

### [SEC-003] `delete_user()` RPC fails for any user who has an expense, packing item, or rating — GDPR right-to-erasure is broken in practice

- **Category:** Privacy Violation (also a functional Security Flaw — an advertised control silently fails)
- **Severity:** Critical
- **Status:** ✅ Resolved (2026-08-05) — `docs/supabase_migrations/stage23_security_hardening.sql` adds `on delete cascade` to the three missing FKs.
- **Location:** `docs/supabase_migrations/stage4_expenses.sql:18` (`payer_id`), `stage5_packing.sql:13` (`added_by_id`), `stage4_ratings.sql:15` (`user_id`) — none has `on delete cascade`, unlike every other `auth.users(id)` FK in the schema (`profiles`, `messages`, `notification_preferences`, `trip_segments`, `push_tokens`, `itinerary_posts`, `post_likes`, `follows`, `pending_invitations` all correctly cascade)
- **1. Cause:** These three FKs declare `references auth.users(id)` with no `on delete` clause, defaulting to Postgres's `NO ACTION`/`RESTRICT`. `delete_user()`'s `delete from auth.users where id = auth.uid()` raises a foreign-key-violation and rolls back the entire deletion the moment the target user has ever paid an expense, added a packing item, or left a rating — i.e. almost any user who has actually used the app.
- **2. Impact:** The app's only GDPR Art. 17 / CCPA right-to-delete mechanism throws a database error for the large majority of real users instead of deleting their account. This is worse from a regulatory standpoint than having no delete feature at all — it's a shipped, documented control that silently fails.
- **3. Remediation:**
  ```sql
  -- new migration, e.g. stage23_fix_erasure_cascades.sql
  -- (check exact constraint names first: select conname from pg_constraint where conrelid = 'public.expenses'::regclass;)
  alter table public.expenses
    drop constraint expenses_payer_id_fkey,
    add constraint expenses_payer_id_fkey
      foreign key (payer_id) references auth.users(id) on delete cascade;

  alter table public.packing_items
    drop constraint packing_items_added_by_id_fkey,
    add constraint packing_items_added_by_id_fkey
      foreign key (added_by_id) references auth.users(id) on delete cascade;

  alter table public.ratings
    drop constraint ratings_user_id_fkey,
    add constraint ratings_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  ```
  Note: if shared-trip expense history should survive a payer's deletion (e.g. so other members still see "who owed what"), use `on delete set null` on `payer_id` instead of cascade — either choice fixes the erasure bug; the current *absence* of either is the actual defect.
- **4. Resolution Mechanism:** Once these three FKs have an `on delete` action, deleting the `auth.users` row no longer conflicts with a dangling reference, so `delete_user()` completes successfully regardless of what the user has done in the app.

---

### [SEC-004] Private-profile data delivered to the client in full regardless of visibility setting — no server-side enforcement

- **Category:** Privacy Violation / Security Flaw (Broken Access Control)
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-05) — `stage23_security_hardening.sql` tightens `profiles_select`; `lib/features/profile/data/datasources/user_profile_remote_datasource.dart` adds a client-side backstop and a restricted public column set.
- **Location:** `docs/supabase_migrations/stage2_profiles_and_messages.sql:26-27` (`profiles_select` policy, never tightened despite `profile_visibility` being added in `stage16_extended_profile.sql:25-28`); `lib/features/profile/data/datasources/user_profile_remote_datasource.dart:77-97` (`getProfileById`); `lib/features/social/presentation/pages/public_profile_page.dart:124-125,175-187,239-260`
- **1. Cause:** `profiles_select` is `for select using (auth.role() = 'authenticated')` — it grants read access to the entire profile row (bio, city, country, timezone, travel tags, avatar, email) to **any** authenticated user, unconditionally. When `profile_visibility` was added, no corresponding RLS change gated row visibility on it. `getProfileById()` queries with no visibility filter either, and `PublicProfilePage`'s `_isPrivate` check only hides the `bio` widget and posts list in the *rendered UI* — the full row is already in memory on the client before that check runs.
- **2. Impact:** A user who sets their profile to "private" gets no actual protection. Anyone with a valid session can retrieve the full row directly via the Supabase REST API (`GET /rest/v1/profiles?id=eq.<uuid>`), bypassing the app UI entirely. This is precisely the "privacy control is theater" pattern a regulator or security researcher flags — GDPR Art. 5(1)(f) (integrity/confidentiality) and Art. 25 (protection by design/default) exposure.
- **3. Remediation:**
  ```sql
  drop policy if exists "profiles_select" on public.profiles;

  create policy "profiles_select" on public.profiles
    for select using (
      auth.uid() = id                 -- always see your own row
      or profile_visibility = 'public' -- public profiles readable by anyone
      -- fast-follow once membership is normalized (see SEC-005):
      -- or exists (shared-trip collaborator check)
    );
  ```
  Plus a client-side defense-in-depth backstop so a private profile fails safely even if a future code path forgets to filter:
  ```dart
  // user_profile_remote_datasource.dart
  final model = UserProfileModel.fromJson(rows.first);
  final viewerId = KumoSupabaseClient.auth.currentUser?.id;
  if (model.profileVisibility == 'private' && model.id != viewerId) {
    throw AuthException(message: 'This profile is private');
  }
  return model;
  ```
- **4. Resolution Mechanism:** Moving the visibility decision into the RLS policy means the database — not the Flutter client — is the enforcement boundary: the row is physically unreadable by an unauthorized party regardless of which client or raw API call is used. The client-side throw is a fail-safe backstop, not the primary control.

---

### [SEC-005] Any trip editor can arbitrarily rewrite or remove other members, including the owner's own membership entry

- **Category:** Security Flaw
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-05) — `docs/supabase_migrations/stage23_security_hardening.sql` (`guard_members_mutation` trigger).
- **Location:** `docs/supabase_migrations/stage12_fix_member_visibility.sql:33-52` (same policy as SEC-001; broader exploitable surface)
- **1. Cause:** `itineraries_member_update`'s `with check` only requires that the *caller* still has an editor/owner entry somewhere in the resulting `members` array — it places no constraint on what happens to *other* members' entries. Since `members` is one JSONB column the caller fully controls in a single UPDATE, an editor can submit an array that removes the real owner's entry, demotes another editor, or fabricates an `"owner"` role for themselves.
- **2. Impact:** An editor invited only to help plan a trip can unilaterally remove or demote every other collaborator, or fake elevated status that fools client-side role-gated UI (e.g. "Remove member" affordances keyed off the members array rather than the immutable `owner_id` column). Real risk on shared/family/group trips.
- **3. Remediation:**
  ```sql
  create or replace function public.guard_members_mutation()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    _uid uuid := auth.uid();
  begin
    if old.owner_id = _uid then
      return new; -- the real owner may always manage membership freely
    end if;
    if exists (
      select 1 from jsonb_array_elements(old.members) as m
      where not (m->>'user_id' = _uid::text or m->>'userId' = _uid::text)
        and not (new.members @> jsonb_build_array(m))
    ) then
      raise exception 'Only the trip owner may add, remove, or change other members';
    end if;
    return new;
  end;
  $$;

  drop trigger if exists guard_members_mutation on public.itineraries;
  create trigger guard_members_mutation
    before update on public.itineraries
    for each row execute function public.guard_members_mutation();
  ```
  **Longer-term fix:** normalize `members` into a real `itinerary_members(itinerary_id, user_id, role)` table with its own RLS restricted to `owner_id = auth.uid()` for insert/update/delete — this whole class of bug (stage11→stage13's repeated JSONB-membership fixes) stems from one mutable blob having no row-level granularity.
- **4. Resolution Mechanism:** The trigger diffs `OLD.members` against `NEW.members` and rejects any write where a non-owner altered or removed an entry that isn't their own — directly enforcing "editors can only affect their own membership row."

---

### [SEC-006] `invite-email` Edge Function has no membership check — arbitrary trip disclosure and unsolicited invite relay

- **Category:** Security Flaw
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-05) — `supabase/functions/invite-email/index.ts` now checks caller membership before reading trip data or sending an invite.
- **Location:** `supabase/functions/invite-email/index.ts:41-74`
- **1. Cause:** The function verifies the caller holds a *valid* session but never checks they're a member/owner of the `itinerary_id` in the request body, then uses the **service-role client** (bypasses RLS entirely) to read that trip's `title`/`start_date`/`end_date` and call `auth.admin.inviteUserByEmail` for an attacker-supplied `invited_email`. (Independently identified by two separate audit passes, confirming it.)
- **2. Impact:** Any authenticated user who obtains an `itinerary_id` (trivially available — a public social post's `source_itinerary_id`, a shared link, a past membership) can (a) read any trip's title/dates regardless of relationship to it, and (b) trigger Kumo's real email infrastructure to send an unsolicited "you're invited" email to any third-party address at will — an open spam/phishing relay riding on Kumo's sender reputation. OWASP A01:2021 Broken Access Control / IDOR.
- **3. Remediation:**
  ```diff
     if (!trip) {
       return json({ error: 'Trip not found' }, 404)
     }

  +  const memberIds: string[] = (trip.members ?? [])
  +    .map((m: { userId?: string; user_id?: string }) => m.userId ?? m.user_id)
  +    .filter((id: string | undefined): id is string => !!id)
  +  const isAuthorized = trip.owner_id === user.id || memberIds.includes(user.id)
  +  if (!isAuthorized) {
  +    return json({ error: 'Forbidden' }, 403)
  +  }
  +
     const inviterName = inviter?.display_name || inviter?.email || 'A Kumo traveller'
  ```
  (also add `owner_id, members` to the initial `.select()`.)
- **4. Resolution Mechanism:** Re-deriving authorization from the caller's actual membership before any privileged read/send happens closes both the disclosure and spam-relay paths, mirroring the ownership check `send-message-push` already gets right (see Verified Compliant Controls below).

---

### [SEC-007] Session tokens persisted via default plaintext local storage — no secure storage configured

- **Category:** Security Flaw
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-05) — `lib/core/network/supabase_client.dart` now persists the Supabase session via a `FlutterSecureStorage`-backed `LocalStorage` implementation.
- **Location:** `lib/core/network/supabase_client.dart:20-25` (`Supabase.initialize()` with no `authOptions`/custom local storage); `pubspec.yaml` (no `flutter_secure_storage` dependency at all)
- **1. Cause:** `supabase_flutter` defaults to a `SharedPreferences`-backed session store when no `FlutterAuthClientOptions(localStorage: ...)` is supplied. `SharedPreferences` is an unencrypted XML file (Android) / plist (iOS) in app-private storage — not OS-level secure storage. The long-lived `access_token`/`refresh_token` pair (sufficient for full account takeover for its lifetime) is stored in cleartext on-device.
- **2. Impact:** Filesystem-level access without full OS compromise (a malicious app with shared storage access on older/rooted Android, an unencrypted local backup, forensic extraction) yields a directly usable session token with no decryption step required.
- **3. Remediation:**
  ```diff
  // pubspec.yaml
  dependencies:
  +   flutter_secure_storage: ^9.0.0
  ```
  ```dart
  // lib/core/network/supabase_client.dart
  class _SecureSessionStorage extends LocalStorage {
    const _SecureSessionStorage();
    static const _storage = FlutterSecureStorage();
    static const _key = 'supabase.session';
    @override
    Future<void> initialize() async {}
    @override
    Future<String?> accessToken() => _storage.read(key: _key);
    @override
    Future<bool> hasAccessToken() async => (await _storage.read(key: _key)) != null;
    @override
    Future<void> persistSession(String s) => _storage.write(key: _key, value: s);
    @override
    Future<void> removePersistedSession() => _storage.delete(key: _key);
  }
  // ... Supabase.initialize(..., authOptions: const FlutterAuthClientOptions(localStorage: _SecureSessionStorage()))
  ```
- **4. Resolution Mechanism:** Routes session persistence through the Android Keystore / iOS Keychain, both hardware-backed and encrypted at rest independent of filesystem access — a raw file read or unencrypted backup no longer yields a usable token.

---

### [SEC-008] `contactVisibility` is a phantom control — collected, presented to users, never enforced; email exposed on every profile fetch

- **Category:** Privacy Violation
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `user_profile_remote_datasource.dart` splits `_publicCols`/`_ownCols`; `email` is never selected for another user's profile.
- **Location:** `lib/features/profile/domain/entities/user_profile.dart:60-61`; `lib/features/profile/data/datasources/user_profile_remote_datasource.dart:42-47`; no enforcement site exists anywhere in `lib/` (verified by repo-wide grep for `contactVisibility`/`contact_visibility`)
- **1. Cause:** `contactVisibility` ('collaborators_only' | 'hidden') is documented as controlling email/phone exposure and is user-editable in Privacy Settings — but nothing ever reads it back. `email` is unconditionally selected in `_cols` and returned for both `getOwnProfile()` and `getProfileById()` regardless of who's asking.
- **2. Impact:** Users are shown a setting that implies control over who sees their email, and it does nothing — every authenticated user viewing any profile receives that email. A GDPR Art. 5(1)(a) fairness/transparency problem: the app represents a capability it doesn't provide.
- **3. Remediation:**
  ```dart
  // Split into two column sets in user_profile_remote_datasource.dart
  static const _publicCols = 'id, display_name, username, avatar_url, bio, city, '
      'country, timezone, preferred_currency, preferred_language, units_preference, '
      'travel_preference_tags, profile_visibility, updated_at';
  static const _ownCols = '$_publicCols, email, contact_visibility, is_searchable, '
      'username_last_changed_at, push_message_preview_enabled';

  @override
  Future<UserProfileModel> getProfileById(String userId) async {
    final rows = await KumoSupabaseClient.client
        .from('profiles').select(_publicCols).eq('id', userId).limit(1);
    // ... never select email/contact_visibility for other users' profiles
  }
  ```
- **4. Resolution Mechanism:** Removing `email`/`contact_visibility` from the column set used for *other users'* fetches means the data never leaves the database for that request. If a genuine "visible to collaborators" feature is wanted later, it needs an explicit, separately-gated query — not a blanket profile fetch.

---

### [SEC-009] No rate limiting on the AI itinerary-generation endpoint — unbounded billing exposure

- **Category:** Security Flaw
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `generation_requests` table + per-user hourly cap added in `stage23_security_hardening.sql` and enforced in `supabase/functions/generate-itinerary/index.ts`.
- **Location:** `supabase/functions/generate-itinerary/index.ts:22-148`
- **1. Cause:** The only gate is "does this request carry a valid Supabase session" — no per-user or global rate limit exists before the function calls the paid Anthropic Messages API. (Independently identified by two audit passes.)
- **2. Impact:** A single compromised or maliciously self-signed-up account can script unlimited calls, translating directly to unbounded Anthropic API billing (OWASP API4:2023 Unrestricted Resource Consumption) with no circuit breaker.
- **3. Remediation:**
  ```diff
  +    const { count } = await supabase
  +      .from('generation_requests')
  +      .select('*', { count: 'exact', head: true })
  +      .eq('user_id', user.id)
  +      .gte('created_at', new Date(Date.now() - 60 * 60 * 1000).toISOString())
  +    if ((count ?? 0) >= 10) {
  +      return json({ error: 'Rate limit exceeded — try again later' }, 429)
  +    }
  +    await supabase.from('generation_requests').insert({ user_id: user.id })
  +
       const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
  ```
- **4. Resolution Mechanism:** Caps paid upstream calls per user per hour, bounding worst-case spend from any single account to a known, budgetable ceiling.

---

### [SEC-010] `mark_messages_read()` doesn't verify the caller is a member of the target itinerary

- **Category:** Security Flaw
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `stage23_security_hardening.sql` reissues `mark_messages_read()` with a membership check.
- **Location:** `docs/supabase_migrations/stage19_chat_upgrade.sql:116-136` (originally `stage15_read_receipts.sql:15-26`)
- **1. Cause:** This `SECURITY DEFINER` function (bypasses RLS by design) takes a caller-supplied `p_itinerary_id` but never checks `auth.uid()` is actually a member/owner before updating `messages.read_by` and inserting into `message_reads`.
- **2. Impact:** Any authenticated user can call this for a trip they don't belong to — doesn't leak message content, but lets an attacker enumerate valid itinerary UUIDs and pollutes read-receipt integrity for trips they were never part of (a stranger's user_id appearing in another group's read receipts).
- **3. Remediation:**
  ```sql
  create or replace function public.mark_messages_read(p_itinerary_id uuid)
  returns void language plpgsql security definer set search_path = public as $$
  begin
    if not exists (
      select 1 from public.itineraries i
      where i.id = p_itinerary_id
        and (i.owner_id = auth.uid() or exists (
          select 1 from jsonb_array_elements(i.members) as m
          where m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text
        ))
    ) then
      raise exception 'Not a member of this itinerary';
    end if;
    -- ... existing update_by/message_reads logic unchanged
  end;
  $$;
  ```
- **4. Resolution Mechanism:** Adds the same membership check every other itinerary-scoped policy already uses, closing the gap between "this function bypasses RLS by design" and "this function should still enforce equivalent authorization."

---

### [SEC-011] Cached user profile (including phone number) stored unencrypted in `SharedPreferences`

- **Category:** Privacy Violation
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `lib/features/auth/data/datasources/auth_local_datasource.dart` now uses `FlutterSecureStorage` instead of `SharedPreferences`.
- **Location:** `lib/features/auth/data/datasources/auth_local_datasource.dart:22-41`; `lib/features/auth/data/models/user_model.dart:48-58`
- **1. Cause:** `AuthLocalDataSourceImpl` writes the full `UserModel` JSON (email, display name, avatar URL, phone number when present) into plain `SharedPreferences` under `cached_user`, as an offline-fallback cache, with no encryption or data minimization.
- **2. Impact:** Same at-rest exposure as SEC-007, applied to PII: a filesystem-level read discloses phone number and identity data. GDPR Art. 32 ("appropriate technical measures") gap.
- **3. Remediation:** Route this cache through `FlutterSecureStorage` (same dependency as SEC-007) instead of `SharedPreferences`; at minimum, strip `phone_number` from what this specific cache persists, since the offline-fallback use case only needs id/email/displayName/avatarUrl.
- **4. Resolution Mechanism:** Secure storage encrypts via OS keystore/keychain; trimming fields applies data minimization so a worst-case cache read discloses less regardless.

---

### [SEC-012] No data-export/portability mechanism anywhere in the app (GDPR Art. 20 / CCPA)

- **Category:** Privacy Violation
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `export_own_data()` RPC added in `stage23_security_hardening.sql`. Note: not yet wired to a "Download my data" UI action in `PrivacySettingsPage` — the backend capability exists; the settings-page button is a follow-up.
- **Location:** N/A — absence of feature. `delete_user()` (erasure) exists; nothing analogous exists for export. Checked `lib/features/profile/**`, `lib/features/settings/**`, and every migration.
- **1. Cause:** The app implements the right to erasure but has no corresponding self-service mechanism for a user to obtain a copy of their own data.
- **2. Impact:** GDPR Art. 20 (data portability) and CCPA's "right to know"/"right to obtain a copy" both require this. A regulator reviewing compliance would flag the asymmetry: erasure implemented, portability not.
- **3. Remediation:**
  ```sql
  create or replace function public.export_own_data()
  returns jsonb language plpgsql security definer set search_path = public as $$
  declare _uid uuid := auth.uid();
  begin
    return jsonb_build_object(
      'profile', (select to_jsonb(p) from public.profiles p where p.id = _uid),
      'itineraries', (select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb) from public.itineraries i where i.owner_id = _uid),
      'expenses', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) from public.expenses e where e.payer_id = _uid),
      'ratings', (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from public.ratings r where r.user_id = _uid),
      'published_posts', (select coalesce(jsonb_agg(to_jsonb(pp)), '[]'::jsonb) from public.itinerary_posts pp where pp.author_id = _uid)
    );
  end;
  $$;
  revoke all on function public.export_own_data() from anon;
  grant execute on function public.export_own_data() to authenticated;
  ```
  Pair with a "Download my data" action in `PrivacySettingsPage` that calls it and shares/saves the JSON result.
- **4. Resolution Mechanism:** Gives users (and the company, responding to a data-subject-access request) a self-service, `auth.uid()`-scoped path to fulfill the portability obligation, using the same trusted pattern `delete_user()` already established.

---

### [SEC-013] Publishing an itinerary broadcasts free-text description/item fields with no disclosure at the point of consent

- **Category:** Privacy Violation
- **Severity:** Medium
- **Status:** ✅ Resolved (2026-08-05) — `itinerary_detail_page.dart`'s `_StatusRow._publish` now shows a confirmation dialog before the first publish.
- **Location:** `lib/features/social/data/models/itinerary_post_model.dart:64-83` (`buildInsertJson`); publish entry point in `itinerary_detail_page.dart`'s `_StatusRow._publish`
- **1. Cause:** `buildInsertJson` copies `itinerary.description` and every item's title/location verbatim into the public `itinerary_posts.snapshot`. These are free-text fields filled in for a *private* trip with no expectation of publication (e.g. a description mentioning a friend's home address as a meeting point). The Publish button gives no "this will make your description and stops public" confirmation.
- **2. Impact:** Users can inadvertently publish personal information (their own or a third party's) to a public feed with no warning and — given posts are immutable/undeletable by design — no way to retract it. A purpose-limitation problem (GDPR Art. 6(4)/Art. 5(1)(b)): data collected for private planning is repurposed for public broadcast without a distinct consent step.
- **3. Remediation:**
  ```dart
  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    if (!itinerary.isPublic) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Publish this trip?'),
          content: const Text('Your title, description, and itinerary stops will '
              'become visible to everyone on Discover. Trip notes and member names '
              'stay private. This cannot be undone once published.'),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Publish')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    // ... existing publish logic
  }
  ```
- **4. Resolution Mechanism:** Surfacing exactly what becomes public at the moment the irreversible action is taken converts an implicit/absent consent into an informed, specific one.

---

### [SEC-014] Firebase config files with embedded API key were previously committed to git history

- **Category:** Security Flaw (Secret Exposure)
- **Severity:** Medium
- **Status:** ⚠️ Open — requires manual action outside this codebase (rotate/restrict the Firebase API key in the Firebase console; cannot be done from a code change). Left in Active Remediation Log below.
- **Location:** git history — `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` (per this repo's own `lib/features/chat/CLAUDE.md`: committed when Firebase was first wired up, now gitignored)
- **1. Cause:** The files were committed at least once before being gitignored; removing them from the working tree doesn't remove them from git history — anyone with a full clone or old mirror can recover the historical commit and extract the embedded key.
- **2. Impact:** A Firebase per-app API key can be used for API abuse/quota exhaustion if Firebase security rules aren't locked down, and its presence in history is exactly what automated secret scanners (GitHub push protection, gitleaks) and a compliance auditor flag as unresolved until rotated.
- **3. Remediation:** Confirm the specific leaked key has been rotated/restricted in the Firebase console to this app's package name + SHA-1/bundle ID (mirroring what's already documented for the Google Maps key); if not, do it now. Git-history scrubbing is optional once the key itself is invalidated.
- **4. Resolution Mechanism:** Rotating/restricting the key makes the historical copy useless to an attacker regardless of whether it's still recoverable from history — targeting the credential's validity, not just its visibility.

---

### [SEC-015] Unused `getSession()` API exposes raw access/refresh tokens as a plain map — latent logging risk

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `getSession()` removed from `AuthRemoteDataSource`/`AuthRepositoryImpl`/`AuthRepository`.
- **Location:** `lib/features/auth/data/datasources/auth_remote_datasource.dart:207-218`; `lib/features/auth/domain/repositories/auth_repository.dart:188-191`
- **1. Cause:** `getSession()` returns `{'access_token', 'refresh_token', 'expires_at'}` as a bare map. Zero callers exist anywhere in `lib/` — it's dead code a future contributor could call and accidentally log.
- **2. Impact:** Low likelihood today, but if wired up carelessly (e.g. "let me log the session to debug this"), it puts a live, reusable token pair directly into application logs.
- **3. Remediation:** Delete the method if genuinely unused (matches YAGNI); if session introspection is needed later, expose `Future<Either<Failure, bool>> hasValidSession()` instead — no raw token material.
- **4. Resolution Mechanism:** Removes the only code path handing a full session secret to arbitrary calling code, closing the accidental-logging vector at the source.

---

### [SEC-016] Trip data (including budget figures and item geolocation) cached unencrypted in local device storage

- **Category:** Privacy Violation
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `lib/features/itinerary/data/datasources/itinerary_local_datasource.dart` now uses `FlutterSecureStorage` instead of `SharedPreferences`.
- **Location:** `lib/features/itinerary/data/datasources/itinerary_local_datasource.dart:11-32`
- **1. Cause:** `saveItineraries` serializes full itinerary objects (budget, currency, item titles/locations/lat-lng) to plaintext JSON in `SharedPreferences` as an offline-read cache.
- **2. Impact:** On a rooted/jailbroken device or via backup extraction, this exposes financial data and location history without needing app credentials — GDPR Art. 32 data-at-rest gap.
- **3. Remediation:** Swap to `FlutterSecureStorage` for this cache (same dependency as SEC-007/SEC-011), keeping the same call shape (`read`/`write` by `userId`-keyed key instead of `SharedPreferences.setString`).
- **4. Resolution Mechanism:** Backs onto iOS Keychain / Android Keystore, both encrypted at rest, without changing the datasource's public API or callers.

---

### [SEC-017] Chat push-notification preview defaults to showing full message content

- **Category:** Privacy Violation
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — entity default changed in `lib/features/profile/domain/entities/user_profile.dart`; column default changed in `stage23_security_hardening.sql` (existing users' own settings untouched).
- **Location:** `lib/features/profile/domain/entities/user_profile.dart:20` (`pushMessagePreviewEnabled = true` default)
- **1. Cause:** New users default to previews enabled, so chat content appears on the lock screen before an active choice is made.
- **2. Impact:** Sensitive conversation content is visible on a locked device by default. Not a violation on its own (industry-standard default), but it's the one privacy-relevant default in this codebase that isn't "privacy by default" per GDPR Art. 25.
- **3. Remediation:** Default to `false` (opt-in to previews) or add a one-time explicit choice prompt post-onboarding instead of a silent default.
- **4. Resolution Mechanism:** New users start in the more private state and must take an affirmative action to enable previews.

---

### [SEC-018] `message_attachments_member_read` uses the pre-stage13 camelCase-only membership check (fails closed, not a real exposure — availability regression)

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `stage23_security_hardening.sql` reissues `message_attachments_member_read` with the dual-key check.
- **Location:** `docs/supabase_migrations/stage19_chat_upgrade.sql:42-55`
- **1. Cause:** Written using the old single-key check (`userId` only), reintroducing the exact gap stage12/13 fixed for every other table's JSONB-membership checks.
- **2. Impact:** Not an exposure — fails closed. A member added via the Flutter client (snake_case entry) is incorrectly denied access to attachments they're otherwise entitled to read. Indicates the stage12/13 fix pattern wasn't propagated forward.
- **3. Remediation:** Rewrite using the dual-key `m->>'user_id' = ... or m->>'userId' = ...` pattern used everywhere else in the schema.
- **4. Resolution Mechanism:** Brings this policy in line with the dual-key pattern, recognizing membership correctly regardless of which code path wrote the entry.

---

### [SEC-019] Orphaned `kumo_schema.sql` defines a disconnected, partially-unprotected schema

- **Category:** Security Flaw (configuration/hygiene risk)
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — moved to `docs/archive/2026-06-12_early_schema_draft_UNUSED.sql` with a non-authoritative header note.
- **Location:** `kumo_schema.sql` (repo root — predates the staged-migration system; confirmed unreferenced by any script, CI config, or app code)
- **1. Cause:** Defines an entirely different, self-contained schema with no relationship to the real deployed schema. Enables RLS on only 9 of the tables it creates — any other table it defines would be fully open if this file were ever executed.
- **2. Impact:** Currently inert, but a live landmine: any future engineer or IaC tool treating a root-level `*_schema.sql` as authoritative could deploy a parallel, partially-unprotected data model. Also actively misleading to anyone auditing the codebase.
- **3. Remediation:** `git rm kumo_schema.sql`, or `git mv` it to a clearly-marked `docs/archive/` location if historical value is wanted.
- **4. Resolution Mechanism:** Removes the risk of accidental execution and the documentation-drift confusion of two coexisting, differently-secured schemas.

---

### [SEC-020] Unbounded verbose error disclosure in all Edge Functions

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — all three Edge Functions now return a generic `Internal server error` message to the client (full detail still goes to `console.error`).
- **Location:** `supabase/functions/generate-itinerary/index.ts:144-146`, `invite-email/index.ts:137-139`, `send-message-push/index.ts:232-233`
- **1. Cause:** Every function's top-level `catch (e)` returns `{ error: String(e) }` verbatim to the client, including whatever internal error object the runtime/SDKs produced.
- **2. Impact:** Low-likelihood information disclosure (OWASP A05:2021) — internal error strings can leak implementation details useful for reconnaissance.
- **3. Remediation:**
  ```diff
  } catch (e) {
    console.error('Unexpected error:', e)
  -  return json({ error: String(e) }, 500)
  +  return json({ error: 'Internal server error' }, 500)
  }
  ```
- **4. Resolution Mechanism:** Keeps detail in server-side logs (visible in the Supabase dashboard) while returning only a generic message to the untrusted client.

---

### [SEC-021] No abuse/rate limiting on public social actions (publish/like/follow)

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `stage23_security_hardening.sql` adds a 30-second per-author publish cooldown (`guard_publish_rate_limit` trigger). Full rate limiting for likes/follows deliberately deferred — both are already bounded by PK uniqueness.
- **Location:** `lib/features/social/domain/usecases/publish_itinerary_usecase.dart`, `toggle_like_usecase.dart`, `toggle_follow_usecase.dart` — no throttle at client or server layer
- **1. Cause:** RLS only checks *identity* on these writes, never *frequency*; no client debounce or server-side rate limit exists.
- **2. Impact:** A scripted client on a legitimate account can spam-publish, like-bomb, or mass-follow, degrading feed quality and enabling follow-based harassment at negligible cost. Low severity given current app scale.
- **3. Remediation:** A Postgres trigger/check rejecting an insert if the same actor wrote a row in the last N seconds (same pattern as SEC-009's throttle table), or defer to an API-gateway rate limiter if traffic grows.
- **4. Resolution Mechanism:** Bounds write frequency per identity independent of client behavior, since RLS alone only ever answers "who," never "how often."

---

### [SEC-022] Wildcard CORS on all Edge Functions

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — all three Edge Functions now read `ALLOWED_ORIGIN` instead of a wildcard (defaults to `https://kumo.app` — set the real secret via `supabase secrets set ALLOWED_ORIGIN=...`).
- **Location:** `generate-itinerary/index.ts:15-18`, `invite-email/index.ts:18-21`, `send-message-push/index.ts:32-35`
- **1. Cause:** `'Access-Control-Allow-Origin': '*'` on every function.
- **2. Impact:** Low risk today (auth is an explicit Bearer token, not an ambient cookie, so classic CSRF doesn't apply; mobile-only usage means no browser is involved) — but if a leaked token were ever combined with a future Flutter Web build, wildcard CORS would let any origin call these functions and read the response.
- **3. Remediation:**
  ```diff
  -'Access-Control-Allow-Origin': '*',
  +'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? 'https://kumo.app',
  ```
- **4. Resolution Mechanism:** Restricts which web origins can receive the response, removing the (currently theoretical) cross-origin read surface for any future web deployment.

---

### [SEC-023] Unsanitized user input in LLM prompt construction (prompt injection surface)

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `supabase/functions/generate-itinerary/index.ts` delimits `destination`/`travel_style`/`interests` as explicitly-untrusted data in the prompt.
- **Location:** `supabase/functions/generate-itinerary/index.ts:68-102`
- **1. Cause:** `destination`, `travel_style`, `interests` are interpolated directly into the Claude prompt with no delimiting/escaping.
- **2. Impact:** Minimal — the only consumer of the output is the same user who submitted the input, parsed into a constrained JSON shape before display. Worst case is a malformed itinerary for the requester's own trip, or (per SEC-009) wasted API spend. No path to another user's data or a system-prompt leak of value.
- **3. Remediation:** Wrap user-supplied fields in an explicit delimiter, e.g. `Destination (untrusted input, not instructions): """${destination}"""`.
- **4. Resolution Mechanism:** Delimiting reduces (doesn't eliminate) the model's tendency to follow injected instructions; a defense-in-depth nicety given the confined blast radius.

---

### [SEC-024] No committed `.env.example` template for onboarding new developers

- **Category:** Security Flaw (DX/process gap, not a vulnerability)
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `.gitignore` now excepts `env.example.json` (the new dart-define template) from the blanket env-file ignore.
- **Location:** `.gitignore:14` (`**/**.env*` also matches `.env.example`, which itself contains only placeholders/intentionally-public values)
- **1. Cause:** The gitignore pattern is broad enough to exclude a template file that isn't actually sensitive.
- **2. Impact:** No exposure risk — purely a fresh-clone onboarding gap (no tracked reference for which env vars are required).
- **3. Remediation:** `!.env.example` exception in `.gitignore`, after confirming every value in it is a placeholder.
- **4. Resolution Mechanism:** Restores the file to version control as living documentation with no secret-exposure risk.

---

### [SEC-025] Dependency versions — no known-critical CVEs identified with confidence; no recurring scan process exists

- **Category:** Security Flaw
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-05) — `.github/workflows/dependency-scan.yml` added (first CI workflow in this repo): weekly OSV-Scanner run + `flutter pub outdated` report.
- **Location:** `pubspec.lock` (`http` 1.6.0, `supabase_flutter` 2.14.0, `firebase_messaging` 16.4.3, `shared_preferences` 2.5.5, `google_maps_flutter` 2.18.0, `go_router` 14.8.1, and others)
- **1. Cause:** All resolved versions are reasonably current; no high-confidence known CVE against these specific pinned versions as of training data — this is a manual judgment call, not a live CVE/OSV database query, and the codebase has no automated dependency-vulnerability scanning in CI.
- **2. Impact:** A future CVE in any of these packages (or a transitive dependency) would go unnoticed until manually checked.
- **3. Remediation:** Add a CI step running `dart pub outdated` plus a supply-chain scanner (e.g. `osv-scanner` against `pubspec.lock`) on a schedule and on every dependency-bump PR.
- **4. Resolution Mechanism:** Automated, recurring scanning against a live vulnerability database catches CVEs disclosed after this audit date, which a one-time manual review cannot.

---

### [SEC-026] `org_members` RLS policies recursed into themselves — every org/work-mode policy touching membership failed with Postgres error 42P17

- **Category:** RLS Defect (availability, not a data exposure)
- **Severity:** High (breaks the feature, not exploitable for unauthorized access)
- **Status:** ✅ Resolved (2026-08-09) — `docs/supabase_migrations/stage31_fix_org_members_rls_recursion.sql`
- **Location:** `org_members`' own SELECT/INSERT/UPDATE/DELETE policies (stage28), plus every `organizations`/`itineraries`/`expenses`/`org_cost_fields*` policy that checked org membership via an inline `exists (select 1 from public.org_members ...)` (stage28-30)
- **1. Cause:** `org_members_select`'s own `using` clause queried `org_members` to check membership — Postgres must re-apply `org_members`' RLS to evaluate that inner query, which means evaluating `org_members_select` again, recursively. This has been broken since the work-mode feature shipped in stage28, not a new regression.
- **2. Impact:** Every org/work-mode read or write that needed a membership check failed outright with a hard database error rather than degrading gracefully — a reliability bug, not an authorization bypass (the recursion causes a failure, not an incorrect grant).
- **3. Remediation:** Moved every membership/admin check into `SECURITY DEFINER` helper functions (`is_org_member`, `is_org_admin`, `is_org_member_for_cost_field`, `is_org_admin_for_cost_field`, `is_org_admin_for_itinerary`) which run with the function owner's privileges and so never re-trigger `org_members`' own RLS — the same pattern already used correctly elsewhere in this schema (e.g. `resolve_trip_cost_center_code`).
- **4. Resolution Mechanism:** A `SECURITY DEFINER` function's internal queries bypass RLS on the tables it reads, breaking the self-referential cycle at its source rather than working around it.

---

### [SEC-027] `generate_trip_email_alias` RPC let any authenticated user who ever knew a trip's id retrieve its masked forwarding address indefinitely

- **Category:** Security Flaw (IDOR)
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-09) — `docs/supabase_migrations/stage32_security_hardening_2.sql`
- **Location:** `generate_trip_email_alias(uuid)`, granted `EXECUTE` to `authenticated` (stage27)
- **1. Cause:** The function is `SECURITY DEFINER` (needed so its `AFTER INSERT` trigger use-case can write the alias row), but it never checked the *calling* user was actually the trip's owner or a member before returning the alias — being `SECURITY DEFINER` means its internal query bypasses `trip_email_aliases_member_select`'s RLS entirely, and the grant made it directly callable as a standalone RPC, not just from the trigger it was written for.
- **2. Impact:** Any authenticated user who ever learned an `itinerary_id` — a removed former member, a stale deep link, a social-feed fork — could resolve that trip's masked forwarding address forever, and membership removal never revoked access.
- **3. Remediation:** The function now requires the caller be the trip's owner or a member before returning anything. The `AFTER INSERT` trigger path is unaffected — it always fires with `auth.uid()` equal to the itinerary's `owner_id`, which trivially satisfies the new check.
- **4. Resolution Mechanism:** Explicit caller-authorization check inside the `SECURITY DEFINER` function body, since RLS itself is bypassed by definition for this function.

---

### [SEC-028] A payer could retarget their own expense's `itinerary_id` to any org via a direct API call, and edit financial fields after approval

- **Category:** Security Flaw (cross-tenant injection / missing state lock)
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-09) — `docs/supabase_migrations/stage32_security_hardening_2.sql`
- **Location:** `expenses_payer_update` policy (stage29) — validated only `payer_id = auth.uid()`, no check that `itinerary_id` belonged to a trip the caller had anything to do with, and no lock on financial fields post-approval
- **1. Cause:** `expenses_payer_update` didn't constrain `itinerary_id`, so a payer could `UPDATE` their own expense row's `itinerary_id` to point at an unrelated org's trip via a direct PostgREST call (not reachable through the app's own UI). `set_expense_cost_center_code` (stage30) would then snapshot that target org's real cost-center code onto the forged row, and `expenses_org_admin_review_select`'s `is_org_admin_for_itinerary` check (stage31) never verified the payer was actually a member of that itinerary — so the forged row would surface in a completely unrelated org's approval queue looking like a legitimate submission. Separately, nothing stopped editing `amount`/`title`/etc. on an already-approved expense afterward.
- **2. Impact:** Cross-tenant data injection into another organization's expense-approval queue, plus post-approval tampering with financial records that should be immutable once reviewed.
- **3. Remediation:** Two guard triggers — `itinerary_id` is now fully immutable after creation (no legitimate flow ever moves an expense between trips), and financially-meaningful fields are frozen for the payer once `approval_status = 'approved'` (an org admin's own review path, gated by `is_org_admin_for_itinerary`, is unaffected — admins only ever touch `approval_status`/`reviewed_by`/`reviewed_at`/`rejection_reason`).
- **4. Resolution Mechanism:** `BEFORE UPDATE` triggers independently re-verify invariants (immutable foreign key, frozen fields post-approval) that RLS's row-level `with check` alone can't express.

---

### [SEC-029] `org_admin_trip_visibility_select` granted org admins full-row access to itineraries, exposing personal expense history and the full member roster

- **Category:** Security Flaw (over-broad RLS grant)
- **Severity:** High
- **Status:** ✅ Resolved (2026-08-09) — `docs/supabase_migrations/stage32_security_hardening_2.sql`, `lib/features/organization/data/datasources/organization_remote_datasource.dart`
- **Location:** `org_admin_trip_visibility_select` policy (stage28)
- **1. Cause:** RLS is row-granular, not column-granular — the policy's own comment promised org admins only "title, dates, status," but granting `SELECT` on the row exposed everything in it, including `expense_summary` (a jsonb aggregate over the trip's entire expense history, personal spending included, not just `is_official`/submitted items) and the full `members` roster (every traveler's user id, name, and role, including people with zero relationship to the org — e.g. a spouse or friend along on the trip).
- **2. Impact:** Org admins could read personal financial data and unrelated travelers' identities far beyond the "the trip exists, not its content" oversight the feature was designed to provide.
- **3. Remediation:** Dropped the policy entirely. Its one real consumer — the pending-approvals list — now goes through a narrow `SECURITY DEFINER` RPC, `fetch_org_pending_approvals`, that returns only the columns that screen actually needs, with matching Dart-side changes in `organization_remote_datasource.dart`.
- **4. Resolution Mechanism:** Replacing row-level table access with a purpose-built RPC that returns a fixed, minimal column set is the practical way to get column-level granularity RLS itself can't express.

---

### [SEC-030] Startup-failure screen displayed the raw exception on-screen with no debug/release distinction

- **Category:** Information Disclosure
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-09) — `lib/main.dart` (`StartupErrorApp`)
- **Location:** `lib/main.dart` — `StartupErrorApp` (introduced alongside a fix for the app silently hanging on the native launch screen when `KumoSupabaseClient.initialize()` fails)
- **1. Cause:** The widget rendered `'$error'` (the raw exception `toString()`) directly on-screen in every build mode, with no distinction between debug/profile and release.
- **2. Impact:** Low — this path only fires on a startup configuration failure (e.g. missing `--dart-define` values), and the exception text doesn't currently contain secrets. Still, on a misconfigured release build it could reveal internal details (e.g. the Supabase project URL) to anyone with physical device access.
- **3. Remediation:** Gated the raw error text behind `kReleaseMode` — release builds now show a generic "Please contact support." message; debug/profile builds still show the full exception for developer diagnosis.
- **4. Resolution Mechanism:** Standard debug-vs-release information-hygiene split, consistent with not logging secrets in release builds elsewhere in the codebase.

---

### [SEC-031] `inbound-trip-email`'s webhook-secret comparison used `!==`, which is not constant-time

- **Category:** Security Hardening (timing side-channel)
- **Severity:** Low
- **Status:** ✅ Resolved (2026-08-09) — `supabase/functions/inbound-trip-email/index.ts`
- **Location:** `supabase/functions/inbound-trip-email/index.ts` — the `INBOUND_WEBHOOK_SECRET` bearer-token check
- **1. Cause:** `providedSecret !== expectedSecret` short-circuits on the first differing byte, so comparison time varies with how many leading characters of a guess are correct.
- **2. Impact:** Low practical risk — this is a webhook secret compared over TLS, where network jitter dominates any timing signal, and the endpoint is also behind a 20-forwards/trip/hour rate limit. Still worth closing on general principle for an endpoint reachable by an unauthenticated caller.
- **3. Remediation:** Added a `timingSafeEqual` helper that always walks the full length of both inputs regardless of where they diverge, and switched the check to use it.
- **4. Resolution Mechanism:** Constant-time comparison removes the timing side-channel entirely, independent of how unlikely it was to be practically exploitable here.

---

## Verified Compliant Controls (no action needed)

- **Anthropic API key correctly server-side only** — read via `Deno.env.get` inside Edge Functions, never bundled client-side (Stage 13 migration).
- **Supabase anon/publishable key's client-side presence is correct and expected** — it identifies the project, not a privileged caller, and grants no access beyond what RLS allows. Not to be confused with the service-role key, which is correctly confined to Edge Functions.
- **Service-role key and third-party secrets (Anthropic, Firebase service account, Resend) never appear in client code, response bodies, or full-value logs.**
- **`send-message-push` correctly checks `message.sender_id === user.id`** before using its service-role client to fan out notifications — the template `invite-email` (SEC-006) should have followed.
- **`send-message-push` correctly gates message-content push previews on the recipient's own `pushMessagePreviewEnabled` setting** before including text in the payload.
- **No HTML/Markdown/WebView rendering anywhere in the app** (repo-wide grep confirmed) — all user-controlled text renders through Flutter's `Text` widget, which doesn't interpret markup. Classic XSS is structurally not applicable.
- **`GoRouter` path parameters are used only as opaque strings in parameterized Postgrest calls**, never string-concatenated into raw SQL or filesystem paths — no path-traversal/injection surface from deep links.
- **Client code consistently self-asserts identity** for social-feature writes (`ForkPostUseCase`, `ToggleLikeUseCase`, `ToggleFollowUseCase`, `PublishItineraryUseCase`) — every call site sources the acting user from the current auth session, never from an externally-supplied parameter.
- **`itinerary_posts`/`post_likes`/`follows` (Stage 22) insert/delete policies correctly scope to `auth.uid()`**, and `follows` has a table-level `check (follower_id <> followee_id)` as defense-in-depth beyond the RLS check.
- **`update_profile()`/`delete_user()`/`upsert_push_token()`/`upsert_notification_preference()`** all source the acting user exclusively from `auth.uid()`, never a caller-supplied parameter, and use only parameterized plpgsql — no injection or impersonation surface.
- **Storage bucket policies (`avatars`, `chat-attachments`) correctly restrict writes to the caller's own `{uid}/` path prefix**, not bypassable via path tricks since Supabase Storage path-matching is literal.
- **`expenses`/`ratings`/`packing_items` DELETE policies key off the immutable `owner_id` column**, not the mutable JSONB `members` array — not directly exploitable by the SEC-005 member-array trick (though they inherit exposure if SEC-001's ownership takeover succeeds).
- **`delete_user()`'s own privilege scoping is correct** (`security definer` + `where id = auth.uid()`, `revoke ... from anon`) — a user can only ever delete their own account. The bug is the missing cascades (SEC-003), not the authorization model.
- **Signup requires explicit, gating consent** — the "Create Account" button is disabled until the user checks an "I agree to the Privacy Policy and Terms of Service" box with real links to both documents (not a pre-checked or passive pattern).
- **Push-token registration correctly gates on OS notification permission first**, before collecting the device-token PII.
- **No user-enumeration vector in login/reset flows** — generic error messages and identical "check your inbox" confirmation regardless of whether an email is registered, consistent with Supabase Auth's own anti-enumeration design.
- **No plaintext password ever logged or persisted** — read once at submit time, passed directly to the Supabase SDK call.
- **`marketing_engagement` notification category defaults to opt-out**, correct GDPR handling for marketing communications (other categories default on, correctly, since those are transactional/service notifications).
- **The social feed snapshot deliberately excludes `notes` (collaborative trip notes) and `members`** from what gets published — only items/segments/description/title are copied, keeping collaborator identities out of the public feed (the remaining description/item-text consent gap is SEC-013).
- **Native platform secrets (Firebase configs, Google Maps key, iOS `Secrets.xcconfig`) are correctly gitignored and absent from the current tracked file list** — only `.example` templates are committed (see SEC-014 for the historical-commit caveat).

---

## Resolved Findings

Fixed in code/migrations on 2026-08-05, plus a second pass on 2026-08-09 covering the work-mode/org feature and the routing/macOS diff (see the **Status** line on each finding above for the specific file/mechanism). **"Resolved" here means the fix has been written and passes `flutter analyze`/`flutter test`.** All SQL migrations, including this pass's, are now live against the production database (confirmed 2026-08-11 — see the Executive Summary). The Edge Functions still need redeploying (with the `ALLOWED_ORIGIN` secret set) before their portion of this takes effect in production.

| ID | Title | Severity |
|---|---|---|
| SEC-001 | Owner-takeover via `owner_id` UPDATE | Critical |
| SEC-002 | Secrets bundled via `pubspec.yaml` assets | Critical |
| SEC-003 | `delete_user()` FK-violation erasure failure | Critical |
| SEC-004 | Private profile data returned regardless of visibility | High |
| SEC-005 | Non-owner can rewrite/remove other members | High |
| SEC-006 | `invite-email` IDOR | High |
| SEC-007 | Session tokens in plaintext SharedPreferences | High |
| SEC-008 | `contactVisibility` phantom control / email leak | Medium |
| SEC-009 | No rate limit on `generate-itinerary` | Medium |
| SEC-010 | `mark_messages_read()` missing membership check | Medium |
| SEC-011 | Cached auth user (incl. phone) unencrypted | Medium |
| SEC-012 | No GDPR data-export mechanism | Medium |
| SEC-013 | No publish-consent dialog | Medium |
| SEC-015 | Unused `getSession()` raw-token API | Low |
| SEC-016 | Itinerary cache unencrypted | Low |
| SEC-017 | Push preview default not privacy-by-default | Low |
| SEC-018 | `message_attachments_member_read` stale key check | Low |
| SEC-019 | Orphaned `kumo_schema.sql` | Low |
| SEC-020 | Verbose error disclosure in Edge Functions | Low |
| SEC-021 | No abuse guard on public social writes | Low |
| SEC-022 | Wildcard CORS | Low |
| SEC-023 | Unsanitized LLM prompt input | Low |
| SEC-024 | No committed `.env.example` | Low |
| SEC-025 | No dependency-scan CI process | Low |
| SEC-026 | `org_members` RLS self-recursion (42P17) | High |
| SEC-027 | `generate_trip_email_alias` IDOR | High |
| SEC-028 | Expense cross-tenant `itinerary_id` retargeting + no post-approval lock | High |
| SEC-029 | `org_admin_trip_visibility_select` over-broad SELECT | High |
| SEC-030 | Raw exception shown on startup-failure screen | Low |
| SEC-031 | Non-constant-time webhook-secret comparison | Low |

**Still open:** SEC-014 (Firebase key rotation — manual console action, see Active Remediation Log above).
