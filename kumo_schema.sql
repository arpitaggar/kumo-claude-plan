-- ============================================================
--  Kumo — Complete PostgreSQL Schema
--  Database: PostgreSQL 15+  (Aurora-compatible)
--  Run order: enums → extensions → tables → indexes →
--             triggers → functions → views → RLS
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";          -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";           -- fuzzy text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";         -- GIN on composite keys
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "citext";             -- case-insensitive text

-- ── Enums ────────────────────────────────────────────────────
CREATE TYPE auth_provider    AS ENUM ('email','google','apple','guest');
CREATE TYPE trip_status      AS ENUM ('planning','active','completed');
CREATE TYPE trip_visibility  AS ENUM ('private','unlisted','public');
CREATE TYPE member_role      AS ENUM ('owner','editor','viewer');
CREATE TYPE item_type        AS ENUM ('activity','transport','hotel',
                                      'restaurant','note','flight');
CREATE TYPE booking_type     AS ENUM ('hotel','airbnb','experience',
                                      'flight','restaurant','other');
CREATE TYPE msg_type         AS ENUM ('text','image','itinerary_card',
                                      'poll','expense','system');
CREATE TYPE notif_type       AS ENUM ('trip_invite','member_joined',
                                      'itinerary_updated','chat_message',
                                      'expense_added','poll_created',
                                      'comment','like','follow','ai_complete');
CREATE TYPE ai_mode          AS ENUM ('skeleton','concierge');
CREATE TYPE ai_status        AS ENUM ('running','complete','failed','cancelled');
CREATE TYPE rating_subject   AS ENUM ('place','hotel','experience',
                                      'restaurant','destination');
CREATE TYPE settlement_status AS ENUM ('pending','confirmed');

-- ============================================================
--  SECTION 1 — Users & Auth
-- ============================================================

CREATE TABLE users (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email            CITEXT      UNIQUE,
  display_name     TEXT        NOT NULL,
  bio              TEXT,
  avatar_url       TEXT,
  cover_url        TEXT,
  auth_provider    auth_provider NOT NULL DEFAULT 'email',
  is_guest         BOOLEAN     NOT NULL DEFAULT false,
  reputation       INTEGER     NOT NULL DEFAULT 0,
  followers_count  INTEGER     NOT NULL DEFAULT 0,
  following_count  INTEGER     NOT NULL DEFAULT 0,
  trips_count      INTEGER     NOT NULL DEFAULT 0,
  is_verified      BOOLEAN     NOT NULL DEFAULT false,
  is_banned        BOOLEAN     NOT NULL DEFAULT false,
  last_active_at   TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT users_display_name_len CHECK (char_length(display_name) BETWEEN 2 AND 60),
  CONSTRAINT users_reputation_non_neg CHECK (reputation >= 0)
);

COMMENT ON TABLE users IS 'Core user accounts. Guests have is_guest=true and no email.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE oauth_connections (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider         auth_provider NOT NULL,
  provider_user_id TEXT        NOT NULL,
  access_token     TEXT,
  refresh_token    TEXT,
  token_expires_at TIMESTAMPTZ,
  raw_profile      JSONB       DEFAULT '{}',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (provider, provider_user_id)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE user_settings (
  user_id          UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  language         CHAR(2)     NOT NULL DEFAULT 'en',
  currency         CHAR(3)     NOT NULL DEFAULT 'USD',
  date_format      TEXT        NOT NULL DEFAULT 'DD/MM/YYYY',
  distance_unit    TEXT        NOT NULL DEFAULT 'km' CHECK (distance_unit IN ('km','mi')),
  push_enabled     BOOLEAN     NOT NULL DEFAULT true,
  email_enabled    BOOLEAN     NOT NULL DEFAULT true,
  marketing_emails BOOLEAN     NOT NULL DEFAULT false,
  profile_public   BOOLEAN     NOT NULL DEFAULT true,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
--  SECTION 2 — Trips
-- ============================================================

CREATE TABLE trips (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  title            TEXT           NOT NULL,
  description      TEXT,
  cover_url        TEXT,
  destination      TEXT           NOT NULL,
  destination_lat  NUMERIC(10,7),
  destination_lng  NUMERIC(10,7),
  start_date       DATE,
  end_date         DATE,
  status           trip_status    NOT NULL DEFAULT 'planning',
  visibility       trip_visibility NOT NULL DEFAULT 'private',
  currency         CHAR(3)        NOT NULL DEFAULT 'USD',
  timezone         TEXT           NOT NULL DEFAULT 'UTC',
  tags             TEXT[]         DEFAULT '{}',
  cover_emoji      TEXT,
  created_by       UUID           NOT NULL REFERENCES users(id),
  cloned_from      UUID           REFERENCES trips(id) ON DELETE SET NULL,
  likes_count      INTEGER        NOT NULL DEFAULT 0,
  comments_count   INTEGER        NOT NULL DEFAULT 0,
  clones_count     INTEGER        NOT NULL DEFAULT 0,
  views_count      INTEGER        NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT trips_dates_valid  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
  CONSTRAINT trips_title_len    CHECK (char_length(title) BETWEEN 2 AND 120)
);

COMMENT ON TABLE trips IS 'A trip plan. visibility=public makes it appear in the social feed.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE trip_members (
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role             member_role NOT NULL DEFAULT 'viewer',
  invited_by       UUID        REFERENCES users(id),
  joined_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_viewed_at   TIMESTAMPTZ,

  PRIMARY KEY (trip_id, user_id)
);

COMMENT ON TABLE trip_members IS 'RBAC: owner can do everything, editor can edit itinerary, viewer is read-only.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE trip_invites (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  invited_by       UUID        NOT NULL REFERENCES users(id),
  email            CITEXT      NOT NULL,
  role             member_role NOT NULL DEFAULT 'editor',
  token            TEXT        NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),
  accepted         BOOLEAN,
  expires_at       TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '7 days',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (trip_id, email)
);

-- ============================================================
--  SECTION 3 — Itinerary
-- ============================================================

CREATE TABLE itinerary_items (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  day_number       SMALLINT    CHECK (day_number > 0),
  position         INTEGER     NOT NULL DEFAULT 0,
  item_type        item_type   NOT NULL,
  title            TEXT        NOT NULL,
  description      TEXT,
  location_name    TEXT,
  latitude         NUMERIC(10,7),
  longitude        NUMERIC(10,7),
  place_id         TEXT,                          -- Google Place ID
  starts_at        TIMESTAMPTZ,
  ends_at          TIMESTAMPTZ,
  duration_minutes INTEGER,
  cost_estimate    NUMERIC(14,2),
  currency         CHAR(3),
  booking_url      TEXT,
  confirmation_ref TEXT,                          -- booking reference
  notes            TEXT,
  ai_generated     BOOLEAN     NOT NULL DEFAULT false,
  ai_session_id    UUID,                          -- source AI session
  is_confirmed     BOOLEAN     NOT NULL DEFAULT false,
  attachments      JSONB       DEFAULT '[]',      -- [{url, name, type}]
  metadata         JSONB       DEFAULT '{}',
  created_by       UUID        NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT items_end_after_start CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at),
  CONSTRAINT items_cost_non_neg    CHECK (cost_estimate IS NULL OR cost_estimate >= 0)
);

COMMENT ON TABLE itinerary_items IS 'A single activity/transport/hotel/etc on a trip. Ordered by (day_number, position).';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE itinerary_item_votes (
  item_id          UUID        NOT NULL REFERENCES itinerary_items(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vote             SMALLINT    NOT NULL CHECK (vote IN (-1, 1)),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (item_id, user_id)
);

COMMENT ON TABLE itinerary_item_votes IS 'Up/down votes so group members can signal interest in specific items.';

-- ============================================================
--  SECTION 4 — Collaboration
-- ============================================================

CREATE TABLE chat_messages (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  sender_id        UUID        NOT NULL REFERENCES users(id),
  body             TEXT,
  message_type     msg_type    NOT NULL DEFAULT 'text',
  reply_to_id      UUID        REFERENCES chat_messages(id) ON DELETE SET NULL,
  metadata         JSONB       DEFAULT '{}',      -- card data, image urls, etc.
  edited           BOOLEAN     NOT NULL DEFAULT false,
  edited_at        TIMESTAMPTZ,
  deleted          BOOLEAN     NOT NULL DEFAULT false,
  deleted_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE chat_messages IS 'Group chat per trip. Append-only logical model; soft deletes for moderation.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE chat_reactions (
  message_id       UUID        NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji            TEXT        NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id, emoji)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE polls (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  chat_message_id  UUID        REFERENCES chat_messages(id) ON DELETE SET NULL,
  created_by       UUID        NOT NULL REFERENCES users(id),
  question         TEXT        NOT NULL,
  is_multiple      BOOLEAN     NOT NULL DEFAULT false,
  closes_at        TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()

  CONSTRAINT polls_question_len CHECK (char_length(question) BETWEEN 3 AND 300)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE poll_options (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id          UUID        NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  label            TEXT        NOT NULL,
  position         SMALLINT    NOT NULL DEFAULT 0,
  itinerary_item_id UUID       REFERENCES itinerary_items(id) ON DELETE SET NULL,

  CONSTRAINT poll_options_label_len CHECK (char_length(label) BETWEEN 1 AND 200)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE poll_votes (
  poll_id          UUID        NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  option_id        UUID        NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  voted_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (poll_id, option_id, user_id)
);

-- ============================================================
--  SECTION 5 — Expenses
-- ============================================================

CREATE TABLE expenses (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  paid_by          UUID        NOT NULL REFERENCES users(id),
  title            TEXT        NOT NULL,
  category         TEXT,                         -- food|transport|accommodation|activity|other
  amount           NUMERIC(14,4) NOT NULL,
  currency         CHAR(3)     NOT NULL,
  amount_base      NUMERIC(14,4),                -- normalised to trip.currency
  fx_rate          NUMERIC(14,8),                -- rate used at conversion time
  receipt_url      TEXT,
  itinerary_item_id UUID       REFERENCES itinerary_items(id) ON DELETE SET NULL,
  notes            TEXT,
  incurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT expenses_amount_pos CHECK (amount > 0)
);

COMMENT ON TABLE expenses IS 'A shared cost. amount_base stores value in trip.currency for settlement maths.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE expense_splits (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id       UUID        NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount           NUMERIC(14,4) NOT NULL,        -- share owed
  amount_base      NUMERIC(14,4),                 -- in trip currency
  is_settled       BOOLEAN     NOT NULL DEFAULT false,
  settled_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (expense_id, user_id),
  CONSTRAINT splits_amount_pos CHECK (amount > 0)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE expense_settlements (
  id               UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID             NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  from_user_id     UUID             NOT NULL REFERENCES users(id),
  to_user_id       UUID             NOT NULL REFERENCES users(id),
  amount           NUMERIC(14,4)    NOT NULL,
  currency         CHAR(3)          NOT NULL,
  status           settlement_status NOT NULL DEFAULT 'pending',
  confirmed_at     TIMESTAMPTZ,
  note             TEXT,
  created_at       TIMESTAMPTZ      NOT NULL DEFAULT now(),

  CONSTRAINT settlements_diff_users CHECK (from_user_id <> to_user_id),
  CONSTRAINT settlements_amount_pos  CHECK (amount > 0)
);

-- ============================================================
--  SECTION 6 — Social
-- ============================================================

CREATE TABLE trip_likes (
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (trip_id, user_id)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE trip_comments (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id),
  parent_id        UUID        REFERENCES trip_comments(id) ON DELETE CASCADE,
  body             TEXT        NOT NULL,
  likes_count      INTEGER     NOT NULL DEFAULT 0,
  edited           BOOLEAN     NOT NULL DEFAULT false,
  deleted          BOOLEAN     NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT comments_body_len CHECK (char_length(body) BETWEEN 1 AND 2000)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE trip_clones (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  source_trip_id   UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  new_trip_id      UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  cloned_by        UUID        NOT NULL REFERENCES users(id),
  cloned_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (source_trip_id, new_trip_id)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE user_follows (
  follower_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (follower_id, followee_id),
  CONSTRAINT follows_no_self CHECK (follower_id <> followee_id)
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE reputation_events (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type       TEXT        NOT NULL,          -- 'trip_liked','trip_cloned','comment_posted',etc
  delta            SMALLINT    NOT NULL,           -- +/- change
  reference_id     UUID,                           -- trip, comment, etc.
  reference_type   TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reputation_events IS 'Audit log for all reputation changes. Sum = users.reputation.';

-- ============================================================
--  SECTION 7 — Ratings
-- ============================================================

CREATE TABLE ratings (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_type     rating_subject NOT NULL,
  subject_ref      TEXT           NOT NULL,       -- Google Place ID or internal ID
  subject_name     TEXT,
  user_id          UUID           NOT NULL REFERENCES users(id),
  trip_id          UUID           REFERENCES trips(id) ON DELETE SET NULL,
  overall          NUMERIC(3,1)   NOT NULL CHECK (overall BETWEEN 1 AND 5),
  -- Category scores (NULL = not rated for that category)
  value_for_money  NUMERIC(3,1)   CHECK (value_for_money BETWEEN 1 AND 5),
  vibe             NUMERIC(3,1)   CHECK (vibe BETWEEN 1 AND 5),
  service          NUMERIC(3,1)   CHECK (service BETWEEN 1 AND 5),
  food             NUMERIC(3,1)   CHECK (food BETWEEN 1 AND 5),
  accessibility    NUMERIC(3,1)   CHECK (accessibility BETWEEN 1 AND 5),
  safety           NUMERIC(3,1)   CHECK (safety BETWEEN 1 AND 5),
  cleanliness      NUMERIC(3,1)   CHECK (cleanliness BETWEEN 1 AND 5),
  body             TEXT           CHECK (char_length(body) <= 2000),
  photos           TEXT[]         DEFAULT '{}',
  helpful_count    INTEGER        NOT NULL DEFAULT 0,
  not_helpful_count INTEGER       NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),

  UNIQUE (subject_type, subject_ref, user_id)
);

COMMENT ON TABLE ratings IS 'Community-generated ratings. One per user per subject. Categories are optional.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE rating_helpful_votes (
  rating_id        UUID        NOT NULL REFERENCES ratings(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  helpful          BOOLEAN     NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (rating_id, user_id)
);

-- ============================================================
--  SECTION 8 — Booking Hub
-- ============================================================

CREATE TABLE saved_bookings (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          UUID         REFERENCES trips(id) ON DELETE CASCADE,
  user_id          UUID         NOT NULL REFERENCES users(id),
  itinerary_item_id UUID        REFERENCES itinerary_items(id) ON DELETE SET NULL,
  booking_type     booking_type NOT NULL,
  title            TEXT         NOT NULL,
  description      TEXT,
  image_url        TEXT,
  source_url       TEXT,
  affiliate_url    TEXT,
  price            NUMERIC(14,2),
  currency         CHAR(3),
  check_in         DATE,
  check_out        DATE,
  location_name    TEXT,
  latitude         NUMERIC(10,7),
  longitude        NUMERIC(10,7),
  place_id         TEXT,
  rating           NUMERIC(3,1),
  metadata         JSONB        DEFAULT '{}',
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────

CREATE TABLE affiliate_clicks (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id       UUID        NOT NULL REFERENCES saved_bookings(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id),
  affiliate_url    TEXT        NOT NULL,
  ip_hash          TEXT,
  user_agent       TEXT,
  clicked_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE affiliate_clicks IS 'Click-through tracking for affiliate revenue attribution.';

-- ============================================================
--  SECTION 9 — AI Planning
-- ============================================================

CREATE TABLE ai_sessions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id),
  trip_id          UUID        REFERENCES trips(id) ON DELETE SET NULL,
  mode             ai_mode     NOT NULL,
  status           ai_status   NOT NULL DEFAULT 'running',
  input_prompt     TEXT,
  messages         JSONB       NOT NULL DEFAULT '[]',   -- full conversation history
  result           JSONB,                               -- final structured itinerary
  applied          BOOLEAN     NOT NULL DEFAULT false,
  applied_at       TIMESTAMPTZ,
  model_used       TEXT,
  tokens_input     INTEGER,
  tokens_output    INTEGER,
  latency_ms       INTEGER,
  error_message    TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at     TIMESTAMPTZ
);

COMMENT ON TABLE ai_sessions IS 'AI planning sessions. messages stores full conversation for concierge mode.';

-- ============================================================
--  SECTION 10 — Notifications
-- ============================================================

CREATE TABLE notifications (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type             notif_type  NOT NULL,
  title            TEXT        NOT NULL,
  body             TEXT,
  image_url        TEXT,
  action_url       TEXT,
  actor_id         UUID        REFERENCES users(id) ON DELETE SET NULL,
  reference_id     UUID,
  reference_type   TEXT,
  is_read          BOOLEAN     NOT NULL DEFAULT false,
  read_at          TIMESTAMPTZ,
  sent_push        BOOLEAN     NOT NULL DEFAULT false,
  sent_email       BOOLEAN     NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE notifications IS 'In-app notification inbox. Push/email sent by worker and flagged here.';

-- ─────────────────────────────────────────────────────────────

CREATE TABLE push_tokens (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token            TEXT        NOT NULL UNIQUE,
  platform         TEXT        NOT NULL CHECK (platform IN ('ios','android','web')),
  is_active        BOOLEAN     NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
--  SECTION 11 — Search Sync Queue
-- ============================================================

CREATE TABLE search_sync_queue (
  id               BIGSERIAL   PRIMARY KEY,
  resource_type    TEXT        NOT NULL,   -- 'trip'|'user'|'rating'|'destination'
  resource_id      UUID        NOT NULL,
  operation        TEXT        NOT NULL CHECK (operation IN ('index','update','delete')),
  payload          JSONB,
  processed        BOOLEAN     NOT NULL DEFAULT false,
  processed_at     TIMESTAMPTZ,
  error            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()

);

CREATE INDEX idx_sync_queue_resource ON search_sync_queue(resource_type, resource_id);
CREATE INDEX idx_sync_queue_pending ON search_sync_queue(processed, created_at) WHERE processed = false;

COMMENT ON TABLE search_sync_queue IS 'CDC feed into OpenSearch. Workers drain this table periodically.';

-- ============================================================
--  INDEXES
-- ============================================================

-- users
CREATE INDEX idx_users_email           ON users(email);
CREATE INDEX idx_users_reputation      ON users(reputation DESC);
CREATE INDEX idx_users_last_active     ON users(last_active_at DESC NULLS LAST);
CREATE INDEX idx_users_display_name_trgm ON users USING GIN (display_name gin_trgm_ops);

-- trips
CREATE INDEX idx_trips_created_by      ON trips(created_by);
CREATE INDEX idx_trips_status          ON trips(status);
CREATE INDEX idx_trips_visibility      ON trips(visibility) WHERE visibility = 'public';
CREATE INDEX idx_trips_public_popular  ON trips(likes_count DESC, created_at DESC)
  WHERE visibility = 'public';
CREATE INDEX idx_trips_destination_trgm ON trips USING GIN (destination gin_trgm_ops);
CREATE INDEX idx_trips_tags            ON trips USING GIN (tags);
CREATE INDEX idx_trips_updated         ON trips(updated_at DESC);

-- trip_members
CREATE INDEX idx_trip_members_user     ON trip_members(user_id);
CREATE INDEX idx_trip_members_trip     ON trip_members(trip_id);

-- itinerary_items
CREATE INDEX idx_items_trip_day_pos    ON itinerary_items(trip_id, day_number, position);
CREATE INDEX idx_items_place_id        ON itinerary_items(place_id) WHERE place_id IS NOT NULL;
CREATE INDEX idx_items_location        ON itinerary_items(latitude, longitude)
  WHERE latitude IS NOT NULL;

-- chat_messages
CREATE INDEX idx_chat_trip_created     ON chat_messages(trip_id, created_at DESC);
CREATE INDEX idx_chat_sender           ON chat_messages(sender_id);

-- polls
CREATE INDEX idx_polls_trip            ON polls(trip_id);

-- expenses
CREATE INDEX idx_expenses_trip         ON expenses(trip_id);
CREATE INDEX idx_expenses_paid_by      ON expenses(paid_by);
CREATE INDEX idx_expense_splits_user   ON expense_splits(user_id);
CREATE INDEX idx_expense_splits_exp    ON expense_splits(expense_id);
CREATE INDEX idx_settlements_trip      ON expense_settlements(trip_id);
CREATE INDEX idx_settlements_from      ON expense_settlements(from_user_id);

-- social
CREATE INDEX idx_likes_trip            ON trip_likes(trip_id);
CREATE INDEX idx_likes_user            ON trip_likes(user_id);
CREATE INDEX idx_comments_trip         ON trip_comments(trip_id, created_at DESC);
CREATE INDEX idx_comments_parent       ON trip_comments(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_follows_follower      ON user_follows(follower_id);
CREATE INDEX idx_follows_followee      ON user_follows(followee_id);
CREATE INDEX idx_rep_events_user       ON reputation_events(user_id, created_at DESC);

-- ratings
CREATE INDEX idx_ratings_subject       ON ratings(subject_type, subject_ref);
CREATE INDEX idx_ratings_user          ON ratings(user_id);
CREATE INDEX idx_ratings_trip          ON ratings(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_ratings_overall       ON ratings(subject_type, subject_ref, overall DESC);

-- bookings
CREATE INDEX idx_bookings_trip         ON saved_bookings(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_bookings_user         ON saved_bookings(user_id);
CREATE INDEX idx_bookings_type         ON saved_bookings(booking_type);

-- ai_sessions
CREATE INDEX idx_ai_sessions_user      ON ai_sessions(user_id, created_at DESC);
CREATE INDEX idx_ai_sessions_trip      ON ai_sessions(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_ai_sessions_status    ON ai_sessions(status) WHERE status = 'running';

-- notifications
CREATE INDEX idx_notifs_user_unread    ON notifications(user_id, created_at DESC)
  WHERE is_read = false;
CREATE INDEX idx_notifs_user_all       ON notifications(user_id, created_at DESC);

-- ============================================================
--  TRIGGERS — updated_at auto-maintenance
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','oauth_connections','user_settings','trips',
    'itinerary_items','expenses','expense_splits',
    'ratings','push_tokens','trip_comments'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%I_updated_at
       BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
      t, t
    );
  END LOOP;
END;
$$;

-- ============================================================
--  TRIGGERS — Denormalised counters
-- ============================================================

-- Trip likes_count
CREATE OR REPLACE FUNCTION sync_trip_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE trips SET likes_count = likes_count + 1 WHERE id = NEW.trip_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE trips SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.trip_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_trip_likes_count AFTER INSERT OR DELETE ON trip_likes
  FOR EACH ROW EXECUTE FUNCTION sync_trip_likes_count();

-- Trip comments_count
CREATE OR REPLACE FUNCTION sync_trip_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NOT NEW.deleted THEN
    UPDATE trips SET comments_count = comments_count + 1 WHERE id = NEW.trip_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.deleted AND NOT OLD.deleted THEN
    UPDATE trips SET comments_count = GREATEST(0, comments_count - 1) WHERE id = NEW.trip_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_trip_comments_count AFTER INSERT OR UPDATE ON trip_comments
  FOR EACH ROW EXECUTE FUNCTION sync_trip_comments_count();

-- Trip clones_count
CREATE OR REPLACE FUNCTION sync_trip_clones_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE trips SET clones_count = clones_count + 1 WHERE id = NEW.source_trip_id;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_trip_clones_count AFTER INSERT ON trip_clones
  FOR EACH ROW EXECUTE FUNCTION sync_trip_clones_count();

-- User followers/following counts
CREATE OR REPLACE FUNCTION sync_follow_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE users SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE users SET followers_count = followers_count + 1 WHERE id = NEW.followee_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE users SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
    UPDATE users SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.followee_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_follow_counts AFTER INSERT OR DELETE ON user_follows
  FOR EACH ROW EXECUTE FUNCTION sync_follow_counts();

-- Reputation from events
CREATE OR REPLACE FUNCTION sync_user_reputation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE users
  SET reputation = GREATEST(0, reputation + NEW.delta)
  WHERE id = NEW.user_id;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_reputation AFTER INSERT ON reputation_events
  FOR EACH ROW EXECUTE FUNCTION sync_user_reputation();

-- Queue search sync on trip insert/update
CREATE OR REPLACE FUNCTION queue_trip_for_search()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO search_sync_queue (resource_type, resource_id, operation)
  VALUES ('trip', NEW.id, CASE WHEN TG_OP = 'INSERT' THEN 'index' ELSE 'update' END)
  ON CONFLICT DO NOTHING;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_trip_search_sync AFTER INSERT OR UPDATE ON trips
  FOR EACH ROW WHEN (NEW.visibility = 'public')
  EXECUTE FUNCTION queue_trip_for_search();

-- ============================================================
--  FUNCTIONS
-- ============================================================

-- ── Settlement minimiser ──────────────────────────────────────
-- Returns the minimum set of transfers to settle all balances in a trip.
CREATE OR REPLACE FUNCTION calculate_settlements(p_trip_id UUID)
RETURNS TABLE(
  from_user_id UUID,
  to_user_id   UUID,
  amount       NUMERIC,
  currency     CHAR(3)
) LANGUAGE plpgsql AS $$
DECLARE
  _currency CHAR(3);
BEGIN
  SELECT t.currency INTO _currency FROM trips t WHERE t.id = p_trip_id;

  -- Compute net balance per user (positive = owed money, negative = owes money)
  WITH balances AS (
    SELECT
      u.user_id,
      COALESCE(SUM(CASE WHEN e.paid_by = u.user_id THEN es.amount_base ELSE -es.amount_base END), 0) AS balance
    FROM trip_members u
    LEFT JOIN expense_splits es ON es.user_id = u.user_id AND NOT es.is_settled
    LEFT JOIN expenses e ON e.id = es.expense_id AND e.trip_id = p_trip_id
    WHERE u.trip_id = p_trip_id
    GROUP BY u.user_id
  ),
  creditors AS (
    SELECT user_id, balance FROM balances WHERE balance > 0.005
    ORDER BY balance DESC
  ),
  debtors AS (
    SELECT user_id, -balance AS owes FROM balances WHERE balance < -0.005
    ORDER BY owes DESC
  )
  -- Simple greedy matching: pair largest creditor with largest debtor
  SELECT
    d.user_id AS from_user_id,
    c.user_id AS to_user_id,
    LEAST(d.owes, c.balance) AS amount,
    _currency  AS currency
  FROM debtors d
  CROSS JOIN LATERAL (
    SELECT user_id, balance FROM creditors LIMIT 1
  ) c
  WHERE LEAST(d.owes, c.balance) > 0.01;
END;
$$;

-- ── Clone a public trip ───────────────────────────────────────
CREATE OR REPLACE FUNCTION clone_trip(
  p_source_trip_id UUID,
  p_user_id        UUID,
  p_new_title      TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
  _new_id UUID;
  _source trips%ROWTYPE;
BEGIN
  SELECT * INTO _source FROM trips WHERE id = p_source_trip_id AND visibility = 'public';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trip not found or not public';
  END IF;

  -- Create new trip
  INSERT INTO trips (title, description, cover_url, destination, destination_lat, destination_lng,
                     start_date, end_date, currency, timezone, tags, cover_emoji,
                     created_by, cloned_from)
  VALUES (COALESCE(p_new_title, _source.title || ' (copy)'),
          _source.description, _source.cover_url, _source.destination,
          _source.destination_lat, _source.destination_lng,
          _source.start_date, _source.end_date, _source.currency,
          _source.timezone, _source.tags, _source.cover_emoji,
          p_user_id, p_source_trip_id)
  RETURNING id INTO _new_id;

  -- Add cloning user as owner
  INSERT INTO trip_members (trip_id, user_id, role) VALUES (_new_id, p_user_id, 'owner');

  -- Copy itinerary items
  INSERT INTO itinerary_items (trip_id, day_number, position, item_type, title, description,
                                location_name, latitude, longitude, place_id, duration_minutes,
                                cost_estimate, currency, booking_url, notes, ai_generated, created_by)
  SELECT _new_id, day_number, position, item_type, title, description,
         location_name, latitude, longitude, place_id, duration_minutes,
         cost_estimate, currency, booking_url, notes, ai_generated, p_user_id
  FROM itinerary_items
  WHERE trip_id = p_source_trip_id;

  -- Record clone
  INSERT INTO trip_clones (source_trip_id, new_trip_id, cloned_by)
  VALUES (p_source_trip_id, _new_id, p_user_id);

  -- Reputation event for original creator
  INSERT INTO reputation_events (user_id, event_type, delta, reference_id, reference_type)
  VALUES (_source.created_by, 'trip_cloned', 15, p_source_trip_id, 'trip');

  RETURN _new_id;
END;
$$;

-- ── Unread notification count ─────────────────────────────────
CREATE OR REPLACE FUNCTION unread_notification_count(p_user_id UUID)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT COUNT(*) FROM notifications
  WHERE user_id = p_user_id AND is_read = false;
$$;

-- ── Mark all notifications read ───────────────────────────────
CREATE OR REPLACE FUNCTION mark_notifications_read(p_user_id UUID)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE notifications
  SET is_read = true, read_at = now()
  WHERE user_id = p_user_id AND is_read = false;
$$;

-- ============================================================
--  VIEWS
-- ============================================================

-- Public trip feed with author info
CREATE VIEW public_trip_feed AS
SELECT
  t.id,
  t.title,
  t.description,
  t.cover_url,
  t.cover_emoji,
  t.destination,
  t.start_date,
  t.end_date,
  t.currency,
  t.tags,
  t.likes_count,
  t.comments_count,
  t.clones_count,
  t.views_count,
  t.created_at,
  u.id           AS author_id,
  u.display_name AS author_name,
  u.avatar_url   AS author_avatar,
  u.reputation   AS author_reputation,
  u.is_verified  AS author_verified,
  (SELECT COUNT(*) FROM itinerary_items i WHERE i.trip_id = t.id) AS item_count,
  (SELECT COUNT(*) FROM trip_members m WHERE m.trip_id = t.id)    AS member_count
FROM trips t
JOIN users u ON u.id = t.created_by
WHERE t.visibility = 'public';

-- Per-user trip expense summary
CREATE VIEW trip_expense_summary AS
SELECT
  e.trip_id,
  es.user_id,
  SUM(CASE WHEN e.paid_by = es.user_id THEN es.amount_base ELSE 0 END) AS total_paid,
  SUM(es.amount_base) AS total_owed,
  SUM(CASE WHEN e.paid_by = es.user_id THEN es.amount_base ELSE -es.amount_base END) AS net_balance
FROM expense_splits es
JOIN expenses e ON e.id = es.expense_id
WHERE NOT es.is_settled
GROUP BY e.trip_id, es.user_id;

-- Subject rating aggregates (for display)
CREATE VIEW rating_aggregates AS
SELECT
  subject_type,
  subject_ref,
  subject_name,
  COUNT(*)                  AS total_ratings,
  ROUND(AVG(overall), 2)   AS avg_overall,
  ROUND(AVG(value_for_money), 2) AS avg_value,
  ROUND(AVG(vibe), 2)      AS avg_vibe,
  ROUND(AVG(service), 2)   AS avg_service,
  ROUND(AVG(food), 2)      AS avg_food,
  ROUND(AVG(safety), 2)    AS avg_safety,
  ROUND(AVG(cleanliness), 2) AS avg_cleanliness
FROM ratings
GROUP BY subject_type, subject_ref, subject_name;

-- ============================================================
--  ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips               ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE itinerary_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses            ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_splits      ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_bookings      ENABLE ROW LEVEL SECURITY;

-- Users: own row + public profiles
CREATE POLICY users_select ON users FOR SELECT
  USING (id = current_setting('app.user_id')::UUID OR is_banned = false);
CREATE POLICY users_update ON users FOR UPDATE
  USING (id = current_setting('app.user_id')::UUID);

-- Trips: members can see, public trips visible to all
CREATE POLICY trips_select ON trips FOR SELECT
  USING (
    visibility = 'public'
    OR created_by = current_setting('app.user_id')::UUID
    OR EXISTS (
      SELECT 1 FROM trip_members tm
      WHERE tm.trip_id = id
        AND tm.user_id = current_setting('app.user_id')::UUID
    )
  );
CREATE POLICY trips_insert ON trips FOR INSERT
  WITH CHECK (created_by = current_setting('app.user_id')::UUID);
CREATE POLICY trips_update ON trips FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM trip_members tm
      WHERE tm.trip_id = id
        AND tm.user_id = current_setting('app.user_id')::UUID
        AND tm.role IN ('owner','editor')
    )
  );
CREATE POLICY trips_delete ON trips FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM trip_members tm
      WHERE tm.trip_id = id
        AND tm.user_id = current_setting('app.user_id')::UUID
        AND tm.role = 'owner'
    )
  );

-- Itinerary items: same membership check as trips
CREATE POLICY items_select ON itinerary_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM trips t
      LEFT JOIN trip_members tm ON tm.trip_id = t.id
      WHERE t.id = trip_id
        AND (t.visibility = 'public' OR tm.user_id = current_setting('app.user_id')::UUID)
    )
  );

-- Notifications: own only
CREATE POLICY notifs_own ON notifications FOR ALL
  USING (user_id = current_setting('app.user_id')::UUID);

-- ============================================================
--  SEED DATA (development only — remove for production)
-- ============================================================

INSERT INTO users (id, email, display_name, auth_provider, is_verified, reputation)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'demo@kumo.app', 'Demo User', 'email', true, 120),
  ('00000000-0000-0000-0000-000000000002', 'admin@kumo.app', 'Kumo Admin', 'email', true, 500);

-- ============================================================
--  END OF SCHEMA
-- ============================================================