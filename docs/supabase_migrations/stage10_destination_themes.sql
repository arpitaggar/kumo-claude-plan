-- Stage 10: Destination themes
-- Adds a theme_key column to itineraries so each trip stores its visual palette.
-- Safe to run on existing data: defaults to 'classic' which matches the prior
-- hard-coded Kumo colour scheme.

ALTER TABLE itineraries
  ADD COLUMN IF NOT EXISTS theme_key TEXT NOT NULL DEFAULT 'classic';

-- Allowed values mirror TripTheme.all keys in the Flutter client.
ALTER TABLE itineraries
  ADD CONSTRAINT itineraries_theme_key_check
    CHECK (theme_key IN (
      'classic', 'sakura', 'tropical', 'alpine',
      'desert', 'nordic', 'mediterranean', 'rainforest'
    ));
