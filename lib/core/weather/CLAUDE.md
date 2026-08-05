# lib/core/weather

Per-trip-leg weather forecast, shown as a small chip on each `SegmentCard` in
the Route tab (`lib/features/itinerary/presentation/widgets/segment_card.dart`).
Kept as a flat core module, not a full feature layer — like
`lib/core/geocoding/`, it's a stateless external lookup, not persisted
domain data, so there's no repository/usecase split.

### Source priority ("official met office first")

The brief was: prefer each destination's own national meteorological office
over generic consumer weather apps, falling back to the best generic API
where no official source is available. Genuinely integrating a per-country
met office for all ~190 countries isn't feasible without the user obtaining
a registered/paid API key for each one (UK Met Office DataHub, Météo-France,
DWD, JMA, BOM, etc. all require this). Instead, `FallbackWeatherService`
(`fallback_weather_service.dart`) tries three free, keyless sources in
order and returns the first hit:

1. **`NwsWeatherService`** — US National Weather Service (`api.weather.gov`). The literal local met office, but US-only; `/points/{lat},{lon}` 404s outside the US grid, which is treated as "not covered" (`null`, not an error).
2. **`MetNorwayWeatherService`** — Norway's national met institute (`api.met.no`, Locationforecast). Used as the "real met office" for everywhere else, since it has genuine global coverage (it's the data behind Yr and many other consumer apps worldwide) — not a generic aggregator standing in for one.
3. **`OpenMeteoWeatherService`** — Open-Meteo (`api.open-meteo.com`). Pure last-resort safety net if both official sources fail or don't cover a location/date.

All three are free and keyless — nothing was added to `lib/config/environment.dart` or CI secrets for this feature.

### Swapping/reordering/adding a source

Every `WeatherService` implementation is self-contained and knows nothing
about the others. The entire fallback order lives in exactly one place —
the list passed into `FallbackWeatherService` in `weather_providers.dart`'s
`weatherServiceProvider`. Reordering, disabling, or adding a source (e.g.
slotting a UK Met Office DataHub integration in ahead of MET Norway if an
API key is ever supplied) is a one-line edit there — no changes needed to
the fallback logic, the UI, or any other source's code or tests.

### Daily-only granularity

`WeatherService.forecastFor(...)` returns one `WeatherForecast` per calendar
date, not hourly data. The three sources have very different native shapes
(NWS: day/night periods: MET Norway: hourly timeseries with 6-hourly
summary blocks; Open-Meteo: native daily aggregates) — daily is the
granularity all three can produce consistently behind one interface.
`MetNorwayWeatherService` aggregates same-UTC-day timeseries entries into a
min/max and picks the entry closest to 12:00 UTC for the day's
condition/wind; `NwsWeatherService` pairs a date's day/night periods for
max/min.

### Attribution

MET Norway's and Open-Meteo's terms of use require crediting the data
source. `WeatherForecast.sourceName` carries this (each concrete service
stamps its own literal name onto every forecast it builds), and
`SegmentCard`'s weather chip shows it in a snackbar on tap rather than
inline, to keep the row compact.

### UI integration

`SegmentCard` is a `ConsumerWidget` that watches
`segmentWeatherProvider(WeatherRequest(...))` for the segment's destination
waypoint and resolved date (`arrivalTime ?? departureTime`). No chip is
shown for segments with no date, a past date, or a date beyond ~16 days out
(Open-Meteo's own forecast horizon — the furthest of the three sources) —
there's no point subscribing the provider for a segment that can't possibly
get an answer. Loading shows a small spinner; no data or an error renders
nothing, since weather is decorative and must never block or clutter the
segment row.

Not wired into `RouteMapView`'s map overlay or the add/edit segment page —
scoped to the Route tab's segment list only.
