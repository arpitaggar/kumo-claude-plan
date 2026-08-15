# lib/core/accommodation

Added 2026-08-15. Multi-source accommodation search — shown on the trip detail page's "Stay" tab (`lib/features/itinerary/presentation/pages/itinerary_detail_page.dart`'s `_AccommodationTab`). Kept as a flat core module, not a full feature layer, matching `lib/core/weather/`'s reasoning: it's a stateless external lookup (no persisted domain data beyond the two source-preference columns on `profiles`/`itineraries` — see below), not something with its own repository/usecase split.

### Why every source is mocked right now

None of Airbnb, Expedia, Booking.com, or Hostelworld hand out self-serve API access. Airbnb has no public listings API for third parties at all. The three OTAs gate real access behind approval-based affiliate/partner programs (Booking.com Affiliate Partner Program, Expedia Group's Rapid API via EPS, Hostelworld's affiliate program) — a business process, not something a code change can shortcut.

So v1 ships **fully mocked**: `mock_airbnb_source.dart`, `mock_expedia_source.dart`, `mock_booking_source.dart`, `mock_hostelworld_source.dart` each return realistic fixture listings (scattered around the query's search center via `geo_jitter.dart`, filtered back down by an authoritative radius/price check in `combined_accommodation_source.dart` via `geo_distance.dart`). This mirrors exactly how Katha AI shipped (`generate-itinerary` Edge Function, code-complete, gated behind a "coming soon" placeholder until `ANTHROPIC_API_KEY` existed) — the architecture is real and final; only the data source is a placeholder.

**`MockBookingSource` deliberately reuses two hotel names from `MockExpediaSource`'s fixture list** ("Grand Plaza Hotel", "The Riverside Hotel") — this is what a real hotel resold by multiple OTAs looks like in the wild, and it's the concrete case the "no merge in v1" decision below is about.

### Merge vs. no-merge — the core design decision

The same physical hotel is often resold by multiple OTAs. A real metasearch product (Skyscanner is the reference point this feature's design conversation used) would eventually show that as *one* listing with two prices. **v1 deliberately does not do this** — a hotel on both Expedia and Booking.com renders as two separate `AccommodationListing`s, each with its own source badge, in `CombinedAccommodationSource.search()`'s flat merged list.

Why: cross-source entity resolution (matching "Booking.com's listing #4821" to "Expedia's listing #99201" as the same building) is a genuinely hard problem — no universal ID exists, and even geo+name fuzzy-matching has a real false-positive failure mode (incorrectly merging two *different* hotels and showing the wrong price is a trust-breaking bug, not a cosmetic one). It's also a narrower problem than it first looks: **Airbnb listings never need this** — individual host inventory essentially never also appears on Expedia/Booking under a different name, so only the "traditional OTA" sources (Expedia/Booking/Hostelworld) would ever be merge candidates. If this becomes a v2, it should live as a new, separate, conservative matching pass (geo proximity *and* name-similarity, both required, never merge on uncertainty) sitting between `CombinedAccommodationSource` and the UI — not inside any individual source.

### Adding a new source

1. Register its display metadata in `accommodation_source_meta.dart`'s `kAccommodationSources` — this alone makes it appear (togglable, but non-functional) in the profile/trip settings pickers. A source can be "known" before it's "fetchable."
2. Implement `AccommodationSource` (`accommodation_source.dart`) — for a mock, follow `mock_hostelworld_source.dart`'s shape (shortest of the four). For a real source, see the Edge Function recipe below.
3. Add it to the list in `accommodation_providers.dart`'s `accommodationSourcesProvider` — this is the one place that turns "known" into "actually queried."

No other file changes needed — `CombinedAccommodationSource`, the settings pickers, and the Stay tab all iterate whatever's registered, none of them hardcode a source count or name.

### Wiring up a real source later (the Edge Function recipe)

This app already has the exact template to clone: `supabase/functions/generate-itinerary/index.ts` (Katha AI, proxying the Anthropic API). A real accommodation source's Edge Function should follow the same shape:

1. Header comment documenting the required secret (`supabase secrets set <SOURCE>_API_KEY=...`) and deploy command (`supabase functions deploy listings-<source>`).
2. CORS headers block + `OPTIONS` preflight handling (copy verbatim).
3. Manual auth: extract the `Authorization` header, create a `service_role` client, call `supabase.auth.getUser(bearerToken)` — don't rely solely on the platform's default JWT gate.
4. Optional per-user rate limiting via a dedicated request-log table, if the partner API is metered/costs money per call (clone `generate-itinerary`'s `generation_requests` table pattern).
5. `Deno.env.get('<SOURCE>_API_KEY')`, `fetch()` the partner API server-side — the key must never reach the client.
6. Tolerant response parsing; never surface the raw upstream error verbatim to the client.
7. On the Flutter side: a new `XyzAccommodationSource implements AccommodationSource` whose `search()` calls `KumoSupabaseClient.client.functions.invoke('listings-<source>', body: {...})`, converting a `FunctionException` or an in-band `{error: ...}` body into a thrown `ServerException` — matching `AiGenerationDataSourceImpl`'s exact error-handling shape.

Then swap the corresponding `Mock*Source()` for the real one in `accommodationSourcesProvider` — one line, no other change.

### Settings: profile default → copied onto trip → independently editable

`profiles.enabled_accommodation_sources` (nullable `text[]`) is the user's default — **null means "all sources," not "no sources,"** so a source added to the catalog later automatically appears for anyone who's never customized this. `itineraries.accommodation_sources` (`text[]`, never null) is stamped with a *concrete* list at trip-creation time (`CreateItineraryUseCase` resolves the creator's profile setting — including resolving null to "every currently-known source key" — at that exact moment) and is independently editable afterward via the trip detail page's AppBar action, same as theme. A trip's setting deliberately doesn't silently change later just because the profile default changes or a new source ships.

### v1 known limitations (not gaps — deliberate scope cuts)

- **No cross-source merge** — see above.
- **No manual search-center override** — the query's lat/lng always comes from geocoding the trip's destination title; picking a different center point (e.g. "near the train station instead of downtown") is a natural fast-follow, not built yet.
- **No real logos** — `AccommodationSourceMeta.badgeColor` is a plain colored badge, not each platform's actual trademarked logo mark, since using a real brand's logo without an actual partnership risks their brand-usage guidelines. Swap in official assets once a partnership + its brand terms exist for that source.
- **Activities are a separate, not-yet-built feature** — same pattern (source abstraction, settings inheritance, Edge Function recipe), deliberately deferred as its own fast-follow rather than built alongside this.
