# Kumo — Development Log

**Project:** Kumo — Collaborative Travel Super-App  
**Stack:** Flutter 3.13+ · Dart 3.12+ · Supabase · Riverpod  
**Started:** June 2026

---

## Chapter 1 — Stage 1: Foundation

### 1.1 Vision & Scope

Kumo is a collaborative travel planning app. Users create itineraries, invite co-travellers, split expenses, and eventually get AI-generated itinerary suggestions. The guiding design principle is that a solo traveller can use Kumo alone, and collaboration is additive — not required to derive value.

Stage 1 scope: a working, deployable app where a user can sign up, log in, create trips, view them, and delete them. No collaboration yet — just the individual user owning their own data. This establishes every architectural layer that every future feature will sit on top of.

---

### 1.2 Architecture

#### Clean Architecture with Three Layers

Every feature in Kumo is structured into three layers. The dependency rule flows inward: presentation depends on domain, data depends on domain, and domain depends on nothing outside itself.

```
Presentation  →  Domain  ←  Data
   (UI)       (business)  (network/storage)
```

**Domain layer** (`features/{feature}/domain/`)

The domain layer owns the business logic and has zero framework dependencies. It contains:
- **Entities** — plain Dart objects representing the core data model (e.g., `TravelItinerary`, `User`).
- **Repository interfaces** — abstract contracts defining what data operations are possible, without specifying how.
- **Use cases** — single-responsibility classes, each representing one business operation. A use case calls a repository and may validate or transform data.

This layer is the most stable part of the codebase. Its interfaces and entities rarely change, and they are the foundation every other layer builds on.

**Data layer** (`features/{feature}/data/`)

The data layer implements the domain's repository interfaces. It contains:
- **Models** — extend entities, adding `fromJson`/`toJson` serialisation. The separation means entities never carry serialisation logic.
- **Remote datasources** — concrete Supabase calls.
- **Local datasources** — SharedPreferences for session caching.
- **Repository implementations** — orchestrate remote/local datasources, translate exceptions into typed `Failure` values.

**Presentation layer** (`features/{feature}/presentation/`)

The presentation layer handles everything the user sees. It contains:
- **Pages** — full-screen widgets.
- **Widgets** — reusable UI components scoped to a feature.
- **Providers** — Riverpod `StateNotifier`/`StreamProvider` that mediate between the UI and the domain use cases.

#### Why This Architecture?

The primary reason is **testability**. Each layer can be tested with zero knowledge of the others. Domain use cases are tested with mock repository implementations. Repository implementations are tested with mock datasources. Pages are tested with overridden providers.

The secondary reason is **extensibility**. Stage 2 adds real-time collaboration by wiring a new Supabase Realtime stream into the existing repository interface — no changes to use cases, no changes to the UI except adding `StreamProvider` consumption. Stage 3 adds AI generation as a new datasource implementation behind the same interface. The architecture makes the additions additive, not disruptive.

---

### 1.3 State Management: Riverpod

Riverpod was chosen over BLoC for three reasons:

1. **No boilerplate per operation.** BLoC requires an event class, a state class, and a handler per operation. Riverpod uses plain async methods on a `StateNotifier`.
2. **Compile-time dependency injection.** `ref.watch(someProvider)` is checked at compile time. Providers know their dependencies explicitly.
3. **`AsyncValue` for free.** `StreamProvider` and `FutureProvider` wrap results in `AsyncValue<T>`, which natively represents loading / error / data — no manual state tracking.

Two provider patterns are used in Stage 1:

- **`StateNotifierProvider`** for mutable, operation-driven state (auth state, itinerary list state). The notifier exposes methods (`login`, `createItinerary`, `deleteItinerary`) that the UI calls.
- **`StreamProvider.family`** for reactive, server-pushed state (`itineraryStreamProvider(id)`). The UI subscribes and the data refreshes automatically when Supabase emits a change — the foundation for real-time collaboration in Stage 2.

#### Auth State Machine

Auth is modelled as a sealed class with five states:

```
AuthInitial → AuthLoading → AuthAuthenticated
                          → AuthUnauthenticated
                          → AuthError
                          → AuthPasswordRecovery  (recovery email link clicked)
```

The router watches the auth notifier and redirects accordingly. `AuthPasswordRecovery` is an intentional extra state: when Supabase fires the `passwordRecovery` auth event (user clicked the reset link), the app forces a `/reset-password` route rather than dropping the user at the login screen.

---

### 1.4 Error Handling

Kumo uses a two-tier error system that separates concerns between layers.

**Exceptions** (thrown, caught internally)

`KumoException` is the base class. Subclasses map to specific failure modes:

| Exception | When thrown |
|---|---|
| `NetworkException` | HTTP failure, no connectivity |
| `AuthException` | Supabase auth operation fails |
| `ServerException` | Supabase returns a Postgres/API error |
| `ValidationException` | Domain-level input validation fails |
| `NotFoundException` | Requested resource does not exist |
| `LocalStorageException` | SharedPreferences read/write fails |
| `UnexpectedException` | Catch-all for unexpected errors |

Exceptions are thrown in datasources and repository implementations only. They never cross the domain boundary.

**Failures** (returned via `Either<Failure, T>`)

`Failure` is a sealed class. Repository methods return `Either<Failure, T>` rather than throwing. This means every caller is forced by the type system to handle both the error and success cases.

```dart
result.fold(
  (failure) => state = AuthError(failure.message),
  (user) => state = AuthAuthenticated(user),
);
```

Named factory constructors on each `Failure` subclass (`AuthFailure.invalidCredentials()`, `NetworkFailure.timeout()`) provide consistent, readable error messages across the app without magic strings.

---

### 1.5 Infrastructure

#### Supabase Client (`core/network/supabase_client.dart`)

`KumoSupabaseClient` is a static wrapper around `Supabase.instance`. It is initialised once at app startup in `main.dart` before `runApp`. All features access the database, auth, storage, and realtime through this single point, ensuring credentials are loaded exactly once.

Key design decision: the client reads credentials from `flutter_dotenv` at runtime (`Environment.supabaseUrl`, `Environment.supabaseAnonKey`) rather than baking them in at compile time with `--dart-define`. This means credentials live in `.env` (gitignored) and the build process does not need to know them — important for CI/CD where environment variables can be injected at deploy time.

#### Configuration (`config/environment.dart`, `config/constants.dart`)

`Environment` reads runtime values from dotenv. `AppConstants` holds compile-time constants (pagination sizes, table names, validation limits). These are intentionally separate: constants do not change between environments, environment values do.

#### Routing (`config/router.dart`)

GoRouter is used with a redirect guard that gates every route on auth state:

| Auth state | Behaviour |
|---|---|
| `AuthAuthenticated` on auth route (`/login`, `/signup`, ...) | Redirect to `/home` |
| `AuthUnauthenticated` on protected route | Redirect to `/login` |
| `AuthPasswordRecovery` anywhere | Redirect to `/reset-password` |

The router is rebuilt whenever `authNotifierProvider` state changes, which means navigation is fully reactive to auth transitions — no manual `Navigator.push` calls for auth flows.

Current routes:

| Route | Page | Notes |
|---|---|---|
| `/login` | `LoginPage` | No transition animation |
| `/signup` | `SignupPage` | |
| `/forgot-password` | `PasswordResetPage` | Sends reset email |
| `/reset-password` | `UpdatePasswordPage` | Handles Supabase recovery session |
| `/home` | `HomePage` | No transition animation |
| `/create-trip` | `CreateItineraryPage` | |
| `/trip/:id` | `ItineraryDetailPage` | Real-time via `StreamProvider` |

---

### 1.6 Auth Feature

**What was built:** full email/password authentication including signup, login, logout, password reset via email link, and session persistence across app restarts.

**Entities and models:**
- `User` — domain entity. Holds `id`, `email`, `displayName`, `avatarUrl`, `emailVerified`, `createdAt`, `lastSignInAt`.
- `UserModel extends User` — adds `fromJson`/`toJson` for Supabase serialisation.

**Use cases:**
- `LoginUseCase` — calls `auth.signInWithPassword`, returns `Either<Failure, User>`.
- `SignupUseCase` — calls `auth.signUp` with optional display name metadata, returns `Either<Failure, User>`.
- `LogoutUseCase` — calls `auth.signOut`, clears local cache.

**Datasources:**
- `AuthRemoteDataSourceImpl` — wraps Supabase Auth SDK methods, translates `AuthException` from the Supabase package into the app's own `AuthException`.
- `AuthLocalDataSourceImpl` — caches the current user to SharedPreferences so the home screen can render immediately on cold start before the remote check completes.

**Password reset flow:**
The flow has two halves. The first half (`PasswordResetPage`) sends the email via `auth.resetPasswordForEmail`. The second half is triggered externally — when the user clicks the email link, Supabase redirects them back to the app and fires `AuthChangeEvent.passwordRecovery`. `AuthNotifier` listens to `KumoSupabaseClient.auth.onAuthStateChange` and transitions to `AuthPasswordRecovery`, which the router catches and immediately navigates to `UpdatePasswordPage`. There, `auth.updateUser(password: newPassword)` updates the password against the active recovery session, then signs out and returns to login.

**Session persistence:**
`_checkCurrentUser()` runs on `AuthNotifier` construction. It calls `auth.currentUser` (Supabase SDK) to check for an existing session without a network round-trip on cold start, falling back to the local SharedPreferences cache if offline.

---

### 1.7 Itinerary Feature

**What was built:** create, list, view, and delete itineraries. Real-time stream subscription is wired but unused in the UI until Stage 2.

**Core entity — `TravelItinerary`:**

```
TravelItinerary
├── id, title, description, status (draft|active|completed|archived)
├── ownerId, startDate, endDate, totalBudget, currencyCode
├── members: List<GroupMember>         ← roles: owner|editor|viewer
├── items: List<ItineraryItem>          ← activities, flights, hotels
├── expenseSummary: ExpenseSummary      ← totalSpent, spentByCategory, memberBalances
├── createdAt, updatedAt
```

`members`, `items`, and `expenseSummary` are stored as JSONB columns in Postgres. This sidesteps the need for separate `itinerary_members` and `itinerary_items` join tables at this stage, at the cost of not being able to query individual items or members with SQL filters. This trade-off is intentional: Stage 1 only needs the owner to see their own trips. Stage 2 will assess whether JSONB is sufficient or whether normalised tables are needed for collaborative editing and conflict resolution.

**Database schema (Supabase):**

```sql
public.itineraries (
  id              uuid    PK default gen_random_uuid()
  title           text    NOT NULL
  description     text
  owner_id        uuid    FK → auth.users ON DELETE CASCADE
  start_date      timestamptz
  end_date        timestamptz
  total_budget    numeric(12,2)
  currency_code   text
  members         jsonb   default '[]'
  items           jsonb   default '[]'
  expense_summary jsonb
  status          text    CHECK (draft|active|completed|archived)
  created_at      timestamptz default now()
  updated_at      timestamptz default now()
)
```

Row Level Security is enabled. The `owner full access` policy restricts all operations to the row's `owner_id`. A `members can view` policy allows member reads via a JSONB contains check — ready for Stage 2 invitations without schema migration.

An `updated_at` trigger (`handle_updated_at`) automatically bumps the timestamp on every update, which Supabase Realtime uses to determine change events.

**Use cases:**
- `FetchItinerariesUseCase` — lists all trips owned by a user, ordered by `created_at DESC`.
- `FetchItineraryUseCase` — fetches a single trip by ID.
- `CreateItineraryUseCase` — validates inputs, builds the entity (with the owner as the first member, role `owner`), generates a client-side UUID, and persists via the repository.
- `UpdateItineraryUseCase` — full entity update via Postgres `UPDATE … RETURNING`.
- `DeleteItineraryUseCase` — deletes by ID; RLS ensures users can only delete their own trips.

**Itinerary list state machine:**

```
ItineraryListInitial → ItineraryListLoading → ItineraryListLoaded([])
                                            → ItineraryListLoaded([...trips])
                                            → ItineraryListError
```

Optimistic update on creation: `createItinerary` on the notifier immediately adds the new trip to the loaded list before any round-trip. A silent `softRefresh` runs when returning to the home screen to reconcile with server state without showing a loading spinner.

**Real-time subscription (wired, unused in UI until Stage 2):**

`itineraryStreamProvider` is a `StreamProvider.family<TravelItinerary, String>` backed by `ItineraryRepository.watchItinerary(id)`, which uses Supabase's `.stream(primaryKey: ['id']).eq('id', id)`. The stream emits the current value immediately, then re-emits on any Postgres change. The detail page already consumes this stream — in Stage 2, collaborators editing the same trip will see changes pushed to all viewers without any pull-to-refresh.

**Pages:**
- `HomePage` — shows the list with empty state, navigates to create or detail.
- `CreateItineraryPage` — form: title, description, date range, currency, budget.
- `ItineraryDetailPage` — four sections: overview, budget breakdown, travellers, schedule. Delete with confirmation.

---

### 1.8 Shared Infrastructure

**`core/utils/validators.dart`** — stateless validation methods used by use cases: `validateNonEmpty`, `validateDateRange`, `validateAmount`. Throwing `ValidationException` keeps validation synchronous and in the domain layer.

**`core/utils/formatters.dart`** — display formatting: `formatDate`, `formatCurrency`, `formatDateTime`, `formatDuration`. Used only in the presentation layer. Currency formatting uses `NumberFormat.simpleCurrency` from `intl`, which handles locale-specific symbols correctly.

**`core/utils/logger.dart`** — thin wrapper around the `logger` package with severity levels: `debug`, `info`, `warning`, `error`, `critical`. Structured logging at startup (`Supabase initialized`, `Environment variables loaded`) makes runtime failures diagnosable.

**`shared/widgets/`** — three shared widgets: `LoadingWidget` (centred spinner with optional message), `AppErrorWidget` (error message with retry callback), `AppScaffold` (base scaffold with consistent padding).

**`shared/extensions/context_extensions.dart`** — `BuildContext` extensions: `context.theme`, `context.colorScheme`, `context.textTheme`, `context.screenSize`, `context.showSnackBar(...)`. Eliminates `Theme.of(context)` boilerplate throughout the UI.

---

### 1.9 Known Constraints & Deferred Decisions

**JSONB vs normalised tables for members and items**

Members and itinerary items are stored as JSONB. This is fine while a single owner manages their own data, but becomes a constraint once collaborative editing starts. The risk: two users editing the same `members` array simultaneously would overwrite each other (last-write-wins). Stage 2 will evaluate whether to migrate to a `itinerary_members` join table and a separate `itinerary_items` table, or use Supabase's conflict resolution mechanisms at the application level.

**Client-generated UUIDs**

`CreateItineraryUseCase` generates a UUID client-side via the `uuid` package. The server also has `default gen_random_uuid()` on the `id` column. The client-generated ID takes precedence because the insert explicitly includes it. This avoids an extra round-trip to get the server-assigned ID, but means the client must guarantee UUID uniqueness — a safe assumption with UUID v4.

**No email verification gate**

`verifyEmail` is implemented in the repository and datasource but there is no UI flow for it and no route. Users can log in without verifying their email. This is acceptable for development; a production release should add a "check your email" interstitial after signup.

**`updatePassword` API signature**

`AuthRepository.resetPassword` takes `email` and `token` parameters that the implementation ignores — it calls `auth.updateUser(password: newPassword)` against the active Supabase recovery session. The parameters are vestigial from the original interface design. They should be removed in a cleanup pass before Stage 2 begins.

---

### 1.10 Stage 1 → Stage 2 Bridge Points

The following are the concrete extension points Stage 2 builds directly on top of. Nothing needs to be redesigned — these are already in place.

**Real-time collaboration**

`itineraryStreamProvider(id)` is a live Supabase Realtime subscription. To enable collaborative viewing, Stage 2 needs to:
1. Build an invite flow that inserts a member record into the `members` JSONB array (or a new table).
2. Update the RLS `members can view` policy if the current JSONB-contains approach is insufficient.
3. Add an itinerary items CRUD UI — the `UpdateItineraryUseCase` and datasource method are already implemented.

No new provider or repository method is needed. The stream is already running on the detail page.

**Expense splitting**

`ExpenseSummary` (totalSpent, spentByCategory, memberBalances) is already embedded in every itinerary entity. The expense feature in Stage 4 writes into these fields. The schema supports it today without migration.

**AI generation**

`CreateItineraryUseCase` and `ItineraryRepository.createItinerary` are the entry points. Stage 3 adds an `AiGenerationDataSource` that calls an AI API, formats the response into a `TravelItinerary` entity (with pre-populated `items`), and passes it through the same create use case. No changes to the domain layer.

**Chat**

Chat is feature-independent from itineraries at the domain level. Stage 2 introduces a `chat` feature module with its own entity (`Message`), repository interface, Supabase Realtime datasource, and Riverpod `StreamProvider`. The itinerary entity will gain a `groupId` foreign key that connects it to a chat room.

---

*End of Chapter 1 — Stage 1: Foundation*

---

---

## Chapter 2 — Stage 2: Real-Time Collaboration & Itinerary Editing

### 2.1 Scope

Stage 2 builds the collaborative layer on top of Stage 1's foundation. Three features ship in this stage:

1. **Itinerary items CRUD** — the Schedule section of the detail page was read-only in Stage 1. Stage 2 adds the full add/edit/delete flow for `ItineraryItem` entries.
2. **Member invite flow** — the trip owner can invite any registered Kumo user by email, choosing a role (viewer or editor). The Travellers section in the detail page now shows an Invite button.
3. **Real-time group chat** — every itinerary gets a chat room. Members can send and receive messages in real time. A chat icon in the detail page app bar opens the chat.

---

### 2.2 Pre-Stage-2 Cleanup

`AuthRepository.resetPassword` had vestigial `email` and `token` parameters that the implementation silently ignored — the actual Supabase call only needs the new password (it operates on the active recovery session). All four layers (abstract datasource, concrete datasource, abstract repository, concrete repository) and the `AuthNotifier.updatePassword` call site were updated to use `resetPassword({required String newPassword})`. The docstring now accurately describes the method's behaviour.

---

### 2.3 Database Changes

Two new tables are required in Supabase. The SQL is in `docs/supabase_migrations/stage2_profiles_and_messages.sql`.

**`public.profiles`**

One row per auth user, created automatically via an `after insert on auth.users` trigger (`handle_new_user`). Stores `id` (= `auth.uid()`), `display_name`, `email`, and `avatar_url`. RLS allows any authenticated user to read any profile — this is intentional and necessary for the invite flow (users need to look each other up by email). Only the row owner can update their own profile.

**`public.messages`**

One row per chat message, scoped to an itinerary via `itinerary_id` (FK → `public.itineraries`). Columns: `id`, `itinerary_id`, `sender_id`, `sender_name`, `content`, `created_at`. RLS mirrors the itinerary's access pattern: the itinerary owner has full access; members listed in the JSONB `members` array can select and insert (but not delete). Supabase Realtime is enabled on this table so live message delivery works without polling.

---

### 2.4 Itinerary Items CRUD

**What was built:** `AddEditItemPage` at `/trip/:id/item` (new) and `/trip/:id/item/:itemId` (edit).

**Flow:**
1. User taps "Add" in the Schedule section → navigates to `AddEditItemPage` with no `itemId`.
2. User fills: name (required), type (activity / flight / hotel / restaurant / transport / other), start date+time (required), end date+time (optional), location (optional).
3. On save: the page reads the latest itinerary snapshot from `itineraryStreamProvider(id).value`, splices in the new item sorted by `startTime`, and calls `UpdateItineraryUseCase` directly.
4. The Supabase Realtime stream on the detail page emits the updated row immediately — no manual state management is needed for the UI refresh.

Edit taps the popup menu on any item and navigates to `AddEditItemPage` with the `itemId`. The page watches `itineraryStreamProvider(id)` to find the existing item and pre-populates the form on first load (`_initialized` guard prevents re-population on subsequent stream emissions while the form is open).

Delete is handled directly in `_DetailScaffold._deleteItem` — reads the current itinerary, filters out the item by ID, and calls `UpdateItineraryUseCase`. The stream handles the UI.

**Key decision — no separate item notifier:** Item mutations are performed by calling `updateItineraryUseCaseProvider` directly from the page rather than routing through `ItineraryListNotifier`. The list notifier manages list-level state (create, delete trip); the detail page manages item and member mutations through the use case directly. This keeps the notifier focused and avoids exposing item-level operations on a list-level abstraction.

**New items are sorted by `startTime`** when added. Edits preserve existing order (the map replaces in place).

---

### 2.5 Member Invite Flow

**What was built:** `ProfileRemoteDataSource`, `InviteMemberPage` at `/trip/:id/invite`.

**Infrastructure:** `ProfileRemoteDataSourceImpl` queries `public.profiles` by email (exact match, lowercased). Returns a `ProfileResult` value object (id, displayName, email, avatarUrl) or `null` if not found. The datasource is scoped to the itinerary data layer because it is exclusively used by the invite flow, which is an itinerary operation.

**Flow:**
1. User taps "Invite" in the Travellers section → navigates to `InviteMemberPage`.
2. User enters an email and taps the search button. The page calls `ProfileRemoteDataSource.findByEmail`.
   - Not found: error message shown inline.
   - Already a member: duplicate-check error shown inline.
   - Found: profile card appears with a role picker (Viewer / Editor). Owner role is not available in the invite flow — only the current owner has that role.
3. User taps "Add to Trip": a new `GroupMember` is appended to `itinerary.members`, the updated itinerary is saved via `UpdateItineraryUseCase`, and the page pops with a snackbar confirmation.

**Members can view their own invite entry immediately** because the RLS `members can view` policy on `public.itineraries` was already in place from Stage 1 — it uses a JSONB contains check on `members @> [{"userId": "<uid>"}]`.

---

### 2.6 Chat Feature

**New module:** `lib/features/chat/` with the standard three-layer structure.

**Domain:**
- `Message` entity: `id`, `itineraryId`, `senderId`, `senderName`, `content`, `createdAt`.
- `ChatRepository` interface: `watchMessages(itineraryId)` → `Stream<Either<Failure, List<Message>>>` and `sendMessage(...)` → `Future<Either<Failure, void>>`.
- `SendMessageUseCase`: validates content (non-empty, ≤ 4000 chars), delegates to repository.

**Data:**
- `MessageModel extends Message` with `fromJson`/`toJson`.
- `ChatRemoteDataSourceImpl.watchMessages` uses Supabase's `.stream(primaryKey: ['id']).eq('itinerary_id', id).order('created_at')` — emits the full message list on first subscribe, then re-emits on every insert. Supabase Realtime must be enabled on the `messages` table (see migration).
- `ChatRepositoryImpl` wraps the stream in `Either` and handles errors via `.handleError`.

**Presentation:**
- `chatStreamProvider` is a `StreamProvider.family<List<Message>, String>` backed by the repository stream. Mirrors the pattern of `itineraryStreamProvider`.
- `ChatPage` at `/trip/:id/chat`: scrollable message list with sender grouping (sender name shown only when it changes), chat bubbles (own messages right-aligned in primary colour, others left-aligned in surface colour), timestamp per bubble, and a fixed input bar with a send button. The page derives the trip title from `itineraryStreamProvider` — no title needs to be passed through the route.
- The list auto-scrolls to the bottom when new messages arrive via `ref.listen` on the stream provider.

**Route:** `/trip/:id/chat` is a child route of `/trip/:id` in the GoRouter config (see §2.7). The chat icon appears in the detail page app bar.

---

### 2.7 Routing

All four new pages are child routes of `/trip/:id`, keeping the URL hierarchy consistent with the resource hierarchy:

| Route | Page |
|---|---|
| `/trip/:id/chat` | `ChatPage` |
| `/trip/:id/item` | `AddEditItemPage` (new item) |
| `/trip/:id/item/:itemId` | `AddEditItemPage` (edit existing) |
| `/trip/:id/invite` | `InviteMemberPage` |

Using GoRouter nested routes means path parameters from the parent (`id`) are inherited by all child routes automatically. No extra `extra` passing or query parameters are needed.

---

### 2.8 Known Constraints & Deferred Decisions

**JSONB members array — collaborative edit conflicts**

The invite flow appends to `itinerary.members` via a full-document update. If two owners simultaneously invite different users, the second write wins and the first invite is lost. This is an acceptable trade-off at this stage: inviting is a low-frequency, owner-only operation. Stage 4 can migrate members to a normalised `itinerary_members` table if concurrent invite conflicts become a real problem.

**Itinerary item ordering**

Items are sorted by `startTime` on insert but not re-sorted on edit. A user who edits an item's start time to be earlier than a preceding item will see it out of order until they navigate away and back. Fix: sort items in `UpdateItineraryUseCase` or on read. Deferred.

**Chat — no pagination**

`watchMessages` streams the full message list for an itinerary. For typical trip sizes (tens of messages) this is fine. Long-running group chats (hundreds of messages) will feel slow. Stage 4 can add cursor-based pagination.

**Chat — no push notifications**

Messages arrive in real time only while the app is open. Background delivery requires a push notification service (FCM/APNs via Supabase Edge Functions). Deferred to a later stage.

**`profiles` backfill**

The `handle_new_user` trigger only fires on new signups after the migration runs. Existing users will not have a `profiles` row and will not be findable by email in the invite flow. A one-time backfill query is needed in production:

```sql
insert into public.profiles (id, display_name, email)
select id,
       coalesce(raw_user_meta_data->>'display_name', ''),
       email
from auth.users
on conflict (id) do nothing;
```

---

### 2.9 Stage 2 → Stage 3 Bridge Points

**AI generation entry point unchanged:** `CreateItineraryUseCase` and `ItineraryRepository.createItinerary` remain the entry points. Stage 3 adds an `AiGenerationDataSource` that calls an LLM API, constructs a `TravelItinerary` with pre-populated `items`, and passes it through the existing use case. No domain changes needed.

**Items are now editable:** Stage 3's AI-generated itinerary will arrive with `items` pre-populated. The user can immediately edit, reorder, and delete those items using the Stage 2 CRUD flow.

---

*End of Chapter 2 — Stage 2: Real-Time Collaboration & Itinerary Editing*

---

> Next: **Chapter 3 — Stage 3: AI Itinerary Generation** *(not yet started)*
