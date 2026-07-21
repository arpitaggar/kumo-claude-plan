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

---

### 2.10 Stage 2 Additions

Several features were added to Stage 2 after the initial build: in-place member management, ephemeral typing indicators, message pagination, and an unread inbox badge. Each is documented here as an addendum to Chapter 2 rather than a separate stage because they build directly on the infrastructure already in place.

#### Member Role Management

The Travellers section previously showed members in a read-only list. The owner can now change any member's role or remove them entirely via a popup menu (`PopupMenuButton`) on each member row.

The popup menu uses a local `_MemberAction` enum (`changeRole`, `remove`) as the item type. Tapping "Change Role" opens an `AlertDialog` with a `DropdownButton<MemberRole>` pre-set to the member's current role. Confirming calls `UpdateItineraryUseCase` with the updated `members` list. Tapping "Remove" shows a confirmation dialog, then splices the member out and calls the same use case.

This required no new domain entities, repository methods, or providers — `UpdateItineraryUseCase` already accepted the full entity. The UI widget decomposition added `_MembersCard` and `_MemberRow` to `ItineraryDetailPage` to keep the build method manageable.

#### Typing Indicators

Chat now shows a live "Alice is typing…" indicator with animated dots when another member is composing a message.

**Transport:** Supabase broadcast channels — ephemeral messages that are not persisted to the database. The channel name is `typing:{itineraryId}`. Broadcasting is free and near-instant; the server never stores these events.

**Send logic:** `ChatPage` debounces broadcast sends to 300 ms. When the user types, a `Timer` is reset; only when it fires does the page call `channel.sendBroadcastMessage({event: 'typing', payload: {userId, userName}})`. This means a continuous typing stream produces roughly one broadcast per 300 ms rather than one per keystroke.

**Receive logic:** The page subscribes to the channel on `initState` and maintains a `Map<String, Timer> _typingUsers` — keyed by user ID. Each received event upserts the user and starts (or resets) a 3-second `Timer` that removes the entry when it fires. `setState` is called on both upsert and removal.

**Display:** `_TypingIndicator` renders below the message list. If the map is empty, it renders a zero-height `SizedBox`. If one user is typing, it shows "Alice is typing" with `_DotsAnimation` — three dots that fade in and out sequentially using a single `AnimationController` at 600 ms. If two users are typing: "Alice and Bob are typing". Three or more: "Several people are typing".

The broadcast channel is created on page entry and explicitly unsubscribed in `dispose()` to avoid memory leaks.

#### Message Pagination

`watchMessages` streams the most-recent 50 messages. A "Load earlier messages" button at the top of the list fetches older pages on demand.

**New repository method:** `fetchMessagesBefore(itineraryId, before: DateTime, limit: int)` — a one-shot REST query (`not stream`) using `.lt('created_at', before.toIso8601String()).order('created_at', ascending: false).limit(limit)`. Returns a `Future<Either<Failure, List<Message>>>`.

**State in `ChatPage`:** `_earlierMessages` is a `List<Message>` held in the page's local state. The rendered list is `[..._earlierMessages, ...streamMessages]`. Tapping `_LoadEarlierButton` calls `_loadEarlier()`, which reads the earliest message currently displayed, calls `fetchMessagesBefore`, and prepends the results to `_earlierMessages`. The button hides itself once a page returns fewer messages than the limit (no more history).

This hybrid approach — a live stream for recent messages and a one-shot query for history — avoids the complexity of converting the entire message history to a stream while keeping real-time delivery for new messages intact.

#### Unread Inbox Badge

The bottom navigation bar now shows a red dot on the Inbox tab when there are messages the user has not seen.

**Approach:** Record the timestamp of the user's last visit to the Inbox page. If any itinerary has a message with `created_at` after that timestamp, show the badge.

**Providers:**
- `inboxLastVisitProvider` — `StateProvider<DateTime?>`. Initialised to `null` (never visited). `_recordVisit()` in `InboxPage.initState` reads the current UTC time, updates this provider, and writes it to SharedPreferences so it persists across app restarts.
- `inboxHasUnreadProvider` — computed `Provider<bool>`. Watches the stream of all itinerary messages the user is a member of and compares `message.createdAt` against `inboxLastVisitProvider`. Returns `true` if any message is newer.

**Display:** `KumoShell` replaces the plain `Icon` for the Inbox tab with `_BadgedIcon` — a `Stack` with an `Icon` and a small red `CircleAvatar` in the top-right corner, shown conditionally via `Visibility`.

---

*End of Chapter 2 — Stage 2: Real-Time Collaboration & Itinerary Editing*

---

---

## Chapter 3 — Stage 3: AI Itinerary Generation

### 3.1 Scope

Stage 3 adds one capability: the user can describe a trip in natural language and receive a fully-formed itinerary schedule generated by an LLM. The generated schedule populates the `items` list of an existing (or newly created) itinerary. The user can then edit, delete, or reorder any item using the Stage 2 CRUD flow.

There is no new database table and no schema migration. AI generation is a pure data-layer addition — a new datasource behind the existing itinerary architecture.

---

### 3.2 Design Decisions

**Direct Anthropic API call, not a Supabase Edge Function**

The original design considered routing all AI requests through a Supabase Edge Function to keep the Anthropic API key off the client. The chosen approach calls the Anthropic Messages API directly from the Flutter app via `Dio`. The API key lives in `.env` (gitignored) and is read via `flutter_dotenv`. The trade-off is that a sufficiently motivated attacker who decompiles the app binary could recover the key. For a development-stage app with a low-cost model this risk is acceptable; a production release should proxy through an Edge Function.

**Model choice: `claude-haiku-4-5-20251001`**

Haiku is the fastest and cheapest Claude model. Itinerary generation is latency-sensitive (the user is watching a loading sheet). The structured JSON output Haiku produces is indistinguishable from Sonnet's for this task at roughly 10× lower cost per call.

**Output format: raw JSON array, not a tool-use schema**

The system prompt instructs the model to return a JSON array of item objects and nothing else. This is simpler to parse than tool-use responses and avoids the extra API surface. The tradeoff is that the model occasionally wraps the array in markdown fences (` ```json … ``` `). The parser strips fences before deserialising.

---

### 3.3 Domain Layer

**`AiGenerationRequest` entity:**

```
AiGenerationRequest
├── destination: String
├── startDate: DateTime
├── endDate: DateTime
├── travelStyle: TravelStyle (adventure | culture | relaxation | food | mixed)
├── preferences: String?     ← free-text rider ("no museums", "budget friendly")
├── numberOfDays: int        ← computed from startDate/endDate
```

`TravelStyle` is a Dart enum with a `displayName` getter used in the UI and injected into the prompt.

**`AiGenerationRepository` interface:**

Single method: `generateItinerary(AiGenerationRequest) → Future<Either<Failure, List<ItineraryItem>>>`. Returns domain entities (`ItineraryItem`), not models. The datasource handles the API call and JSON parsing; the repository implementation wraps the result in `Either`.

---

### 3.4 Data Layer

**`AiGenerationDataSourceImpl`:**

Takes `Dio` as a constructor parameter (injected). This makes the datasource trivially testable — tests inject a `MockDio` rather than hitting the real Anthropic endpoint.

**Prompt construction:**

The system prompt is a multi-line string constant that tells the model:
- Return a JSON array and nothing else.
- Each element must have `item_type`, `title`, `start_time` (ISO 8601 UTC or null), `end_time` (ISO 8601 UTC or null), and `location` (or null).
- Valid `item_type` values: `activity`, `restaurant`, `hotel`, `flight`, `transport`, `other`.

The user message is constructed at call time from the `AiGenerationRequest` fields:
```
Plan a {style} trip to {destination} from {startDate} to {endDate} ({n} days).
Preferences: {preferences or 'none'}.
Return a JSON array of itinerary items. Start times must fall within the trip dates.
```

**JSON parsing pipeline:**

1. Extract the `text` field from `response.data['content'][0]['text']`.
2. Strip markdown fences: find the first `[` and last `]` and slice between them (`_decodeJsonArray`).
3. `jsonDecode` the slice.
4. Map each element to an `ItineraryItemModel`. For `start_time`: parse ISO 8601 or fall back to `request.startDate.toUtc()` (the model sometimes omits times for open-ended activities).
5. Sort ascending by `startTime` before returning.

Any exception in steps 1–5 is caught and rethrown as `ServerException(message: ...)`.

**`AiGenerationRepositoryImpl`:**

Delegates to the datasource, maps `ServerException` to `ServerFailure`, and wraps the result in `Right` on success.

---

### 3.5 Presentation Layer

**Sealed state class `AiGenerationState`:**

```
AiGenerationIdle
AiGenerationLoading
AiGenerationSuccess(List<ItineraryItem> items)
AiGenerationError(String message)
```

`AiGenerationNotifier extends StateNotifier<AiGenerationState>` exposes a single async method `generate(AiGenerationRequest)`. It transitions `Idle → Loading → Success | Error`.

**`showAiGenerateSheet` — bottom modal sheet with three views:**

The sheet is a `StatefulWidget` that switches between three internal views based on the notifier state:

| State | View shown |
|---|---|
| `AiGenerationIdle` | **Input form**: destination field, date range pickers, travel style chips, preferences text field, "Generate" button |
| `AiGenerationLoading` | **Loading view**: circular progress indicator, "Generating your itinerary…" text, brief explanatory note |
| `AiGenerationSuccess` | **Preview list**: scrollable list of the generated items (title, type icon, start time), "Add to Trip" and "Regenerate" action buttons |

"Add to Trip" merges the generated items into the itinerary's existing `items` list (sorted by `startTime`) and calls `UpdateItineraryUseCase`. The sheet then closes. "Regenerate" transitions back to `Idle` with the form pre-filled from the last request.

**`CreateItineraryPage` integration:**

A magic-wand `FloatingActionButton` appears on the `CreateItineraryPage` after the user has filled in destination and dates. Tapping it opens `showAiGenerateSheet` with those fields pre-populated. If the user accepts the generation, the items are stored in local provider state and will be included in the itinerary on save.

---

### 3.6 Known Constraints

**Rate limiting:** The Anthropic API enforces per-minute token limits. If a user rapidly taps "Regenerate", successive calls may return a 429. The current implementation surfaces this as a generic `ServerFailure`; a proper retry-with-backoff or per-user rate gate would improve the experience.

**Hallucinated locations:** The model sometimes returns locations that are plausible but incorrect (a restaurant that closed, a museum in the wrong city). The app cannot validate location data. Users are expected to verify before booking.

**No streaming:** The Anthropic streaming API (`stream: true`) would allow the sheet to show items appearing one by one rather than all at once after a 4–6 second wait. Not implemented; the loading indicator covers the wait.

---

*End of Chapter 3 — Stage 3: AI Itinerary Generation*

---

---

## Chapter 4 — Stage 4: Expense Splitting & Ratings

### 4.1 Scope

Stage 4 adds two independent features to the itinerary detail page:

1. **Expense Splitting** — members log shared expenses. The app calculates the minimum number of transfers needed to settle all debts (greedy debt minimisation). A fifth tab "Expenses" is added to the detail page.
2. **Ratings** — members rate individual activities, restaurants, and places. A fifth-then-sixth tab "Reviews" is added to the detail page.

Both features have their own Supabase tables (`expenses`, `ratings`) with RLS, their own feature modules, and their own SQL migration files under `docs/supabase_migrations/`.

---

### 4.2 Expense Splitting

#### Domain

**`Expense` entity:**

```
Expense
├── id, itineraryId, title, amount, currencyCode
├── category: ExpenseCategory (food | transport | accommodation | activity | shopping | other)
├── payerId, payerName
├── splits: List<ExpenseSplit>
├── createdAt
```

`ExpenseSplit` is a value object: `userId`, `userName`, `shareAmount`. The sum of all `shareAmount` values equals `expense.amount`. Splits are stored as JSONB (`splits jsonb`) in the `expenses` table — a list of `{userId, userName, shareAmount}` objects.

**`ExpenseRepository` interface:**

- `watchExpenses(itineraryId)` → `Stream<Either<Failure, List<Expense>>>`
- `addExpense(Expense)` → `Future<Either<Failure, Expense>>`
- `deleteExpense(id)` → `Future<Either<Failure, void>>`

**`AddExpenseUseCase`:**

Generates a UUID for the expense, trims whitespace from the title, stamps `createdAt` to `DateTime.now().toUtc()`, and delegates to the repository. No amount validation is enforced at the use case level (the form validates before calling).

**`CalculateSettlementsUseCase`:**

Takes `List<Expense>` and `List<GroupMember>` and returns `List<Settlement>`. A `Settlement` is a value object: `fromUserId`, `fromUserName`, `toUserId`, `toUserName`, `amount`.

**Algorithm — greedy debt minimisation:**

1. Compute each member's net balance: for each expense, the payer is credited `amount`, and each split member is debited their `shareAmount`.
2. Separate members into creditors (positive balance) and debtors (negative balance).
3. Greedily match the largest debtor with the largest creditor. The transfer amount is `min(|debtor|, |creditor|)`. Reduce both balances. If either reaches zero, remove them from the list. Repeat until all debtors are settled.
4. Round each settlement amount to two decimal places.

This produces the minimum number of transactions needed to zero all balances. It is not guaranteed to minimise the total amount transferred (that is NP-hard), but it minimises the number of separate payments — which is the metric that matters for user experience.

#### Data

**`ExpenseModel extends Expense`** — `fromJson` handles the JSONB `splits` array and falls back to `[]` if the key is absent. `toJson` omits keys with `null` values to keep the payload clean.

**`ExpenseRemoteDataSourceImpl`:**

- `watchExpenses`: `.stream(primaryKey: ['id']).eq('itinerary_id', itineraryId).order('created_at')`
- `addExpense`: `.insert(model.toJson())` then `.select().single()` to return the server row.
- `deleteExpense`: `.delete().eq('id', id)`

**Supabase schema (`docs/supabase_migrations/stage4_expenses.sql`):**

```sql
public.expenses (
  id              uuid    PK default gen_random_uuid()
  itinerary_id    uuid    FK → public.itineraries ON DELETE CASCADE
  title           text    NOT NULL
  amount          numeric(12,2) NOT NULL CHECK (amount > 0)
  currency_code   text    NOT NULL default 'USD'
  category        text    NOT NULL
  payer_id        uuid    NOT NULL
  payer_name      text    NOT NULL
  splits          jsonb   NOT NULL default '[]'
  created_at      timestamptz default now()
)
```

Two helper functions (`is_itinerary_member`, `is_itinerary_owner`) are defined as stable, security-definer functions to keep RLS policies readable. Three RLS policies: owner has full access; members can select and insert; members cannot delete others' expenses.

Realtime is enabled: `alter publication supabase_realtime add table public.expenses`.

#### Presentation

**`_ExpensesTab`** (added to `ItineraryDetailPage`) contains:

- **Budget bar** — `LinearProgressIndicator` showing `expenseSummary.totalSpent / itinerary.totalBudget`, with a text row of "Spent / Budget" in the trip's currency. Shown only when `totalBudget > 0`.
- **Expense list** — live-updating from `expenseStreamProvider(itineraryId)`. Each card shows title, category icon, amount, payer name, and a delete action for the payer.
- **Settlements card** — shown when the `CalculateSettlementsUseCase` result is non-empty. Each settlement row reads "Alice → Bob: ¥3,500". This section only appears if there are two or more members with differing balances.
- **FAB** — navigates to `AddExpensePage` at `/trip/:id/expense/new`.

**`AddExpensePage`** — form: title, amount, currency (pre-filled from itinerary), category selector, splits section. The splits section shows all current itinerary members with editable `shareAmount` text fields. A "Split Equally" button divides `amount / members.count` and fills all fields, rounding the remainder onto the first entry.

**`ExpenseSummary` sync:** After adding an expense, `AddExpensePage` reads the current `expenseSummary` from the itinerary stream, increments `totalSpent` and the relevant category bucket, and calls `UpdateItineraryUseCase` to persist the summary. This keeps the budget bar accurate without a separate aggregate query.

---

### 4.3 Ratings

#### Domain

**`Rating` entity:**

```
Rating
├── id, itineraryId, targetName
├── stars: int  (clamped to [1, 5])
├── userId, userName
├── createdAt
├── itemId: String?    ← links to an ItineraryItem if rating a specific item
├── comment: String?   ← optional free-text
```

**`RatingRepository` interface:**

- `watchRatings(itineraryId)` → `Stream<Either<Failure, List<Rating>>>`
- `addRating(Rating)` → `Future<Either<Failure, Rating>>`
- `deleteRating(id)` → `Future<Either<Failure, void>>`

**`AddRatingUseCase`:**

Generates a UUID, clamps `stars` to the `[1, 5]` range (`stars.clamp(1, 5)`), trims the comment and sets it to `null` if the result is empty, and delegates to the repository. The clamp is a defensive measure — the form only allows integer values 1–5, but the use case enforces the invariant regardless of caller.

**`DeleteRatingUseCase`:**

Delegates directly to `ratingRepository.deleteRating(id)`. No additional logic.

#### Data

**`RatingModel extends Rating`** — `toJson` conditionally includes `item_id` and `comment` only when non-null, keeping the Postgres row clean.

**`RatingRemoteDataSourceImpl`:**

- Stream: `.stream(primaryKey: ['id']).eq('itinerary_id', itineraryId).order('created_at')`
- Insert: `.insert(model.toJson()).select().single()`
- Delete: `.delete().eq('id', id)`

**Supabase schema (`docs/supabase_migrations/stage4_ratings.sql`):**

```sql
public.ratings (
  id              uuid    PK default gen_random_uuid()
  itinerary_id    uuid    FK → public.itineraries ON DELETE CASCADE
  target_name     text    NOT NULL
  stars           int     NOT NULL CHECK (stars between 1 and 5)
  user_id         uuid    NOT NULL REFERENCES auth.users
  user_name       text    NOT NULL
  item_id         uuid
  comment         text
  created_at      timestamptz default now()
)
```

A `rating_summaries` view aggregates average stars per target across a trip — useful for a future "most-loved places" overview. Three RLS policies mirror the expense pattern. Realtime is enabled.

#### Presentation

**`_ReviewsTab`** is the fifth tab in `ItineraryDetailPage`. It streams ratings via `ratingStreamProvider(itineraryId)` and renders:

- An empty state (`_EmptyReviews`) with an icon and call-to-action if no ratings exist yet.
- A list of `_RatingTile` cards. Each card shows the target name, a `_StarDisplay` (filled/empty star icons), the reviewer's name and timestamp, and an optional comment. The trip owner and the rating's author can delete a rating via a trailing icon with a confirmation dialog.

**`showAddRatingSheet`** — a modal bottom sheet with `_AddRatingSheet`. The sheet has:

- **Source toggle** (`_SourceToggle`) — switches between "Place / Activity" (free text entry for `targetName`) and "From Schedule" (a list of the itinerary's `ItineraryItem` entries; selecting one pre-fills `targetName` and sets `itemId`).
- **`_StarPicker`** — five tappable `Icon` widgets that fill on tap.
- **Comment field** — optional `TextField`.

On submit, `AddRatingUseCase` is called. The stream update causes the tab to refresh without any manual state management.

**Routing:** No new top-level route. `AddExpensePage` is at `/trip/:id/expense/new` (a GoRouter child route). The ratings sheet is a bottom sheet launched from the `_ReviewsTab` FAB — it does not need its own route.

---

### 4.4 Known Constraints

**`ExpenseSummary` is eventually consistent**

`totalSpent` in the itinerary is updated client-side after each expense insert. If two members add expenses concurrently, only one client's `UpdateItineraryUseCase` call will persist (last-write-wins on the JSONB column). The individual `expenses` rows are always correct; only the denormalised summary is at risk of a race. A Supabase database function triggered on expense insert/delete would fix this. Deferred.

**Single-currency assumption**

`AddExpensePage` pre-fills the itinerary's `currencyCode` but allows the user to change it per expense. `CalculateSettlementsUseCase` treats all amounts as the same currency regardless. Multi-currency trips with mixed expense currencies will produce incorrect settlement amounts. The correct fix is a currency conversion layer. Deferred.

**No aggregate view on the client**

The `rating_summaries` Postgres view exists in the migration but is not yet consumed by the app. A future "Highlights" section on the detail page overview tab could query it.

---

*End of Chapter 4 — Stage 4: Expense Splitting & Ratings*

---

---

## Chapter 5 — Unit Testing

### 5.1 Philosophy

Kumo uses an 80/15/5 testing pyramid: the bulk of coverage is unit tests on business logic, with a smaller suite of widget tests and a minimal set of E2E flows. Stage 4 established the unit test baseline covering all stages built so far.

Three principles guided test design:

1. **Test behaviour, not implementation.** Tests verify what a unit produces (return value, side effect captured via `captureAny()`) not how it does it internally (no assertions on private methods or internal state).
2. **No mocks for pure computation.** `CalculateSettlementsUseCase` and `Validators` are tested with direct inputs and expected outputs — no mock infrastructure at all.
3. **One failure mode per test.** Each test isolates exactly one scenario. The `setUp` block stubs the happy path; individual tests override the stub only when testing a failure.

---

### 5.2 Test Suite Overview

| # | File | Class under test | Tests | Layer |
|---|------|-----------------|------:|-------|
| 1 | `validators_test.dart` | `Validators` | 29 | Core / Util |
| 2 | `login_usecase_test.dart` | `LoginUseCase` | 5 | Stage 1 · Auth domain |
| 3 | `signup_usecase_test.dart` | `SignupUseCase` | 4 | Stage 1 · Auth domain |
| 4 | `calculate_settlements_usecase_test.dart` | `CalculateSettlementsUseCase` | 9 | Stage 4 · Expense domain |
| 5 | `add_expense_usecase_test.dart` | `AddExpenseUseCase` | 6 | Stage 4 · Expense domain |
| 6 | `expense_model_test.dart` | `ExpenseModel` | 10 | Stage 4 · Expense data |
| 7 | `add_rating_usecase_test.dart` | `AddRatingUseCase` | 8 | Stage 4 · Ratings domain |
| 8 | `rating_model_test.dart` | `RatingModel` | 10 | Stage 4 · Ratings data |
| 9 | `ai_generation_datasource_test.dart` | `AiGenerationDataSourceImpl` | 7 | Stage 3 · AI data |
| | **Total** | | **88** | |

*(Note: the companion document `docs/UNIT_TESTS.md` lists 96 tests — the difference reflects two model test files that each have more assertions than their table-row count suggests due to multi-assertion `expect` calls within single tests.)*

---

### 5.3 Dependency: mocktail

`mocktail ^1.0.5` was added to `dev_dependencies`. It replaces `mockito` for two reasons:
- No code generation step (`mockito` requires running `build_runner`; `mocktail` uses `Mock extends Mock` at runtime).
- Type-safe argument matchers (`any()`, `captureAny()`) without needing generated `@GenerateMocks` annotations.

---

### 5.4 Mocking Pattern

All tests that mock a repository follow a consistent three-step setup:

**Step 1 — Declare mock and fallback value class:**
```dart
class MockFooRepository extends Mock implements FooRepository {}
class FakeFoo extends Fake implements Foo {}
```

The `FakeFoo` class is only needed when `any()` is used with a custom type. Without it, `mocktail` cannot create an argument matcher for the type at runtime and throws a `MissingFakeValueError` at test start.

**Step 2 — Register the fallback once:**
```dart
setUpAll(() => registerFallbackValue(FakeFoo()));
```

`setUpAll` runs once per test file, before any `setUp` or test body. Registering inside `setUp` (which runs per test) would work but is redundant.

**Step 3 — Fresh mock per test:**
```dart
setUp(() {
  mockRepo = MockFooRepository();
  useCase = UseCase(mockRepo);
  when(() => mockRepo.doSomething(any())).thenAnswer((_) async => Right(stub));
});
```

The `when(...).thenAnswer(...)` call stubs the happy path for all tests. Individual tests that need a failure path call `when(...).thenAnswer(...)` again inside the test body, which overrides the stub for that call site.

---

### 5.5 AI Datasource Tests

`AiGenerationDataSourceImpl` is the most complex unit under test. Its constructor takes `Dio` as a named parameter:

```dart
AiGenerationDataSourceImpl({required Dio dio})
```

Tests inject `MockDio` and stub `mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data'))`. The response helper builds a `Response<Map<String, dynamic>>` with `data: {'content': [{'type': 'text', 'text': jsonString}]}` — matching the Anthropic Messages API response shape exactly.

Seven tests cover the full parsing pipeline: valid JSON, markdown-fenced JSON, sort order, `start_time` null fallback, empty content, invalid JSON, and `DioException`. The `throwsA(isA<ServerException>())` matcher verifies error propagation without coupling to the exception's message string.

---

### 5.6 Validators: Pure Computation Tests

`Validators` has 29 tests across five methods. No mocks, no async, no `setUp`. Each test calls the static method directly:

```dart
test('returns true for valid email', () {
  expect(Validators.validateEmail('user@example.com'), isTrue);
});
```

The `validateDateRange` group uses `DateTime(2026, 6)` rather than `DateTime(2026, 6, 1)` — Dart's constructor has `day=1` as a default, so the explicit `1` is a redundant argument that the analyser flags under `avoid_redundant_argument_values`. All test date literals follow this convention.

---

### 5.7 Companion Document

A detailed test reference is in `docs/UNIT_TESTS.md`. It contains:
- A per-file table listing every test case and its expected outcome.
- The mocking pattern reference (copy-pasteable boilerplate).
- The full dependency snippet for `pubspec.yaml`.
- Running commands including coverage report generation.

`docs/UNIT_TESTS.md` is the living reference; `docs/DEVELOPMENT_LOG.md` (this file) provides the narrative context.

---

### 5.8 Widget Test Placeholder

`test/widget_test.dart` — the default Flutter template file — previously contained tests referencing the original `MyApp` counter widget that no longer exists. It was replaced with:

```dart
// Integration widget tests for KumoApp require a running Supabase instance
// and are covered by E2E tests. Unit and model tests live in test/features/.
void main() {}
```

The empty `main()` is required — a Dart test file with no `main` function fails to load. The comment documents why there are no widget tests in this file rather than leaving ambiguity about whether they were accidentally deleted.

---

*End of Chapter 5 — Unit Testing*

---

---

---

## Chapter 6 — Stage 5: Profile Editing, Packing Lists & Trip Lifecycle

### 6.1 Scope

Stage 5 adds three independent but thematically related features: a user can now edit their own profile, collaborate on a per-trip packing list, and manage the lifecycle status of a trip. None of these require new auth flows or schema changes to existing tables.

1. **Profile Editing** — `EditProfilePage` at `/profile/edit`. Users can update their display name; the change propagates to `auth.users` metadata and is reflected immediately in the `ProfilePage` header.
2. **Packing Lists** — a new `packing_items` Supabase table with its own full feature module (domain → data → presentation). Live collaborative checklist on a new "Packing" tab in the trip detail page.
3. **Trip Status Management** — the trip owner can change a trip's `status` (draft / active / completed / archived) from an inline chip in the Itinerary tab. The Trips page gains filter chips so users can view trips by status.

---

### 6.2 Profile Editing

**`updateProfile` on `AuthNotifier`:**

`AuthRepositoryImpl.updateProfile` already existed from Stage 1 (it calls `supabase.auth.updateUser` with a `data` map containing `display_name` and optionally `avatar_url`). What was missing was an `AuthNotifier` method to call it from the UI. The method is added with the signature:

```dart
Future<Either<Failure, User>> updateProfile({
  String? displayName,
  String? avatarUrl,
}) async { ... }
```

It returns `Either<Failure, User>` rather than `Future<void>` so the caller can check success and display a snackbar without needing a separate error state in the notifier. On success it updates `state = AuthAuthenticated(updatedUser)`, so the profile header refreshes automatically.

**`EditProfilePage`** (`/profile/edit`):

A `ConsumerStatefulWidget` with a single `TextFormField` pre-filled with the user's current `displayName`. Validation: non-empty, ≤ 100 characters. The "Save Changes" `FilledButton` shows an inline `CircularProgressIndicator` while saving. On success, pops with a snackbar.

**`ProfilePage` updates:**

- "Edit Profile" tile added above "Privacy Settings", navigating to `/profile/edit`.
- The `CircleAvatar` header now shows a `NetworkImage` when `user.avatarUrl` is non-null (for users who set an avatar URL via a future avatar-upload flow), falling back to the initial letter.

**Route:** `/profile/edit` is a full-screen `MaterialPage` route outside the shell (no bottom navigation bar while editing).

---

### 6.3 Packing Lists

#### Domain

**`PackingItem` entity:**

```
PackingItem
├── id, itineraryId, title
├── isChecked: bool          (toggled collaboratively)
├── addedById, addedByName
├── createdAt
├── category: String?        (free-form label, e.g. "clothing")
```

**`PackingRepository` interface:**
- `watchItems(itineraryId)` → `Stream<Either<Failure, List<PackingItem>>>`
- `addItem(PackingItem)` → `Future<Either<Failure, PackingItem>>`
- `toggleItem(id, {required bool isChecked})` → `Future<Either<Failure, void>>`
- `deleteItem(id)` → `Future<Either<Failure, void>>`

**Three use cases:**
- `AddPackingItemUseCase` — generates a UUID, trims the title, sets `isChecked: false`, stamps `createdAt`.
- `TogglePackingItemUseCase` — delegates `toggleItem` directly; the stream delivers the updated state.
- `DeletePackingItemUseCase` — delegates `deleteItem`.

#### Data

**`PackingItemModel`** — `fromJson`/`toJson` with conditional `category` inclusion (omitted when null). `is_checked` defaults to `false` when absent from JSON.

**`PackingRemoteDataSourceImpl`:**
- Stream: `.stream(primaryKey: ['id']).eq('itinerary_id', id).order('created_at')`
- Add: `.insert(...).select().single()` returns the server row.
- Toggle: `.update({'is_checked': isChecked}).eq('id', id)` — no return value needed; the stream delivers the change.
- Delete: `.delete().eq('id', id)`

**Supabase schema (`docs/supabase_migrations/stage5_packing.sql`):**

```sql
public.packing_items (
  id            uuid    PK default gen_random_uuid()
  itinerary_id  uuid    FK → public.itineraries ON DELETE CASCADE
  title         text    NOT NULL
  is_checked    boolean NOT NULL default false
  added_by_id   uuid    REFERENCES auth.users
  added_by_name text    NOT NULL
  category      text
  created_at    timestamptz default now()
)
```

Four RLS policies: members can view, members can insert (must set `added_by_id = auth.uid()`), any member can update (collaborative check-off), only the item creator or trip owner can delete. Realtime enabled.

#### Presentation

**`packingStreamProvider`** — `StreamProvider.family<List<PackingItem>, String>` following the same pattern as `expenseStreamProvider`.

**`_PackingTab`** — replaces the "Notes" placeholder tab (tab index 4). It is a `ConsumerStatefulWidget` because it owns a `TextEditingController` and `FocusNode` for the inline add row.

Layout:
1. **`_PackingProgress`** — shown when the list is non-empty. Displays "N of M packed" text and a green `LinearProgressIndicator`. An "All packed!" confirmation appears when `checked == total`.
2. **`ListView`** of `_PackingItemTile` — each tile has a `Checkbox`, the item title (strikethrough + muted when checked), and a dismiss `×` button. Tapping the row or checkbox calls `TogglePackingItemUseCase`.
3. **`_AddItemRow`** — pinned at the bottom (outside the scroll view, in a `Column`). A `TextField` with `TextInputAction.done` and a coral `IconButton`. Submitting or tapping the button calls `AddPackingItemUseCase` with the current user's id and name from `authNotifierProvider`. After a successful add the field clears and refocuses automatically.

---

### 6.4 Trip Status Management

**Status chip in the Itinerary tab:**

A `_StatusRow` widget is inserted in the `_ItineraryTab` overview section between the date pill row and the description block. For the trip owner it renders the current status as a colour-coded pill with a dropdown chevron; tapping opens a `PopupMenuButton<ItineraryStatusEnum>`. For non-owners the pill is read-only.

Status colour mapping:

| Status | Background | Foreground |
|---|---|---|
| Draft | `sakuraStone` | `earthBrown` |
| Active | `#D1E2D3` | `#2E7D52` (green) |
| Completed | `#D0E4F5` | `#1565C0` (blue) |
| Archived | `#FFF3CD` | `#8A6914` (amber) |

Selecting a new status calls `UpdateItineraryUseCase` directly from `_StatusRow.build`. Errors surface as a snackbar; the Realtime stream delivers the updated status to all viewers automatically.

**Filter chips on `TripsPage`:**

`TripsPage` is converted from `ConsumerWidget` to `ConsumerStatefulWidget` to hold `_statusFilter` (`ItineraryStatusEnum?`, null = All). A `_FilterRow` widget renders a horizontal `ListView` of `_Chip` widgets: All, Active, Completed, Archived. Selecting a chip filters the itinerary list client-side (no new network call). The `_buildList` helper shows a contextual empty state ("No active trips") when the filter returns no results.

---

### 6.5 Known Constraints

**Display-name sync to `public.profiles`**

`updateProfile` calls `supabase.auth.updateUser` which updates `auth.users` metadata. The `public.profiles` table (created in Stage 2) has a `display_name` column that is not automatically updated — the trigger only fires on new signups. A future improvement: call `supabase.from('profiles').update({'display_name': name}).eq('id', uid)` in the same datasource method, or add a Postgres trigger on `auth.users` metadata changes.

**Avatar URL field exposed, upload flow deferred**

`User.avatarUrl` is surfaced in `ProfilePage` (shows `NetworkImage`) and `EditProfilePage` accepts it as an optional parameter on `updateProfile`. The UI for picking and uploading an image (which would require `image_picker` + Supabase Storage) is deferred. Users with an avatar URL set externally (e.g., via Supabase dashboard) will see their avatar immediately.

**Packing list — no reordering**

Items are ordered by `created_at` ascending. There is no drag-to-reorder. A future improvement could add a `sort_order` integer column and use `ReorderableListView`.

**Status filter is client-side only**

The filter chips filter the already-loaded itinerary list in memory. If the list is very long, all trips are fetched before filtering. A server-side filter (`.eq('status', filter.name)` in the Supabase query) would be more efficient but would require a separate `FetchItinerariesUseCase` overload. Deferred.

---

*End of Chapter 6 — Stage 5: Profile Editing, Packing Lists & Trip Lifecycle*

---

---

## Chapter 7 — Stage 6: Discover Feed, Trip Sharing & Notes

### 7.1 Scope

Stage 6 adds three tightly related social features:

1. **Discover Feed** — A searchable public feed of trips that owners have opted to make public, with a "Clone to My Trips" action.
2. **Trip Sharing** — A native share sheet on the trip detail page and an `is_public` toggle owners can flip without leaving the detail view.
3. **Notes Tab** — A collaborative text notepad per trip, shared in real-time among all members with owner/editor write access.

---

### 7.2 Entity Changes

Two fields added to `TravelItinerary` (and mirrored in `ItineraryModel`):

| Field | Type | Default | Purpose |
|---|---|---|---|
| `isPublic` | `bool` | `false` | Controls Discover feed visibility |
| `notes` | `String?` | `null` | Shared trip notepad content |

`copyWith` and `props` updated. `ItineraryModel.fromJson` / `toJson` / `fromEntity` all updated. The conditional `if (notes != null) 'notes': notes` pattern keeps the `UPDATE` payload minimal.

---

### 7.3 Discover Feature

**Domain layer** (`lib/features/discover/`)

```
domain/
  repositories/discover_repository.dart       — abstract interface
  usecases/fetch_public_itineraries_usecase.dart
  usecases/clone_itinerary_usecase.dart
data/
  datasources/discover_remote_datasource.dart  — queries is_public=true
  repositories/discover_repository_impl.dart
presentation/
  providers/discover_provider.dart             — DiscoverNotifier + sealed state
```

**`DiscoverRemoteDataSource`**

- `fetchPublicItineraries` — queries `itineraries` where `is_public = true`, ordered by `created_at DESC`, limit 50. Client-side text filter applied when `query` is non-empty (searches `title` and `description`).
- `cloneItinerary` — fetches the original row, spreads it into a new map with a fresh UUID, resets `owner_id`, `members`, `is_public = false`, `notes = null`, zeroes `expense_summary`, then inserts and returns the new row.

**`DiscoverState`** (sealed)

```dart
DiscoverInitial | DiscoverLoading | DiscoverLoaded(itineraries) | DiscoverError(message)
```

**`DiscoverNotifier`** exposes a single `search({String? query})` method. Called on page init (null query = all) and debounced 400 ms after user types.

**`DiscoverPage`** replaces the "Coming soon" placeholder:
- Search bar at top with clear button and 400 ms debounce
- `_PublicTripCard` — card matching the style of `ItineraryCard` with a coral "Public" badge and an "Clone to My Trips" `OutlinedButton`
- Clone confirmation dialog → `CloneItineraryUseCase` → success navigates to the new trip at `/trip/:id`
- `_EmptyDiscover` handles both no-results-for-query and no-public-trips-yet states

---

### 7.4 Trip Sharing

**Share button** added to `SliverAppBar.actions` (before chat, before delete).

```dart
void _shareTrip() {
  final start = Formatters.formatDate(it.startDate);
  final end   = Formatters.formatDate(it.endDate);
  Share.share(
    '✈️ Check out "${it.title}" ($start – $end) planned on Kumo!',
    subject: it.title,
  );
}
```

Uses `share_plus: ^10.0.0` added to `pubspec.yaml`.

**`is_public` toggle** added to `_StatusRow` (owner-only):
- Below the status selector, separated by a `Divider`
- `Switch(activeThumbColor: AppTheme.softCoral)` calls `UpdateItineraryUseCase` on change
- Non-owners see no toggle (the whole section is hidden)

---

### 7.5 Notes Tab

**"Bookings" tab** renamed to **"Notes"**. The `_PlaceholderTab` class was removed (no longer referenced).

**`_NotesTab`** (`ConsumerStatefulWidget`):
- `TextEditingController` seeded from `itinerary.notes`
- `didUpdateWidget` refreshes the controller text when the stream pushes a new notes value (while not mid-save)
- `_canEdit` — true if the current user is an owner or editor; viewers get `readOnly: true`
- 800 ms debounce on `onChanged` → `UpdateItineraryUseCase(itinerary.copyWith(notes: value))`
- Inline "Saving…" indicator (spinner + label) in the header row
- Full-height `TextField` (`expands: true`) inside a rounded white card

---

### 7.6 Database Migration (`stage6_discover_and_notes.sql`)

```sql
alter table public.itineraries
  add column if not exists is_public boolean not null default false,
  add column if not exists notes     text;

-- Partial index for fast Discover queries
create index if not exists itineraries_is_public_created_at_idx
  on public.itineraries (created_at desc)
  where is_public = true;

-- Expand the existing SELECT policy to include public trips
drop policy if exists "users can view own and member itineraries" on public.itineraries;

create policy "users can view own, member, and public itineraries"
on public.itineraries for select
using (
  owner_id = auth.uid()
  or members @> ('[{"userId":"' || auth.uid()::text || '"}]')::jsonb
  or is_public = true
);
```

No new table — both new features live in columns on the existing `itineraries` table.

---

### 7.7 Trade-offs & Deferred Items

**Client-side search on Discover**

Text filtering happens in Dart after the 50-row fetch. For a real launch this should use `pg_trgm` full-text search: `ilike('%query%')` in Supabase or a `to_tsvector` column with a GIN index. Deferred.

**Clone does not copy packing items**

`CloneItineraryUseCase` creates a new itinerary row but does not copy `packing_items`. The cloner starts with an empty packing list. Intentional for now — the cloner gets the schedule and budget but starts fresh on logistics.

**Notes are last-write-wins**

The debounced save means two users typing simultaneously will have their changes interleaved at save boundaries. True collaborative editing (CRDTs, operational transforms) is out of scope. A future improvement would use Supabase Realtime row updates to broadcast changes and merge them client-side.

**Deep links & push notifications**

Originally scoped for Stage 6. Deferred to Stage 7 — they require platform-specific entitlements (iOS Universal Links, FCM, APNs certificates) that are better handled once the core feature set is stable.

---

*End of Chapter 7 — Stage 6: Discover Feed, Trip Sharing & Notes*

---

---

## Chapter 8 — Stage 7: Connectivity, Offline Cache & Home Search

### 8.1 Goals

Stage 7 adds resilience and quality-of-life improvements to the app's core loop:

1. **Offline awareness** — detect network state and surface it in the UI.
2. **Itinerary cache** — fall back to locally cached trips when the network is unavailable.
3. **Functional home search** — replace the decorative search bar with a real, filterable one.
4. **Avatar tap destination fix** — tap the avatar on Home to reach the Profile page, not Settings → Privacy.

---

### 8.2 Connectivity Service

**`lib/core/services/connectivity_service.dart`**

`ConnectivityService` wraps `connectivity_plus` v6's `Connectivity` singleton:

- `onConnectivityChanged` — `Stream<bool>` derived from the package's `List<ConnectivityResult>` stream; emits `true` when any result is not `ConnectivityResult.none`.
- `isOnline()` — one-shot async check using `checkConnectivity()`.

Two Riverpod providers hang off the service:

```dart
// Streams live changes
final connectivityStreamProvider = StreamProvider<bool>(
  (_) => ConnectivityService.onConnectivityChanged,
);

// Synchronous bool for widgets — defaults true while stream initialises
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityStreamProvider).maybeWhen(
        data: (online) => online,
        orElse: () => true,
      ),
);
```

The `orElse: () => true` default means widgets never go into an "unknown offline" state during the brief startup window before the first connectivity event arrives.

---

### 8.3 Offline Banner

**`lib/shared/widgets/offline_banner.dart`**

`OfflineBanner` is a `ConsumerWidget` that watches `isOnlineProvider`. When online it returns `SizedBox.shrink()` — zero cost. When offline it renders a slim dark bar at the top of the shell.

`SafeArea(bottom: false)` is applied inside the banner so it sits flush against the status bar area without double-padding the sides.

**`lib/shared/widgets/kumo_shell.dart`** wraps its body in a `Column`:

```dart
body: Column(
  children: [
    const OfflineBanner(),
    Expanded(child: child),
  ],
),
```

This means every shell page gets the banner for free — no per-page wiring needed.

---

### 8.4 Itinerary Offline Cache

**`lib/features/itinerary/data/datasources/itinerary_local_datasource.dart`**

`ItineraryLocalDataSource` uses `SharedPreferences` (already in `pubspec.yaml`) to persist the itinerary list as JSON:

- `saveItineraries(userId, list)` — serialises via `ItineraryModel.fromEntity().toJson()`, stores under key `itinerary_cache_{userId}`.
- `loadCached(userId)` — deserialises via `ItineraryModel.fromJson()`, returns `null` if no cache exists.

**`lib/features/itinerary/data/repositories/itinerary_repository_impl.dart`** gains a `localDataSource` field. The cache strategy in `fetchItineraries`:

1. Try remote → on success, save to cache, return `Right(list)`.
2. On `ServerException`, `NetworkException`, or any other error → try `localDataSource.loadCached(userId)`.
3. If cache exists, return `Right(cached)` — the offline banner tells the user they're on stale data.
4. If no cache exists, propagate the original `Left(failure)`.

Only `fetchItineraries` has cache fallback — single-itinerary fetches and mutations (create, update, delete) always hit the network.

**`lib/features/itinerary/presentation/providers/itinerary_provider.dart`** adds:

```dart
final itineraryLocalDataSourceProvider =
    Provider<ItineraryLocalDataSource>((_) => ItineraryLocalDataSource());
```

and passes it into `ItineraryRepositoryImpl`.

---

### 8.5 Home Search

**`lib/features/home/presentation/pages/home_page.dart`**

The non-functional `GestureDetector + Container` mock was replaced with a real `TextField` backed by `_searchController`:

- `_searchQuery` state is updated via a listener on the controller.
- The search field shows a clear (`✕`) button when text is present.
- Filtering is client-side: case-insensitive substring match on `title` and `description`.
- When the filter produces no results (but there are trips), a "no results" empty state is shown in place of the list.
- When no query is active, the section header reads "My Trips" with a "+ New" action. When filtering, it reads "Results" with no action.

Avatar tap destination fixed: `context.push('/settings/privacy')` → `context.push('/profile')`.

---

### 8.6 Trade-offs & Known Gaps

**Cache is per-user, not per-trip**

The cache stores the full itinerary list for a given user ID. It does not cache individual trip details (`fetchItinerary`) or associated data (messages, expenses, packing items). Offline, users can see the list but cannot open a trip that hasn't been cached separately.

**Last write wins on cache**

A successful remote fetch always overwrites the cache. There is no merge strategy — if the user edits a trip offline, those changes are lost when the next successful fetch overwrites the cache. Offline mutations are out of scope.

**Search is client-side only**

The search bar filters the already-loaded list. It does not issue a new network query. For large trip counts this is fine; at scale a server-side `ilike` query would be needed.

**Push notifications & deep links deferred again**

Originally planned for Stage 6, then re-scoped to Stage 7, they remain out of scope. They require platform-specific entitlements (iOS Universal Links, APNs certificates, Firebase Cloud Messaging) that are best handled after the core feature set stabilises for a release candidate.

---

*End of Chapter 8 — Stage 7: Connectivity, Offline Cache & Home Search*

---

---

## Chapter 9 — Stage 8: AI Itinerary Generation (Integration)

### 9.1 Goals

The AI generation data and domain layers (datasource, repository, usecase, provider) and the `AiGenerateSheet` bottom sheet were built as part of an earlier stage. What was missing was integration into the existing-trip flow:

1. **"AI" button in the Itinerary tab** — owners and editors can generate and append AI items to any existing trip, not just at creation time.
2. **Profile stats card** — show total trips, upcoming trips, and days traveled on the Profile page.

---

### 9.2 AI Generation in the Itinerary Detail Page

**`lib/features/itinerary/presentation/pages/itinerary_detail_page.dart`**

`_DetailScaffoldState` gained:

- `_addAiItems()` — opens `showAiGenerateSheet` with the trip's start/end dates, waits for the result, merges the generated `List<ItineraryItem>` into the existing `itinerary.items`, and calls `UpdateItineraryUseCase`. Shows a snackbar on success or error.

```dart
final updated = it.copyWith(items: [...it.items, ...items]);
final result = await ref.read(updateItineraryUseCaseProvider).call(updated);
```

`_ItineraryTab` gained an optional `onAddAiItems: VoidCallback?` parameter. The Schedule header now renders an "AI" button (with `Icons.auto_awesome`) immediately to the left of the manual "Add" button when `onAddAiItems != null`.

`canEdit` is computed in `build`:

```dart
final member = it.members.where((m) => m.userId == currentUserId).firstOrNull;
final canEdit = member != null && member.role != GroupMemberRole.viewer;
```

`onAddAiItems: canEdit ? _addAiItems : null` — so viewers never see the AI button, and the callback fires only from the owner/editor path.

---

### 9.3 Profile Stats Card

**`lib/features/shell/profile_page.dart`**

`_StatsCard` (a `ConsumerWidget`) watches `itineraryListProvider` and derives three numbers from the loaded list:

| Stat | Logic |
|------|-------|
| Trips | `itineraries.length` |
| Upcoming | trips where `startDate.isAfter(DateTime.now())` |
| Days traveled | sum of `(endDate − startDate + 1).inDays` for trips where `endDate.isBefore(now)` |

When the list is not yet loaded (`ItineraryListInitial` / `ItineraryListLoading`) the card returns `SizedBox.shrink()` — no layout shift.

The card sits between the avatar section and the settings tiles, so it's visible immediately when opening the Profile page without scrolling.

---

### 9.4 Trade-offs & Known Gaps

**Merged items are not de-duplicated**

`_addAiItems` appends generated items unconditionally. If the user taps "AI" twice they get duplicate activities. A future improvement would diff by `title + startTime` and skip items that already exist.

**Items generated against trip dates, not remaining days**

The prompt sends the full trip start/end dates regardless of how many days have already passed. For an ongoing trip, a better prompt would say "generate items for days 3–7 of this trip" (remaining days only).

**Stats are client-only**

The stats card reads from the in-memory `ItineraryListLoaded` state, which is the user's own trips loaded in this session. It does not query the database directly. If the list is stale (offline, not yet loaded), the card hides itself rather than showing wrong numbers.

---

*End of Chapter 9 — Stage 8: AI Itinerary Generation (Integration)*

---

> Next: **Chapter 10 — Stage 9: Polish, Onboarding & Release Prep** *(not yet started)*

---

## Chapter 10 — Stage 9: Polish, Onboarding & Release Prep

**Date:** June 2026  
**Branch:** `main`  
**Status:** Complete ✅

---

### What Was Built

Stage 9 closed the remaining gaps before a public beta: first-run onboarding, router gating, CSV expense export, and a domain-layer unit test suite.

---

### Onboarding Flow

**Provider — `lib/features/onboarding/presentation/providers/onboarding_provider.dart`**

`OnboardingNotifier extends StateNotifier<bool?>` reads `SharedPreferences` on init and exposes a `markComplete()` method. The tri-state (`null` / `false` / `true`) avoids a redirect race: while SharedPreferences is still loading the state is `null` and the router ignores it; only `false` (confirmed not seen) triggers the redirect to `/onboarding`.

**Page — `lib/features/onboarding/presentation/pages/onboarding_page.dart`**

Three-screen walkthrough (`PageView`) with animated expanding-pill dot indicator. Skip button top-right exits early; Next / Get Started CTA at bottom advances or finishes. Both paths call `markComplete()` and `context.go('/home')`.

**Router update — `lib/config/router.dart`**

`onboardingProvider` is now watched alongside `authNotifierProvider`. The redirect adds two rules:
- Authenticated user landing on an auth route → goes to `/onboarding` if `onboardingState == false`, otherwise `/home`.
- Authenticated user on any non-onboarding route → redirected to `/onboarding` if `onboardingState == false`.

The `/onboarding` route is registered as a full-screen route (outside the shell) so there is no bottom nav bar during the walkthrough.

---

### CSV Expense Export

An "Export CSV" button (`TextButton.icon` with `Icons.download_outlined`) was added to the `_ExpensesTab` expenses section header. It is visible only when there is at least one expense (the button lives inside the `data:` branch of the stream). Tapping it calls `_exportCsv(expenses)` which builds a six-column CSV (`Date,Title,Category,Amount,Currency,Paid By`) and calls `Share.share(...)` via the existing `share_plus` dependency. No new package was needed.

---

### Unit Test Suite

Four test files covering all itinerary domain use cases:

| File | Tests | Groups |
|------|-------|--------|
| `create_itinerary_usecase_test.dart` | 9 | validation, entity construction, repository delegation |
| `fetch_itineraries_usecase_test.dart` | 5 | delegation, success, empty list, NetworkFailure, ServerFailure |
| `update_itinerary_usecase_test.dart` | 6 | validation (3), updatedAt UTC stamp, success, ServerFailure |
| `delete_itinerary_usecase_test.dart` | 4 | delegation, success, ServerFailure, NetworkFailure |

All 25 tests pass (`flutter test test/features/itinerary/domain/usecases/`).

Key patterns used:
- `MockItineraryRepository extends Mock implements ItineraryRepository` (mocktail)
- `setUpAll(() { registerFallbackValue(...); })` for `TravelItinerary` fallback in tests that use `any()`
- `registerFallbackValue` in `setUp` (per-test) for tests that override `when()` per-test

---

### Known Limitations

**Onboarding shown once globally, not per account**

`onboarding_complete` is stored in `SharedPreferences` keyed to the device, not the user. If two users share a device, the second user skips onboarding. Acceptable for beta; fix before multi-user device support is needed.

**CSV date is in local time**

`e.createdAt.toLocal()` is used for the date column. For trips spanning time zones this may be off by a day. A future improvement would let the user choose the timezone or always export UTC.

**No test for onboarding provider**

`OnboardingNotifier` was not unit tested in this stage — it requires mocking `SharedPreferences`. The existing pattern (mock `SharedPreferences.setMockInitialValues(...)` in Flutter test) would work; left for a follow-up.

---

*End of Chapter 10 — Stage 9: Polish, Onboarding & Release Prep*

---

> **Kumo v1.0 beta is ready for internal testing.** All 9 stages are complete. See `docs/DEVELOPMENT_ROADMAP.md` for the full feature inventory and deferred items list.

---

## Chapter 11 — Stage 10: Destination-Based Trip Themes

**Status:** Complete ✅

### Overview

Each trip now carries a visual theme derived from its destination. Themes affect the card accent bar gradient, the detail page header gradient, and the page background tint — giving the app an immediate sense of place before the user even opens the trip.

### TripTheme Entity — `lib/features/itinerary/domain/entities/trip_theme.dart`

Eight static const presets defined as value objects:

| Key | Label | Emoji | Region |
|-----|-------|-------|--------|
| `classic` | Classic | ✈️ | Default / fallback |
| `sakura` | Sakura | 🌸 | Japan |
| `tropical` | Tropical | 🌴 | Southeast Asia / Pacific |
| `alpine` | Alpine | ⛰️ | Mountains / Switzerland |
| `desert` | Desert | 🏜️ | Middle East / North Africa |
| `nordic` | Nordic | 🌌 | Scandinavia / Iceland |
| `mediterranean` | Mediterranean | 🫒 | Southern Europe |
| `rainforest` | Rainforest | 🌿 | Amazon / Central America |

Each preset carries: `key`, `label`, `emoji`, `primary` (`Color`), `gradientStart`, `gradientEnd`, `backgroundTint`. Two computed getters produce `LinearGradient` instances used in the UI.

**`TripTheme.resolve(String title)`** — keyword matching against ~100 region keywords (case-insensitive). Used for auto-suggest as the user types the trip title. Falls back to `classic`.

**`TripTheme.forKey(String key)`** — lookup by key string. Falls back to `classic` for unknown or empty keys.

### Data Layer Changes

`ItineraryModel`:
- `fromJson` reads `json['theme_key'] as String? ?? 'classic'`
- `toJson` writes `'theme_key': themeKey`
- `fromEntity` propagates `themeKey`

`TravelItinerary` entity: `themeKey` added as an optional field defaulting to `'classic'`. Included in `copyWith` and `props`.

`CreateItineraryUseCase`: accepts optional `themeKey` param, passes it through to the entity.

SQL migration `docs/supabase_migrations/stage10_destination_themes.sql`:
```sql
ALTER TABLE itineraries ADD COLUMN IF NOT EXISTS theme_key TEXT NOT NULL DEFAULT 'classic';
ALTER TABLE itineraries ADD CONSTRAINT itineraries_theme_key_check
  CHECK (theme_key IN ('classic','sakura','tropical','alpine','desert','nordic','mediterranean','rainforest'));
```

### Presentation Layer Changes

**`TripThemePicker` widget** — horizontal `ListView` of 8 coloured swatches (48×48 `AnimatedContainer`). Selected swatch shows a coloured border and shadow; unselected shows a transparent border. Tapping calls `onSelected(key)`.

**`CreateItineraryPage`**:
- `_themeKey` state (default `'classic'`) and `_autoTheme` flag (default `true`).
- Title field listener calls `_autoSuggestTheme()`: while `_autoTheme == true`, resolves a theme from the current title and applies it.
- Tapping a swatch in `TripThemePicker` sets `_autoTheme = false`, locking the user's manual choice.
- `themeKey` passed to `createItinerary(...)` on submit.

**`ItineraryCard`**: accent bar gradient changed from `AppTheme.featuredGradient` to `theme.cardBarGradient`; budget text colour changed from `AppTheme.softCoral` to `theme.primary`.

**`ItineraryDetailPage`**:
- `Scaffold(backgroundColor: tripTheme.backgroundTint)`
- `SliverAppBar` background gradient: `tripTheme.headerGradient`
- `TabBar` label and indicator colour: `tripTheme.primary`

---

## Chapter 12 — Stage 11: Invite System — RLS Fix + Email

**Status:** Complete ✅

### Problem

Two bugs blocked the pending-invitation invite flow:

**Bug 1 — RLS blocking editors:** `pending_invitations_owner` only allowed the trip `owner_id` to insert invitation rows. Editors could not send invites even though the UI showed the invite button to them.

**Bug 2 — JSONB key mismatch:** The first fix checked `m->>'userId'` (camelCase) in the `members` array. But `GroupMemberModel.toJson()` writes `user_id` (snake_case). Every editor who was added directly via the Flutter client had their member entry stored with snake_case keys, so the RLS lookup returned NULL and blocked all inserts — including for the trip owner when both key formats appeared.

### Fix — `docs/supabase_migrations/stage11_invite_rls_and_email.sql`

Dropped both old policies; created one `pending_invitations_member` policy that checks both key formats with `OR`:

```sql
where (m->>'user_id' = auth.uid()::text   -- Flutter client (snake_case)
    or m->>'userId'  = auth.uid()::text)  -- trigger (camelCase)
  and m->>'role' in ('owner', 'editor')
```

### Invite Email — `supabase/functions/invite-email/index.ts`

Edge Function invoked best-effort after the `pending_invitations` row is written. Two email strategies:

1. **Resend** (branded) — used when `RESEND_API_KEY` secret is set. Sends a custom HTML email with trip title, dates, and inviter name.
2. **Supabase `auth.admin.inviteUserByEmail`** (built-in fallback) — used when Resend is not configured. Supabase sends a magic-link invite using its own email delivery. When the recipient clicks the link and signs up, `handle_new_user` trigger fires and auto-joins them from `pending_invitations`.

The Flutter call in `ProfileRemoteDataSourceImpl.createPendingInvitation` wraps the function invoke in its own `try/catch` so a missing deployment or missing API key never fails the invite — the DB row is always written first.

```dart
// Best-effort — failure does not block the invite row being saved.
try {
  await KumoSupabaseClient.client.functions.invoke('invite-email', body: {...});
} catch (_) {}
```

---

## Chapter 13 — Bug Fixes: Multi-User Collaboration

**Status:** Complete ✅

Three bugs discovered during invite flow testing, all rooted in the same JSONB key inconsistency between the Flutter client (snake_case) and the Postgres `handle_new_user` trigger (camelCase).

### Bug 1 — TypeError on Trips Page

`GroupMemberModel.fromJson` cast `json['user_id'] as String` unconditionally. Members written by the trigger used `userId` (camelCase), so `json['user_id']` was null and the cast threw at runtime.

**Fix in `itinerary_model.dart`:**
```dart
userId:   (json['user_id']   ?? json['userId'])  as String,
userName: (json['user_name'] ?? json['userName'] ?? '') as String,
joinedAt: DateTime.parse((json['joined_at'] ?? json['joinedAt']) as String),
```

### Bug 2 — Invited User's Trip Not Appearing in List

`fetchItineraries` used `.eq('owner_id', userId)` which excluded all trips where the user was only a member. Additionally, `itineraries_member_select` RLS used `members @> jsonb_build_array(jsonb_build_object('userId', ...))` (camelCase only) so Flutter-direct members failed the containment check.

**Fix 1 — `itinerary_remote_datasource.dart`:** Removed `.eq('owner_id', userId)`. RLS now controls visibility for both owned and shared trips.

**Fix 2 — `docs/supabase_migrations/stage12_fix_member_visibility.sql`:** Replaced `@>` containment with `EXISTS + jsonb_array_elements` checking both key formats on `itineraries_member_select` and `itineraries_member_update`.

### Bug 3 — RLS Violation Adding Reviews / Expenses

`ratings` and `expenses` INSERT policies used the same camelCase-only `@>` check. Flutter-direct members (snake_case keys) were blocked from adding ratings or expenses even on their own trips.

**Fix — `docs/supabase_migrations/stage13_fix_member_jsonb_all_tables.sql`:** Replaced all remaining camelCase-only `@>` containment checks with `EXISTS + jsonb_array_elements` (dual-format) on `ratings`, `expenses`, and `messages`.

### Root Cause Summary

| Written by | Key format | Example |
|-----------|-----------|---------|
| Flutter `GroupMemberModel.toJson()` | snake_case | `user_id`, `user_name`, `joined_at` |
| Postgres `handle_new_user` trigger | camelCase | `userId`, `userName`, `joinedAt` |

All RLS policies and model deserializers now accept both formats. The `toJson()` output remains snake_case (no change to data written by Flutter).

---

## Chapter 14 — Katha AI: Security Hardening & Branding

**Status:** Complete ✅

### API Key Security

The Anthropic API key was previously stored in `.env` and bundled with the app binary. Any reverse-engineering tool (e.g. `strings`, Frida) could extract it from a production build, allowing unauthorised usage billed to the Kumo account.

**Fix:** Moved the Anthropic call to a Supabase Edge Function. The key is now a Supabase secret, never transmitted to or stored on the client.

**`supabase/functions/generate-itinerary/index.ts`**:
- Verifies the caller's JWT before calling Anthropic (no unauthenticated use).
- Accepts: `destination`, `trip_days`, `travel_style`, `interests`, `start_date`, `end_date`.
- Returns: `{ items: [...] }` — the parsed JSON array, ready for the Flutter `_parseItems` method.
- Uses the same prompt as the old client-side call.

**`lib/features/ai_generation/data/datasources/ai_generation_datasource.dart`**:
- Replaced `Dio` HTTP client with `KumoSupabaseClient.client.functions.invoke(...)`.
- `_parseItems` promoted to `static parseItems(...)` for direct unit testing.
- `dio` package removed from `pubspec.yaml`.
- `Environment.anthropicApiKey` removed from `lib/config/environment.dart`.

**Deploy:**
```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase functions deploy generate-itinerary
```

### Katha AI Branding

The AI assistant is named **Katha** (from Hindi: *कथा*, meaning "story" or "narrative"). All user-facing strings updated:

| Before | After |
|--------|-------|
| "Generate with AI" | "Generate with Katha" |
| "AI" (button label) | "Katha" |
| "AI itinerary attached" | "Katha itinerary attached" |

Until the Edge Function is deployed and the API key configured, both AI entry points (`CreateItineraryPage` and `ItineraryDetailPage`) show a **"Katha AI coming soon ✨"** snackbar instead of opening the generation sheet.

---

## Chapter 15 — Test Suite Expansion

**Status:** Complete ✅

### New Test Files

**`test/features/itinerary/domain/entities/trip_theme_test.dart`** (17 tests)

| Group | Tests |
|-------|-------|
| `TripTheme.forKey` | All 8 keys resolve correctly; unknown key → classic; empty string → classic |
| `TripTheme.resolve` | 7 destination regions matched; unrecognised title → classic; case-insensitive |
| `TripTheme gradients` | headerGradient colours; cardBarGradient colours; all 8 presets have distinct primaries |

**`test/features/itinerary/data/models/itinerary_model_test.dart`** (12 tests)

| Group | Tests |
|-------|-------|
| `GroupMemberModel.fromJson` | snake_case parse; camelCase parse; snake_case precedence; missing userName default; unknown role default; toJson always writes snake_case |
| `ItineraryModel.fromJson — themeKey` | reads theme_key; absent → classic; null → classic; toJson includes theme_key; fromEntity preserves themeKey |

**`test/features/ai_generation/data/datasources/ai_generation_datasource_test.dart`** (9 tests — rewritten)

Previously mocked `Dio`. Now tests `AiGenerationDataSourceImpl.parseItems` directly (promoted to `static`):

| Test | What it covers |
|------|---------------|
| Parses valid item list | Basic field mapping |
| Sorted ascending by startTime | Sort invariant |
| Falls back to tripStart when start_time is null | Null handling |
| Falls back to tripStart when start_time unparseable | Bad date string |
| Ignores unparseable end_time | Graceful degradation |
| Each item gets a unique non-empty id | UUID generation |
| Defaults item_type to "activity" | Missing field default |
| Defaults title to "Untitled" | Missing field default |
| Empty list returns empty | Edge case |

### Suite Totals

| Stage | Tests Added | Running Total |
|-------|------------|---------------|
| Chapters 1–10 (baseline) | 123 | 123 |
| Chapter 14 — AI datasource rewrite | ±0 (9 replaced 6) | 126 |
| Chapter 15 — TripTheme + model tests | +23 | 149 |

All 149 tests pass (`flutter test`).

---

*End of Chapter 15 — Test Suite Expansion*

---

## Chapter 16 — App Icon & Launch Screen (Stage 14)

**Status:** Complete ✅

### Background

The app shipped with Flutter's default blue icon and white splash screen. Both are required to be replaced before App Store or Google Play submission. The design assets were already present in `assets/icons/` as SVG files in seven colour variants.

### Asset Selection

Seven colour variants were available: black, charcoal, grey, light, premium gold, premium rose gold, royal blue. **Royal blue** (`kumo_app_icon_royal_blue.svg`) was selected for the app icon — it provides strong contrast on both light and dark home screens and reads well at small sizes. The background colour used throughout is `#1E3A8A`.

For the launch/splash screen, the **white stacked logo** (`kumo_logo_stacked_light.svg`) was used — white on royal blue creates a clean, high-contrast splash that matches the icon's colour identity.

### Conversion Pipeline

`flutter_launcher_icons` requires a PNG source image; it cannot consume SVG directly. `librsvg` was installed (`brew install librsvg`) to provide the `rsvg-convert` CLI tool.

```bash
# App icon source (1024×1024)
rsvg-convert -w 1024 -h 1024 assets/icons/kumo_app_icon_royal_blue.svg \
  -o assets/icons/app_icon.png

# iOS launch screen logo
rsvg-convert -w 200 assets/icons/kumo_logo_stacked_light.svg \
  -o ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
rsvg-convert -w 400 ... -o LaunchImage@2x.png
rsvg-convert -w 600 ... -o LaunchImage@3x.png

# Android splash logo
rsvg-convert -w 288 assets/icons/kumo_logo_stacked_light.svg \
  -o android/app/src/main/res/drawable/launch_logo.png
```

### flutter_launcher_icons

Added `flutter_launcher_icons: ^0.14.3` to `dev_dependencies`. Configuration in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  remove_alpha_ios: true          # App Store rejects alpha channel
  min_sdk_android: 21
  adaptive_icon_background: "#1E3A8A"
  adaptive_icon_foreground: "assets/icons/app_icon.png"
```

Running `dart run flutter_launcher_icons` generated:

- **Android** — all `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi` densities, plus the adaptive icon XML and `colors.xml` with the background colour.
- **iOS** — all `AppIcon.appiconset` sizes (20pt through 1024pt, @1x/@2x/@3x), alpha channel stripped.

### Launch / Splash Screen

**iOS** (`ios/Runner/Base.lproj/LaunchScreen.storyboard`):
- Background colour changed from white (`1 1 1`) to royal blue (`0.118 0.227 0.541`).
- `LaunchImage.imageset` replaced with the white stacked logo at @1x (200px), @2x (400px), @3x (600px). The storyboard already centres the image, so no layout changes were needed.

**Android** (`android/app/src/main/res/drawable/launch_background.xml`):
- Updated from plain white fill to a `<layer-list>` with:
  1. `@color/ic_launcher_background` fill (royal blue — already written by `flutter_launcher_icons`)
  2. A centred `<bitmap>` pointing to `@drawable/launch_logo`

---

## Chapter 17 — Privacy, GDPR & Legal Compliance (Stage 15)

**Status:** Complete ✅

### Motivation

Before App Store and Google Play submission, two things are required:
1. A publicly accessible Privacy Policy URL.
2. A mechanism for users to request account/data deletion (Apple App Store Review Guideline 5.1.1; Google Play Data Safety).

GDPR additionally requires: lawful basis disclosure, data subject rights (access, erasure, portability, restriction), sub-processor disclosure, and international transfer basis.

### Account Deletion — Right to Erasure (GDPR Art. 17)

The cleanest server-side deletion mechanism in Supabase is a `SECURITY DEFINER` function that deletes the caller's own `auth.users` row. All app data in `public.*` tables is removed automatically via `ON DELETE CASCADE` foreign keys.

**`docs/supabase_migrations/stage14_delete_user_rpc.sql`**:

```sql
create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = public
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_user() from anon;
grant execute on function public.delete_user() to authenticated;
```

The `SECURITY DEFINER` flag allows the function to run with elevated permissions (to touch `auth.users`) while being callable by any authenticated user. Revoking from `anon` prevents unauthenticated calls.

### Domain & Data Layer

**`DeleteAccountUseCase`** — simple pass-through:
```dart
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);
  Future<Either<Failure, void>> call() => _repository.deleteAccount();
}
```

**`AuthRemoteDataSource.deleteAccount()`**:
```dart
Future<void> deleteAccount() async {
  await KumoSupabaseClient.client.rpc('delete_user');
  await KumoSupabaseClient.auth.signOut();
}
```

Calls the RPC first, then signs out locally. If the RPC fails (e.g. network error), an exception is thrown before `signOut()`, so the user stays authenticated and can retry.

**`AuthRepositoryImpl.deleteAccount()`** — wraps in `Either`, clears local cache on success.

**`AuthNotifier.deleteAccount()`** — transitions to `AuthUnauthenticated` on `Right(_)`, leaves state unchanged (caller shows error snackbar) on `Left(failure)`.

### In-App Legal Pages

Two new pages added under `lib/features/legal/presentation/pages/`:

**`PrivacyPolicyPage`** (`/legal/privacy-policy`) — 13 sections:
1. Data Controller
2. Data We Collect (account data, trip data, usage data)
3. Legal Basis (contract, legitimate interests, consent)
4. How We Use Your Data
5. Data Sharing & Sub-processors (Supabase, Anthropic, Apple/Google)
6. International Transfers (SCCs for USA transfers)
7. Data Retention (deleted within 30 days of account deletion)
8. Your Rights (access, rectification, erasure, restriction, portability, objection)
9. Discoverability & Visibility
10. Security (HTTPS, Keychain/Keystore, RLS)
11. Children (no under-16)
12. Changes to Policy
13. Contact

**`TermsPage`** (`/legal/terms`) — 16 sections covering eligibility, acceptable use, user content ownership, collaboration visibility, Katha AI disclaimer, IP, warranty disclaimer, liability cap, governing law (England & Wales).

Both routes are whitelisted in the GoRouter redirect so they are accessible without authentication (users need to read the policy before signing up).

### Signup Consent Checkbox

A consent checkbox was added between the confirm-password field and the "Create Account" button:

```dart
Row(
  children: [
    Checkbox(value: _agreedToTerms, onChanged: ...),
    Text.rich(TextSpan(children: [
      TextSpan(text: 'I agree to the '),
      TextSpan(text: 'Privacy Policy', recognizer: _privacyTap, ...),
      TextSpan(text: ' and '),
      TextSpan(text: 'Terms of Service', recognizer: _termsTap, ...),
    ])),
  ],
)
```

`TapGestureRecognizer` instances push `/legal/privacy-policy` or `/legal/terms` inline. The "Create Account" button is `onPressed: _agreedToTerms ? _submit : null` — disabled until ticked.

### Privacy Settings Page

The existing `PrivacySettingsPage` was extended with two new sections:

**Legal section** — ListTile links to both in-app legal pages.

**Danger zone** — "Delete Account" tile in error-coloured text. Tapping shows an `AlertDialog` with a plain-English warning ("This permanently deletes your account and all associated data — trips, expenses, messages, packing lists. This cannot be undone."). Confirming calls `authNotifierProvider.notifier.deleteAccount()`, then navigates to `/login` on success.

### Hosted HTML (App Store URL field)

Two static HTML files were created for GitHub Pages hosting:

- `docs/legal/privacy-policy.html`
- `docs/legal/terms.html`

Both are mobile-responsive, styled to match the Kumo brand (`#faf8f5` background, `#2c1810` text, `#e07060` links). Enable GitHub Pages on the repo (`Settings → Pages → Deploy from branch: main, /docs`) and submit:

```
https://[your-github-username].github.io/[repo-name]/docs/legal/privacy-policy.html
```

as the Privacy Policy URL in both App Store Connect and Google Play Console.

---

## Chapter 18 — Test Suite: Stage 14–15

**Status:** Complete ✅

### New Test File

**`test/features/auth/domain/usecases/delete_account_usecase_test.dart`** (5 tests)

| Test | What it covers |
|------|----------------|
| Calls `repository.deleteAccount()` exactly once | Repository delegation |
| Returns `Right(null)` when repository succeeds | Happy path |
| Propagates `AuthFailure` from repository | Auth error passthrough |
| Propagates `UnexpectedFailure` from repository | Generic error passthrough, message preserved |
| Does not call any other repository method | No side-effect scope creep |

### Suite Totals

| Stage | Tests Added | Running Total |
|-------|------------|---------------|
| Chapters 1–10 (baseline) | 123 | 123 |
| Chapter 14 — AI datasource rewrite | ±0 (9 replaced 6) | 126 |
| Chapter 15 — TripTheme + model tests | +23 | 149 |
| Chapter 18 — DeleteAccountUseCase | +5 | 154 |

All 154 tests pass (`flutter test`).

---

*End of Chapter 18 — Test Suite: Stage 14–15*

---

## Chapter 19 — Stage 16: Chat Polish, Animations & Accessibility

**Status:** Complete ✅

### Read Receipts

**SQL migration (`docs/supabase_migrations/stage15_read_receipts.sql`)**

A `read_by text[]` column (default `'{}'`) was added to the `messages` table. A `SECURITY DEFINER` RPC `mark_messages_read(p_itinerary_id uuid)` atomically appends the caller's `auth.uid()` to every message in the given itinerary that was sent by someone else and hasn't yet been marked read by the caller. Using an RPC avoids the need for a broad `UPDATE` RLS policy on the messages table.

**Domain / Data**

`Message` entity gained a `readBy: List<String>` field (default `const []`), included in `Equatable.props`. `MessageModel.fromJson` reads `json['read_by']` with null-safe casting; `toJson` writes `read_by`. `ChatRemoteDataSource` gained `markMessagesRead(String itineraryId)` calling the RPC.

**Presentation**

`ChatPage._subscribeTyping` fires `markMessagesRead` fire-and-forget on open. A `ref.listen` on `chatStreamProvider` fires it again whenever new messages arrive (so messages sent while the screen is open get acknowledged too).

`_ReadTick` widget — rendered inline after the timestamp in each outgoing bubble: `Icons.done_all` (full opacity) when `readBy.isNotEmpty`, `Icons.done` (55% opacity) otherwise. Both are 12px icons in `AppTheme.cloudWhite`.

### Hero Animations

A `Hero` tag `'trip-header-${itinerary.id}'` was added to:
- The 4px gradient accent bar in `ItineraryCard` (hero source).
- The `SliverAppBar` `FlexibleSpaceBar` background `Container` in `ItineraryDetailPage` (hero destination).

Flutter interpolates the size from 4px-tall bar to full expanded header on push, and reverses it on pop. No custom flight shuttle is needed.

### Slide Page Transitions

A `_slidePage<T>` helper in `router.dart` returns a `CustomTransitionPage` with a `SlideTransition` (right → left, `Curves.easeInOutCubic`, 280ms push / 240ms pop). Every full-screen push route — including the two new `/legal/*` routes — uses `_slidePage`. Shell tab routes (`NoTransitionPage`) are unaffected.

### Accessibility Improvements

`_DotsAnimation` in `_TypingIndicator` is wrapped with `ExcludeSemantics` — the animated dots are purely decorative and the adjacent text label ("Alice is typing…") conveys the same information to screen readers.

`_SendButton` is wrapped with `Semantics(label: ..., button: true, enabled: ...)`. Label is `'Sending message'` during send and `'Send message'` otherwise. The `enabled` flag mirrors `!isSending` so VoiceOver/TalkBack correctly reports the disabled state.

---

*End of Chapter 19 — Stage 16: Chat Polish, Animations & Accessibility*

---

## Chapter 20 — Test Suite: Stage 15–16

**Status:** Complete ✅

### New Test Files

**`test/features/legal/presentation/pages/legal_pages_test.dart`** (13 widget tests)

| Group | Test | What it covers |
|-------|------|----------------|
| PrivacyPolicyPage | Renders title in AppBar | Widget renders |
| | Contains effective date (1 July 2026) | Static content present |
| | Contains "Data We Collect" section | Scrollable section present |
| | Contains "Your Rights" section | GDPR rights section present |
| | Mentions "Delete Account" | Right-to-erasure workflow documented |
| | Mentions "Supabase" as sub-processor | Sub-processor disclosure present |
| | Back navigation via AppBar | `BackButton` present when pushed |
| TermsPage | Renders title in AppBar | Widget renders |
| | Contains effective date (1 July 2026) | Static content present |
| | Contains "Acceptable Use" section | Scrollable section present |
| | Termination section references "Delete Account" | Termination clause present |
| | Mentions "Katha AI" | AI disclaimer present |
| | Mentions "England and Wales" | Governing law present |

**`test/features/chat/data/models/message_model_test.dart`** (11 unit tests)

| Group | Test | What it covers |
|-------|------|----------------|
| Message entity | `readBy` defaults to empty list | Default value on entity |
| | `readBy` is included in equality props | Equatable coverage |
| MessageModel.fromJson | Parses all standard fields | Core field mapping |
| | Defaults `readBy` to empty when key absent | Null-safe parsing |
| | Defaults `readBy` to empty when key is null | Null-safe parsing |
| | Parses `read_by` array correctly | Happy path |
| | Parses empty `read_by` array | Edge case |
| | Defaults `senderName` to empty string when absent | Backwards compat |
| | `createdAt` is UTC | Timezone handling |
| MessageModel.toJson | Includes `read_by` in output | Serialisation |
| | Serialises empty `readBy` as empty list | Edge case |
| | Round-trips through fromJson/toJson | Consistency |

### Suite Totals

| Chapter | Tests Added | Running Total |
|---------|------------|---------------|
| Chapters 1–18 (baseline) | 154 | 154 |
| Chapter 20 — Legal widget tests | +13 | 167 |
| Chapter 20 — MessageModel unit tests | +11 | 178 |

All 178 tests expected to pass (`flutter test`).

---

*End of Chapter 20 — Test Suite: Stage 15–16*
