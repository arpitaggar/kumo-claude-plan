# lib/features/profile

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under lib/features/profile/.

### Extended User Profile (Stage 16)

**Migration:** `docs/supabase_migrations/stage16_extended_profile.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

`public.profiles` gains these columns (all `add column if not exists`):

| Column | Type | Notes |
|--------|------|-------|
| `username` | `text` | Unique, case-insensitive (`lower(username)` unique index, NULLs distinct) |
| `bio` | `text` | |
| `city` | `text` | |
| `country` | `char(2)` | ISO 3166-1 alpha-2 |
| `timezone` | `text` | IANA tz string |
| `preferred_currency` | `char(3)` | ISO 4217 |
| `preferred_language` | `char(2)` | ISO 639-1 |
| `units_preference` | `text` | `'metric'` or `'imperial'`, NOT NULL default `'metric'` |
| `travel_preference_tags` | `text[]` | NOT NULL default `'{}'` |
| `profile_visibility` | `text` | `'public'` or `'private'`, NOT NULL default `'public'` |
| `contact_visibility` | `text` | `'collaborators_only'` or `'hidden'`, NOT NULL default `'collaborators_only'` |
| `username_last_changed_at` | `timestamptz` | Used for 7-day cooldown enforcement |
| `updated_at` | `timestamptz` | NOT NULL default `now()` |

**New tables:**
- `public.username_history` — one row per username change; owner-only read RLS
- `public.profile_change_log` — audit trail for field changes; owner-only read RLS
- `public.notification_preferences` — `(user_id, channel, category)` PK; owner-all RLS

**Notification channels:** `push`, `email`, `sms`  
**Notification categories:** `trip_invites`, `expense_activity`, `flight_alerts`, `collab_updates`, `marketing_engagement`  
All default `enabled = true` except `marketing_engagement` (GDPR opt-in → defaults `false`).

#### RPCs

**`update_profile(...)`** — `SECURITY DEFINER`, all params optional (default `null`):
- Uses `COALESCE(param, current_value)` — passing `null` leaves the column unchanged
- Username validation: format regex `^[a-zA-Z0-9][a-zA-Z0-9_]{1,28}[a-zA-Z0-9]$`, case-insensitive uniqueness, 7-day cooldown
- On username change: inserts into `username_history` and `profile_change_log` atomically
- The `username_last_changed_at` CASE expression in the UPDATE re-reads the column to detect a true change (avoids resetting the clock when `p_username` matches current value)

**`upsert_notification_preference(p_channel, p_category, p_enabled)`** — single-row upsert on the `(user_id, channel, category)` PK.

**`seed_notification_preferences(p_user_id)`** — called by the `handle_new_user` trigger on signup and once as a backfill for existing users. Uses `ON CONFLICT DO NOTHING` so it is idempotent.

#### Flutter layer

- **Entities:** `lib/features/profile/domain/entities/user_profile.dart` — `UserProfile extends Equatable` with computed `canChangeUsername` (7-day guard) and `nextUsernameChangeAt`
- **Entities:** `lib/features/profile/domain/entities/notification_preference.dart` — `NotifChannel` / `NotifCategory` constant classes + `NotificationPreference entity`
- **Repository interface:** `lib/features/profile/domain/repositories/user_profile_repository.dart`
- **Data layer:** `lib/features/profile/data/` — models, `UserProfileRemoteDataSourceImpl`, `UserProfileRepositoryImpl`
- **Providers:** `lib/features/profile/presentation/providers/user_profile_provider.dart` — `userProfileProvider` (`FutureProvider.autoDispose`), `notificationPreferencesProvider`, `userProfileRepositoryProvider`
- **Edit Profile page:** `lib/features/profile/presentation/pages/edit_profile_page.dart` — `ConsumerStatefulWidget`; sections: Identity (name, username + cooldown warning, bio), Avatar URL, Location, Preferences (SegmentedButton for units), Travel Interests (FilterChip grid); saves auth metadata + profiles table in sequence; invalidates `userProfileProvider` on success
- **Notification Preferences page:** `lib/features/profile/presentation/pages/notification_preferences_page.dart` — matrix UI (rows = categories, columns = channels); optimistic toggle with revert on failure; route `/profile/notifications`
- **Privacy Settings page:** extended with profile-visibility and contact-visibility `SwitchListTile` sections; reads from `userProfileProvider`, writes via `userProfileRepositoryProvider.updateProfile`

#### Key design decisions

- **UUID is the only stable FK.** `username` is mutable — never used as a foreign key anywhere in the schema. All relations use `user_id uuid`.
- **Two-store sync for display_name / avatar_url.** These fields exist in both `auth.users` metadata (drives `AuthAuthenticated.user` in the app) and `public.profiles`. `EditProfilePage._save()` calls `authNotifier.updateProfile()` first (auth metadata), then `userProfileRepository.updateProfile()` (profiles table).
- **Optimistic notification toggles.** `_PrefsBodyState` keeps a local `Map<(String, String), bool> _state`; on failure the RPC result reverts the local state and shows a snackbar.


### Edit Profile Field Pickers (Stage 16 extension)

**Files:**
- `lib/features/profile/presentation/pages/profile_field_data.dart` — offline lookup lists: 190+ countries (ISO 3166-1 alpha-2), 75 timezones (IANA), 48 currencies (ISO 4217), 69 languages (ISO 639-1), 110+ cities with autofill metadata
- `lib/features/profile/presentation/pages/edit_profile_page.dart` — updated

**Changes to `EditProfilePage`:**
- Country, Timezone, Currency, Language fields replaced with `_PickerField` — a tappable `InputDecorator` row that opens a `_LookupSheet` modal bottom sheet
- `_LookupSheet`: `DraggableScrollableSheet` (75% initial, 95% max) with a live-search `TextField` and a `ListView.builder`; search filters by both name and ISO code; current selection highlighted with a checkmark; tapping an entry pops the sheet returning the ISO code
- Clearing: ✕ `IconButton` shown when a value is selected; sets the state var back to `null`
- The four `TextEditingController`s (`_countryCtrl` etc.) were removed; selected codes are held as `String?` state vars (`_country`, `_timezone`, `_currency`, `_language`); `_save()` passes them directly to `updateProfile()`
- City uses `RawAutocomplete<CityEntry>` with 110+ entries in `kCityData`; selecting a suggestion auto-fills Country, Timezone, Currency (always overwrites); free-text city names work normally with no autofill
- Selecting Country auto-fills Currency and Timezone via `kCityData` lookup using `??=` (only fills if the field is still empty)
- Avatar displayed as a 112 px `CircleAvatar` at the top; pencil overlay opens an action sheet (gallery, camera, URL, remove); images uploaded to Supabase Storage `avatars/{userId}/avatar.{ext}` with cache-busted public URL


### Avatar Storage + Profile Upsert Fix (Stage 18)

**Migration:** `docs/supabase_migrations/stage18_avatar_storage_and_profile_upsert.sql`  
Must be run in Supabase SQL editor.

#### What it does

**Avatars storage bucket:**
- Creates `storage.buckets` entry `(id='avatars', public=true)`
- RLS policies on `storage.objects`:
  - `avatars_public_read` — `SELECT` with no auth (avatar URLs are embedded in UI)
  - `avatars_owner_insert` / `_update` / `_delete` — scoped to `authenticated` where `(storage.foldername(name))[1] = auth.uid()::text`, meaning each user can only touch files under their own `{userId}/` prefix

**Backfill missing profile rows:**
- `INSERT INTO public.profiles (id, email, display_name) SELECT ... FROM auth.users WHERE NOT EXISTS (...)` — one-time fix for users who signed up before `handle_new_user` was deployed and have no profile row

**`update_profile` RPC upsert guard:**
- Adds `INSERT INTO public.profiles (id, display_name, email) ... ON CONFLICT (id) DO NOTHING` at the top of the function body, executed before the `UPDATE`
- Root cause of "Profile not found" error: the old RPC ran `UPDATE ... WHERE id = _uid` which silently matched 0 rows when the profile didn't exist; the follow-up `getOwnProfile()` then found 0 rows and threw `ServerException('Profile not found')`
- The upsert guard makes the function self-healing for any user without a profile row

#### Flutter-side error flow (for reference)

```
updateProfile()                          // datasource
  → rpc('update_profile', params)        // runs OK, upserts if needed
  → getOwnProfile()                      // re-fetches the updated profile
    → rows.isEmpty → throws ServerException('Profile not found')   ← fixed by migration
```

