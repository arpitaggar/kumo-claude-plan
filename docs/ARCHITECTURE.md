# Kumo Super-App: Technical Architecture Document

**Version:** 1.0  
**Last Updated:** June 2026  
**Status:** Production-Ready Design (Stage 1 MVP)

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Real-Time Group Sync & Collaborative Editing](#real-time-group-sync--collaborative-editing)
3. [Security Architecture](#security-architecture)
4. [Future B2B Scalability Plan](#future-b2b-scalability-plan)
5. [API Contract Specification](#api-contract-specification)
6. [Deployment & Infrastructure](#deployment--infrastructure)

---

## System Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         KUMO ECOSYSTEM                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐                                                    │
│  │  Flutter App │ (iOS, Android)                                     │
│  └──────┬───────┘                                                    │
│         │                                                            │
│         ├─── [JWT Token] ────────────────┐                          │
│         │                                │                          │
│         ▼                                ▼                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐        │
│  │  Riverpod State Mgmt     │  │   Supabase Platform      │        │
│  ├──────────────────────────┤  ├──────────────────────────┤        │
│  │ • Async providers        │  │ • Auth (JWT + MFA)       │        │
│  │ • Cache invalidation     │  │ • PostgreSQL (realtime)  │        │
│  │ • Reactive dependencies  │  │ • Storage (avatar, docs) │        │
│  └──────────────────────────┘  │ • Websockets (realtime)  │        │
│         ▲                       │ • Edge Functions (AI)    │        │
│         │                       │ • Policies (RLS)         │        │
│         └───────────────────────┤ • CDN + Backups          │        │
│                                 └──────────────────────────┘        │
│         ▼                                                            │
│  ┌──────────────────────────┐  ┌──────────────────────────┐        │
│  │  Isar Local DB           │  │  Third-Party Integrations│        │
│  ├──────────────────────────┤  ├──────────────────────────┤        │
│  │ • Offline-first cache    │  │ • Stripe Issuing (Cards) │        │
│  │ • Indexed queries        │  │ • OpenAI / Claude API    │        │
│  │ • Sync when online       │  │ • Booking.com, Airbnb    │        │
│  └──────────────────────────┘  │ • Google Maps / Weather  │        │
│                                 └──────────────────────────┘        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. **Flutter Frontend (iOS/Android)**
- **State Management:** Riverpod (functional, reactive, testable)
- **Navigation:** go_router (declarative, deep-linking capable)
- **UI Framework:** Material 3 (Material Design)
- **Offline Support:** Isar local database + Riverpod cache

#### 2. **Supabase Backend**
- **Authentication:** JWT with optional MFA (phone/TOTP)
- **Database:** PostgreSQL with Row-Level Security (RLS) policies
- **Real-Time Engine:** WebSocket subscription for collaborative updates
- **Storage:** File uploads (trip photos, receipts)
- **Edge Functions:** TypeScript/Python for AI orchestration, Stripe webhooks

#### 3. **Isar Local Database**
- **Purpose:** Offline-first cache for itineraries, chats, expense history
- **Sync Strategy:** Optimistic updates locally, reconcile with server on reconnect
- **Data:** Itineraries, messages, transactions, user preferences

#### 4. **Third-Party Integrations**
- **Fintech:** Stripe Issuing (virtual debit cards)
- **AI:** OpenAI GPT-4 or Anthropic Claude (via Supabase Edge Functions)
- **Travel:** Booking.com API, Airbnb Web Scraping
- **Maps:** Google Maps (routes, places, distance matrix)
- **Social:** Firebase Messaging (optional) for push notifications

---

## Real-Time Group Sync & Collaborative Editing

### Challenge: Race Conditions in Collaborative Itineraries

When multiple users edit an itinerary simultaneously (e.g., adding activities), we must prevent:
- **Lost updates:** User A's activity overwritten by User B
- **Data corruption:** Partial updates creating invalid state
- **Stale reads:** UI showing outdated information after network reconnect

### Solution: Event Sourcing + Vector Clocks

#### 1. **Event Sourcing (Append-Only Log)**

Every change to an itinerary is immutable:

```sql
-- Table: itinerary_events
CREATE TABLE itinerary_events (
  id UUID PRIMARY KEY,
  itinerary_id UUID NOT NULL,
  event_type VARCHAR (50) NOT NULL,
  -- event_type: 'ACTIVITY_ADDED', 'ACTIVITY_UPDATED', 'ACTIVITY_REMOVED'
  payload JSONB NOT NULL,
  user_id UUID NOT NULL,
  vector_clock JSONB NOT NULL,
  -- Format: { "user_1": 5, "user_2": 3 }
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Example Payload:**
```json
{
  "event_type": "ACTIVITY_ADDED",
  "activity": {
    "id": "act_123",
    "title": "Senso-ji Temple Visit",
    "startTime": "2026-06-10T10:00:00Z",
    "endTime": "2026-06-10T12:00:00Z",
    "location": "Asakusa, Tokyo"
  },
  "user_id": "user_alice"
}
```

#### 2. **Vector Clocks (Causality Tracking)**

Each event carries a vector clock encoding the sender's logical view of all users' versions:

```dart
// Dart representation
class VectorClock {
  final Map<String, int> clocks; // { user_id: event_count }

  /// Increment this user's clock and apply incoming updates
  VectorClock merge(VectorClock incoming) {
    final merged = Map<String, int>.from(clocks);
    incoming.clocks.forEach((user, count) {
      merged[user] = max(merged[user] ?? 0, count);
    });
    return VectorClock(merged);
  }

  /// True if event1 happened before event2
  static bool happenedBefore(VectorClock vc1, VectorClock vc2) {
    bool atLeastOneLess = false;
    for (final user in vc1.clocks.keys.toSet()..addAll(vc2.clocks.keys)) {
      final c1 = vc1.clocks[user] ?? 0;
      final c2 = vc2.clocks[user] ?? 0;
      if (c1 > c2) return false;
      if (c1 < c2) atLeastOneLess = true;
    }
    return atLeastOneLess;
  }
}
```

#### 3. **Conflict Resolution (Operational Transformation Lite)**

When events arrive out-of-order:

```dart
// Client receives: Event A (add activity), Event B (remove activity)
// But user hasn't acknowledged Event A yet

Future<void> reconcileConflict(
  ItineraryEvent localEvent,
  ItineraryEvent remoteEvent,
) async {
  // If remote event causally depends on local:
  if (VectorClock.happenedBefore(
    localEvent.vectorClock,
    remoteEvent.vectorClock,
  )) {
    // Apply remote transformation
    await _applyEventToLocalItinerary(remoteEvent);
  } else if (VectorClock.happenedBefore(
    remoteEvent.vectorClock,
    localEvent.vectorClock,
  )) {
    // Remote happened first; re-apply local on top
    await _replayLocalEvent(localEvent, remoteEvent);
  } else {
    // Concurrent edits: use deterministic tie-breaker (user ID hash)
    final localUserId = localEvent.userId;
    final remoteUserId = remoteEvent.userId;
    if (localUserId.hashCode < remoteUserId.hashCode) {
      await _applyEventToLocalItinerary(localEvent);
    } else {
      await _applyEventToLocalItinerary(remoteEvent);
    }
  }
}
```

#### 4. **Supabase Realtime Integration**

```dart
// Subscribe to itinerary changes
final subscription = supabase
    .from('itinerary_events')
    .on(SupabaseEventTypes.insert, (payload) {
      final event = ItineraryEvent.fromJson(payload.newRecord);
      reconcileConflict(localEvent: _pendingLocalEvent, remoteEvent: event);
    })
    .subscribe();
```

#### 5. **Client-Side Optimistic Updates**

```dart
// User adds activity locally immediately
final tempEvent = ItineraryEvent(
  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
  eventType: 'ACTIVITY_ADDED',
  payload: newActivity,
  userId: currentUserId,
  vectorClock: currentVectorClock.increment(currentUserId),
);

// Update UI instantly
isarDb.writeTxn(() async {
  await isarDb.itineraryEvents.put(tempEvent);
});

// Optimistically update local itinerary display
emit(ItineraryLoaded(itinerary: _applyEventLocally(tempEvent)));

// Send to server asynchronously
try {
  final response = await supabase
      .from('itinerary_events')
      .insert(tempEvent.toJson());
  
  // Server assigns real ID, we replace temp ID
  await isarDb.writeTxn(() async {
    await isarDb.itineraryEvents.delete(tempEvent.id.hashCode);
    await isarDb.itineraryEvents.put(
      tempEvent.copyWith(id: response.id),
    );
  });
} catch (e) {
  // Rollback local changes on failure
  emit(ItineraryError('Failed to sync: $e'));
}
```

---

## Security Architecture

### 1. **Authentication & Authorization**

#### JWT Token Flow

```
User Login
  ↓
[POST /auth/login { email, password }]
  ↓
Supabase Auth validates credentials
  ↓
Returns: { access_token, refresh_token, user }
  ↓
Flutter stores access_token in secure Keychain/Keystore
  ↓
All subsequent requests include: Authorization: Bearer {access_token}
```

#### Row-Level Security (RLS) Policies

```sql
-- Users can only see their own profile
CREATE POLICY "users_self_select" ON users
  FOR SELECT USING (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "users_self_update" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Users can view itineraries they own OR are invited to
CREATE POLICY "itineraries_visibility" ON itineraries
  FOR SELECT USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT itinerary_id FROM group_members WHERE user_id = auth.uid()
    )
  );

-- Users can only edit itineraries they own or are editors in
CREATE POLICY "itineraries_edit" ON itineraries
  FOR UPDATE USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT itinerary_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'editor'
    )
  );
```

### 2. **Financial Data Security (PCI Compliance)**

#### Stripe Issuing Integration (No PCI Scope)

**Why not store card data locally:**
- Kumo never handles raw card numbers, CVVs, or expiration dates
- All sensitive data stays within Stripe's PCI-compliant vaults

**Card Issuance Flow:**

```
User requests temporary debit card
  ↓
Kumo backend calls Stripe Issuing API
  [POST /v1/issuing/cards {
    type: "physical" | "virtual",
    currency: "USD",
    spending_controls: { ... },
    cardholder_id: "ich_...",
    product_id: "virtual"
  }]
  ↓
Stripe returns: { id, number, exp_month, exp_year, cvc, status }
  ↓
Kumo stores ONLY: card_id, status, spending_limits, expiry_date
  ↓
Kumo returns masked card to Flutter app
  [{ last4: "4242", brand: "visa", expiry: "12/26" }]
  ↓
Card details displayed in app (unencrypted because they're masked)
```

**Spending Controls:**

```json
{
  "spending_limits": [
    {
      "interval": "daily",
      "amount": 5000
    },
    {
      "interval": "monthly",
      "amount": 50000
    }
  ],
  "allowed_categories": ["travel", "lodging", "gas_stations"],
  "blocked_merchants": ["..."license_alcohol"]
}
```

### 3. **Encryption at Rest & In Transit**

#### Database Encryption (Supabase)
- **Storage:** All rows encrypted with AES-256 at the filesystem level (AWS RDS)
- **Backups:** Encrypted S3 backups with separate key management

#### In-Transit Encryption
- **API Calls:** TLS 1.3 (HTTPS only, no HTTP fallback)
- **Websockets:** WSS (Secure WebSocket, not WS)

#### End-to-End Encryption (Chats)
```dart
// Stage 2+: Implement E2E encryption for sensitive messages
// Using libsodium (Dart: `sodium` package)

class ChatMessage {
  final String id;
  final String fromUserId;
  final String toGroupId;
  final String encryptedContent;  // Encrypted with group's public key
  final String nonce;              // Randomness for encryption
  final DateTime createdAt;

  /// Encrypt message content with group's public key
  static Future<ChatMessage> create(
    String content,
    String fromUserId,
    String toGroupId,
    List<int> groupPublicKey,
  ) async {
    final nonce = randombytes(Sodium.crypto_secretbox_NONCEBYTES);
    final encrypted = Sodium.crypto_secretbox(
      utf8.encode(content),
      nonce,
      groupPublicKey,
    );
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      fromUserId: fromUserId,
      toGroupId: toGroupId,
      encryptedContent: base64Encode(encrypted),
      nonce: base64Encode(nonce),
      createdAt: DateTime.now(),
    );
  }
}
```

### 4. **Compliance & Audit Logging**

```sql
-- Immutable audit log for financial transactions
CREATE TABLE audit_log (
  id UUID PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL,
  -- 'CARD_ISSUED', 'TRANSACTION_AUTHORIZED', 'EXPENSE_SPLIT', etc.
  user_id UUID NOT NULL,
  resource_id VARCHAR(255) NOT NULL,
  -- itinerary_id, card_id, expense_id, etc.
  changes JSONB NOT NULL,
  ip_address INET,
  user_agent TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for quick lookups
CREATE INDEX idx_audit_user_timestamp ON audit_log (user_id, timestamp DESC);
```

---

## Future B2B Scalability Plan

### Multi-Tenant Architecture

#### 1. **Organization & Workspace Model**

```sql
-- Organizations (companies)
CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  -- "acme-corp", "startup-xyz"
  subscription_tier VARCHAR(50) DEFAULT 'free',
  -- free, pro, enterprise
  owner_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Organization members and roles
CREATE TABLE org_members (
  id UUID PRIMARY KEY,
  org_id UUID NOT NULL REFERENCES organizations(id),
  user_id UUID NOT NULL REFERENCES users(id),
  role VARCHAR(50) NOT NULL,
  -- 'owner', 'admin', 'manager', 'employee'
  permissions JSONB DEFAULT '{}',
  -- Custom permissions per role
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (org_id, user_id)
);

-- Tenant-scoped itineraries
ALTER TABLE itineraries ADD COLUMN org_id UUID REFERENCES organizations(id);
-- If org_id is NULL: personal itinerary
-- If org_id is set: corporate itinerary
```

#### 2. **Policy Compliance Engine**

```dart
// Stage 5+: Policy enforcement for corporate trips

class TravelPolicy {
  final String id;
  final String orgId;
  final String name;
  final Map<String, dynamic> rules;
  // {
  //   "max_hotel_rate_per_night": 300,
  //   "max_flights_per_day": 3,
  //   "require_manager_approval": true,
  //   "allowed_booking_partners": ["booking.com", "expedia.com"],
  //   "blocked_destinations": ["countries_list"]
  // }
  final DateTime effectiveDate;

  /// Check if proposed itinerary violates policy
  bool violatesPolicy(Itinerary itinerary) {
    if (rules['max_hotel_rate_per_night'] != null) {
      for (final booking in itinerary.accommodations) {
        if (booking.pricePerNight > rules['max_hotel_rate_per_night']) {
          return true;
        }
      }
    }
    return false;
  }
}
```

#### 3. **Automated Expense Reporting**

```dart
// Generate compliance reports for finance/accounting teams

class ExpenseReport {
  final String id;
  final String orgId;
  final String itineraryId;
  final List<Expense> expenses;
  final String reportingPeriod; // "2026-Q2"
  final Map<String, double> expenseByCategory;
  // { "flights": 1200.00, "hotels": 2100.00, "meals": 450.00 }
  
  Future<String> exportToCSV() async {
    // Generate exportable CSV for finance system
    final buffer = StringBuffer('Date,Category,Amount,Status,Approval\n');
    for (final expense in expenses) {
      buffer.writeln(
        '${expense.date},${expense.category},${expense.amount},'
        '${expense.status},${expense.approverName}',
      );
    }
    return buffer.toString();
  }

  Future<void> syncToAccounting(AccountingAPI api) async {
    // Integrate with QuickBooks, SAP, or other ERP
    await api.submitExpenseReport(this);
  }
}
```

#### 4. **Tenant Data Isolation (RLS + Partitioning)**

```sql
-- RLS policy: Users can only see data from orgs they belong to
CREATE POLICY "org_isolation" ON itineraries
  FOR SELECT USING (
    org_id IS NULL AND owner_id = auth.uid()
    OR org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );

-- Partition tables by org_id for performance at scale
CREATE TABLE itineraries_partitioned
  PARTITION BY LIST (org_id)
AS SELECT * FROM itineraries;

CREATE TABLE itineraries_default PARTITION OF itineraries_partitioned DEFAULT;
-- Create individual partitions for high-volume orgs
```

---

## API Contract Specification

### Supabase Edge Functions

#### 1. **AI Itinerary Generation (Skeletal Mode)**

```typescript
// functions/generate_itinerary_skeletal/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  const { trip_date_start, trip_date_end, destination, budget, interests } =
    await req.json();

  const template = {
    day_1: [
      { time: "09:00", activity: "Arrive & check-in", duration_mins: 60 },
      { time: "13:00", activity: "Lunch", duration_mins: 60 },
      { time: "15:00", activity: "Explore city center", duration_mins: 120 },
    ],
    day_2: [
      { time: "10:00", activity: "Museum visit", duration_mins: 180 },
      { time: "14:00", activity: "Lunch", duration_mins: 60 },
      { time: "18:00", activity: "Dinner & evening stroll", duration_mins: 120 },
    ],
  };

  return new Response(JSON.stringify(template), {
    headers: { "Content-Type": "application/json" },
  });
});
```

#### 2. **AI Itinerary Generation (Concierge Mode)**

```typescript
// functions/generate_itinerary_concierge/index.ts
import { Anthropic } from "https://npm.io/@anthropic-ai/sdk@0.10.0";

const client = new Anthropic();

serve(async (req: Request) => {
  const { destination, budget, interests, num_days } = await req.json();

  const stream = await client.messages.stream({
    model: "claude-opus",
    max_tokens: 2000,
    messages: [
      {
        role: "user",
        content: `Create a detailed ${num_days}-day itinerary for ${destination}. Budget: $${budget}. Interests: ${interests.join(", ")}. Return valid JSON.`,
      },
    ],
  });

  return stream.toResponse();
});
```

### REST Endpoints (Supabase Auto-Generated via PostgREST)

All endpoints require `Authorization: Bearer {access_token}`.

#### Itinerary CRUD

```
GET    /rest/v1/itineraries?select=*&owner_id=eq.{user_id}
POST   /rest/v1/itineraries
PATCH  /rest/v1/itineraries?id=eq.{id}
DELETE /rest/v1/itineraries?id=eq.{id}
```

#### Real-Time Subscriptions

```dart
final subscription = supabase
    .from('itinerary_events')
    .on(SupabaseEventTypes.insert, (payload) {
      // Handle new event
    })
    .subscribe();
```

---

## Deployment & Infrastructure

### Deployment Pipeline

```
┌──────────────────┐
│  Developer Push  │
│   to main/dev    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   GitHub Actions │
│  (build, test)   │
└────────┬─────────┘
         │
         ├─ Android Build → Firebase App Distribution
         ├─ iOS Build → TestFlight
         └─ Backend → Supabase Staging
         │
         ▼
┌──────────────────┐
│  Manual Approval │
│  (release lead)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Production      │
│  Release         │
│  (App Stores)    │
└──────────────────┘
```

### Environment Configuration

```
.env.development
  SUPABASE_URL=https://xxxxx.supabase.co
  SUPABASE_KEY=eyJhbGciOiJIUzI1NiIs...
  STRIPE_PUBLISHABLE_KEY=pk_test_...

.env.staging
  SUPABASE_URL=https://staging-xxxxx.supabase.co
  SUPABASE_KEY=...

.env.production
  SUPABASE_URL=https://xxxxx.supabase.co
  SUPABASE_KEY=...
  STRIPE_PUBLISHABLE_KEY=pk_live_...
```

---

## References & Further Reading

- Supabase Real-Time Concepts: https://supabase.com/docs/guides/realtime
- Event Sourcing Pattern: https://martinfowler.com/eaaDev/EventSourcing.html
- Vector Clocks: https://en.wikipedia.org/wiki/Vector_clock
- PCI-DSS Compliance: https://www.pcisecuritystandards.org/
- Flutter Clean Architecture: https://resocoder.com/flutter-clean-architecture

---

**End of Architecture Document**
