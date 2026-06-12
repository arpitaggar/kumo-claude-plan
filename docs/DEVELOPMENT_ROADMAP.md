# Kumo Development Roadmap: 5-Stage Phased Plan

**Version:** 1.0  
**Target Launch:** Q3 2026  
**Current Stage:** Stage 1 (MVP Core) — In Development

---

## Executive Summary

Kumo will be delivered in 5 distinct, chronological phases, each with clear deliverables and "Definition of Done" criteria. This phased approach allows for rapid MVP launch, continuous user feedback integration, and de-risking of complex features (real-time sync, AI, fintech).

---

## Stage 1: MVP Core — Auth, Itinerary UI, Local Storage

**Duration:** Weeks 1–3  
**Team:** 2 Flutter Engineers (Frontend), 1 Backend Engineer (Supabase setup)

### Core Focus

Establish foundational infrastructure and deliver a barebone but functional travel planning app. Users can authenticate, create/view itineraries, and work offline.

### Key Features

- **Authentication:**
  - Sign up (email, password, optional phone MFA)
  - Login / logout
  - Password reset flow
  - Session persistence via JWT tokens
  - Secure token storage (Keychain/Keystore)

- **Itinerary Management:**
  - Create new itinerary (title, dates, budget)
  - View list of personal itineraries
  - View single itinerary detail
  - Edit itinerary metadata
  - Delete itinerary (with confirmation)
  - Add/remove basic activities to itinerary

- **Local Storage & Offline:**
  - Isar database for offline-first caching
  - Auto-sync when connection restored
  - Optimistic UI updates

- **UI/UX:**
  - Material 3 design system
  - Smooth navigation (go_router)
  - Loading, error, and empty states
  - Responsive layout (phone-first)
  - Accessibility (semantic labels, contrast ratios)

### Deliverables

1. **Infrastructure:**
   - Core error handling (Exception, Failure classes)
   - Supabase client initialization
   - Isar database setup and schema
   - Environment configuration (.env files)
   - Logger utility

2. **Auth Feature (Complete Triple-Layer):**
   - Domain: User entity, AuthRepository abstract class, login/signup/logout usecases
   - Data: Supabase datasource, UserModel, AuthRepositoryImpl
   - Presentation: Riverpod auth state provider, login page, signup page, password reset page

3. **Itinerary Feature (Phase 1):**
   - Domain: TravelItinerary entity, ItineraryRepository abstract class, basic usecases
   - Data: Supabase datasource, ItineraryModel, ItineraryRepositoryImpl
   - Presentation: Itinerary list page, itinerary detail page, basic add-activity modal

4. **App Setup:**
   - Riverpod configuration and providers
   - go_router navigation setup
   - App-level error handling
   - main.dart entry point

5. **Testing (Initial Suite):**
   - Auth repository unit tests (80%+ coverage)
   - Login page widget tests
   - Itinerary usecase tests
   - Sample test for local storage sync

6. **Documentation:**
   - Architecture overview
   - Local development setup guide
   - Contributing guidelines

### Definition of Done

- [ ] App compiles without warnings (`flutter analyze` passes)
- [ ] User can sign up and log in
- [ ] User can create, view, and edit personal itineraries
- [ ] Itineraries sync to Supabase (and back) when online
- [ ] Isar local cache works for offline access
- [ ] All Auth and Itinerary domain/data tests pass
- [ ] Screenshots/video demo showing login → create itinerary flow
- [ ] No secrets in code (use environment variables)
- [ ] Dependencies are pinned to exact versions
- [ ] `flutter test` runs and passes all tests

---

## Stage 2: Real-Time Social & Collaboration — Groups, Live Chat, Live Itinerary Sync

**Duration:** Weeks 4–6  
**Team:** 2 Flutter Engineers, 1 Backend Engineer, 1 DevOps (for Supabase realtime tuning)

### Core Focus

Enable multi-user collaboration on shared itineraries. Introduce group management, live chat, and conflict-free concurrent editing using event sourcing and vector clocks.

### Key Features

- **Group Management:**
  - Create groups (invite by email)
  - View group members (name, role, joined date)
  - Change member roles (viewer → editor, owner → admin)
  - Remove members from group
  - Transfer group ownership
  - Accept/decline group invitations

- **Shared Itineraries:**
  - Share itinerary with group (by link or member invitation)
  - Live, real-time sync of itinerary changes across group
  - Conflict resolution (vector clocks, event sourcing)
  - View who made which change (change history)
  - Revert to previous itinerary versions

- **Live Chat:**
  - Real-time messaging within group
  - Message history (paginated)
  - Typing indicators
  - Read receipts
  - Message search (phase 2.2)
  - Emoji reactions (phase 2.2)

- **Notifications (Basic):**
  - In-app notifications for group invites, messages, itinerary changes
  - Optional silent/sound alerts

### Deliverables

1. **Group Management Feature:**
   - Domain: Group entity, GroupRepository, invite/remove/role-change usecases
   - Data: Group table, GroupMember table, Supabase integration
   - Presentation: Group creation page, member list page, invitation page

2. **Real-Time Sync Engine:**
   - Event sourcing schema (itinerary_events table)
   - Vector clock implementation (Dart code)
   - Conflict resolution logic
   - Supabase real-time subscription setup
   - Reconciliation on reconnect

3. **Chat Feature:**
   - Domain: ChatMessage entity, ChatRepository, send/fetch/subscribe usecases
   - Data: Messages table, Supabase realtime subscription
   - Presentation: Chat page, message bubble widgets, input field

4. **Notification System:**
   - Local notification infrastructure
   - Notification types (invite, message, activity, etc.)
   - Notification center/history page

5. **Testing:**
   - Event sourcing unit tests (vector clock logic, conflict resolution)
   - Group repository tests
   - Chat message serialization tests
   - Real-time integration tests (mock Supabase)

6. **Documentation:**
   - Group Sync & Conflict Resolution deep-dive
   - Real-time architecture overview

### Definition of Done

- [ ] Multiple users can log in simultaneously (dev env)
- [ ] Shared itinerary changes appear in real-time on all clients
- [ ] Conflicting edits resolve deterministically (no data loss)
- [ ] Chat messages stream in real-time
- [ ] Invitations flow works end-to-end
- [ ] Offline edits reconcile when connection restored
- [ ] Vector clock tests pass (edge cases)
- [ ] No race conditions in collaborative scenarios
- [ ] Notifications pop correctly
- [ ] Performance: Sync latency <500ms

---

## Stage 3: Agentic AI Integration — Skeletal & Concierge Generation Engines

**Duration:** Weeks 7–9  
**Team:** 2 Flutter Engineers, 1 AI/Backend Engineer (LangChain/CrewAI setup), 1 Supabase DevOps

### Core Focus

Integrate AI-powered itinerary generation with two distinct user experiences: fast skeletal mode and intelligent concierge mode. Handle streaming responses, token management, and result caching.

### Key Features

- **Skeletal Mode:**
  - User selects destination, dates, rough budget
  - App generates basic daily outline in <1 second
  - User can customize/extend
  - No personalization, purely template-based
  - Free tier included in MVP

- **Concierge Mode:**
  - User provides detailed preferences (interests, dietary, group size, style)
  - App uses LLM (GPT-4 or Claude) + web search
  - Generates personalized, specific recommendations
  - Includes restaurant bookings, exact timings, cost breakdowns
  - Premium feature (paid)
  - Streaming response shown in real-time

- **Agentic AI (CrewAI/LangChain):**
  - Backend agents for trip research, cost estimation, local recommendations
  - Integration with booking APIs (Booking.com, Stripe)
  - Integration with maps/weather APIs
  - Result caching to reduce redundant API calls

- **User Feedback Loop:**
  - Iterative refinement ("add more nightlife", "reduce budget to $2k")
  - Non-destructive re-generation
  - Version comparison (show before/after)

### Deliverables

1. **AI Integration Layer:**
   - Supabase Edge Functions (TypeScript/Python) for LLM calls
   - LangChain or CrewAI setup for agentic reasoning
   - Streaming response handling in Flutter
   - API key and token management

2. **Skeletal Generation:**
   - Domain: SkeletalItinerary entity, AiRepository usecase
   - Data: Datasource for template-based generation (local or edge function)
   - Presentation: Generation options page, results display

3. **Concierge Generation:**
   - Domain: ConciergeItinerary entity, refinement usecase
   - Data: Supabase edge function integration, response streaming
   - Presentation: Detailed input form, streaming result display, refinement UI

4. **Result Caching & History:**
   - Cache generated itineraries by destination/params
   - Show user's generation history
   - Allow re-opening/sharing previous generations

5. **Testing:**
   - Mock AI responses for unit tests
   - Streaming response parsing tests
   - Cache invalidation tests
   - Error handling (API limits, timeouts)

6. **Documentation:**
   - AI architecture and LLM integration
   - Prompt engineering guide (internal)
   - Cost estimation for AI features

### Definition of Done

- [ ] Skeletal generation completes in <1 second
- [ ] Concierge generation completes in <30 seconds
- [ ] Streaming response renders in real-time on UI
- [ ] Iterative refinement works without full regeneration
- [ ] AI features gated behind user tier (free/premium)
- [ ] No API keys exposed in app code
- [ ] Cache reduces redundant calls by >80%
- [ ] Error states handled gracefully (API limits, network errors)
- [ ] Cost tracking for AI features (for billing)
- [ ] A/B test: compare skeletal vs. concierge user satisfaction

---

## Stage 4: Fintech & Advanced Features — Splitwise Clone, Virtual Debit Card, Kumo Ratings

**Duration:** Weeks 10–12  
**Team:** 2 Flutter Engineers, 1 Backend/Fintech Engineer (Stripe integration), 1 Data Engineer (ratings/analytics)

### Core Focus

Monetize and differentiate Kumo with fintech capabilities (virtual cards) and engagement tools (expense splitting, social ratings).

### Key Features

- **Expense Splitting (Splitwise Clone):**
  - Add expenses to itinerary (amount, category, payer, splitters)
  - Automatic calculation of who owes whom
  - Uneven splits (e.g., one person paid for 3 nights vs. 2 nights)
  - Payment settling (mark as "paid", record via Stripe)
  - History and receipts
  - CSV export for accounting

- **Virtual Debit Card (Stripe Issuing):**
  - Request temporary virtual card
  - Card details (masked) displayed in app
  - Spending controls (daily/monthly limits, merchant categories)
  - Real-time transaction notifications
  - Link card to group expenses (auto-settlement)
  - Card expiry and renewal

- **Kumo Ratings:**
  - Rate destinations (1-5 stars, comments)
  - Rate accommodations, restaurants, activities
  - Rate fellow travelers (collaboration feedback)
  - Leaderboards (most-traveled, best-rated locations)
  - Social sharing of ratings

- **Payment Integration:**
  - Stripe Connect for expense payouts
  - In-app payment gateway
  - Tax withholding for certain regions (future)

### Deliverables

1. **Expense Splitting Feature:**
   - Domain: Expense entity, ExpenseSplitter logic, ExpenseRepository
   - Data: Expenses table, splits table, Supabase integration
   - Presentation: Add expense page, expense summary, payment modal

2. **Virtual Card Integration:**
   - Domain: VirtualCard entity, Stripe Issuing integration
   - Data: Stripe API client, card datasource
   - Presentation: Card request flow, card details page, transaction history

3. **Kumo Ratings:**
   - Domain: Rating entity, RatingRepository
   - Data: Ratings table, aggregation views
   - Presentation: Rating pages, leaderboard page, rating cards

4. **Payment System:**
   - Stripe Connect setup (payments between users)
   - Transaction history and receipts
   - Tax compliance logging (UK VAT, US sales tax, etc.)

5. **Testing:**
   - Expense splitting math tests (edge cases: N users, uneven amounts)
   - Stripe mocking for payment tests
   - Rating aggregation tests

6. **Documentation:**
   - PCI-DSS compliance notes (fintech section)
   - Expense splitting algorithm
   - Payment flow diagrams

### Definition of Done

- [ ] Users can add expenses and splits are calculated correctly
- [ ] Payment settling works end-to-end (test mode with Stripe)
- [ ] Virtual card can be requested and displayed
- [ ] Card spending limits enforced correctly
- [ ] Ratings persist and display on destinations/accommodations
- [ ] Leaderboards generate and update correctly
- [ ] Expense math tests pass (esp. uneven splits, N-person groups)
- [ ] No financial data stored unencrypted
- [ ] PCI-DSS compliance checklist signed off
- [ ] MVP monetization plan in place (premium tiers, card fees)

---

## Stage 5: Social Feed, Gamification & B2B Portal Scaffolding

**Duration:** Weeks 13–16  
**Team:** 2 Flutter Engineers, 1 Backend Engineer (B2B/multi-tenant), 1 Designer (social UI)

### Core Focus

Expand Kumo into a social platform and prepare infrastructure for B2B (corporate travel portal). Gamification drives engagement; B2B scaffolding enables enterprise contracts.

### Key Features

- **Social Travel Feed:**
  - Publish itineraries to public feed (opt-in)
  - Discovery page (trending destinations, friend activities, suggestions)
  - Like, comment, share itineraries
  - Follow other travelers
  - Trip recommendations based on followers' activity

- **Gamification:**
  - Achievement badges ("First International Trip", "Budget Master", etc.)
  - Experience points (XP) for itinerary creation, expense logging, ratings
  - Seasonal challenges ("Visit 5 new countries", "Try 10 new restaurants")
  - Leaderboards (global, regional, friend groups)
  - Rewards (exclusive discounts, premium features)

- **B2B Portal Scaffolding:**
  - Multi-tenant organization support
  - Corporate account creation and verification
  - Employee onboarding and role management
  - Travel policy engine (e.g., max hotel rate, approved vendors)
  - Automated expense reporting for finance teams
  - Integration with corporate SSO (OAuth2, SAML)
  - Admin dashboard (org analytics, policy management)

- **Analytics & Insights:**
  - Personal trip statistics (distance, cost, duration)
  - Group spending trends
  - Corporate spend reports (for B2B)
  - Feedback collection and surveys

### Deliverables

1. **Social Feed Feature:**
   - Domain: FeedPost entity, SocialRepository, follow/like/comment usecases
   - Data: Feed tables, engagement tables, discovery algorithm
   - Presentation: Feed page, profile page, discovery page

2. **Gamification System:**
   - Domain: Achievement entity, UserStats, Challenge entities
   - Data: Achievements table, user_stats table, challenge_progress table
   - Presentation: Badges display, leaderboard page, achievement notifications

3. **B2B Portal (MVP):**
   - Domain: Organization entity, OrgMember entity, TravelPolicy entity
   - Data: Multi-tenant schema (orgs, org_members, policies, audit_log)
   - Presentation: Organization admin dashboard, member management page, policy editor (MVP)
   - Backend: Multi-tenancy RLS policies, organization-scoped API

4. **Analytics:**
   - User activity tracking (non-invasive, privacy-respecting)
   - Trip statistics aggregation
   - Spend trend analysis
   - Corporate spend reports for B2B

5. **Testing:**
   - Social feature integration tests
   - Gamification math tests (XP calculation, leaderboard ranking)
   - Multi-tenant isolation tests (org A can't see org B's data)
   - B2B policy enforcement tests

6. **Documentation:**
   - Social feed architecture
   - B2B scalability plan
   - Multi-tenant schema design
   - Privacy and data retention policies

### Definition of Done

- [ ] Users can publish trips and view social feed
- [ ] Achievements award correctly based on user activity
- [ ] Leaderboards generate and rank users correctly
- [ ] Multi-tenant schema implemented and tested for isolation
- [ ] Corporate accounts can be created and managed
- [ ] Travel policies can be created, edited, and enforced
- [ ] Expense reports auto-generate for B2B users
- [ ] Admin dashboard displays org analytics
- [ ] All social/gamification features have >75% test coverage
- [ ] Privacy audit passed (GDPR, CCPA compliance)
- [ ] B2B onboarding flow tested with pilot customer

---

## Cross-Stage Considerations

### Quality Gates (All Stages)

- **Code Review:** Every PR requires 2 approvals
- **Testing:** Minimum 70% code coverage (domain/data layers)
- **Performance:** No screen should take >1s to render; API calls <2s
- **Accessibility:** WCAG 2.1 AA compliance for UI
- **Security:** No secrets in code, HTTPS only, token expiry enforced
- **Documentation:** Dartdoc on all public APIs, architecture decisions logged

### Dependency Pinning & Versioning

- All dependencies pinned to exact versions in `pubspec.yaml`
- Monthly dependency updates reviewed for security/bug fixes
- Breaking changes tagged and documented

### Deployment & Rollout

| Stage | Deployment Target | Rollout Strategy |
|-------|-------------------|------------------|
| 1–2 | Internal testing, TestFlight | 10% → 50% → 100% (phased) |
| 3 | App Store Beta | Limited beta (500 users) |
| 4 | App Store Production | General release |
| 5 | B2B Pilot | 3–5 pilot customers; feedback loop |

### Success Metrics per Stage

| Stage | Metric | Target |
|-------|--------|--------|
| 1 | User signups, retention day 3 | 500 users, 30% day-3 retention |
| 2 | Group creation rate, chat volume | 60% of users create group, 1M messages/week |
| 3 | AI generation usage, tier conversion | 80% use Concierge, 5% convert to premium |
| 4 | Virtual cards issued, expense split volume | 100 cards/week, $50k/month split |
| 5 | Social engagement, B2B pipeline | 1k published trips, 10 B2B pilot signups |

---

## Risk & Mitigation

| Risk | Stage | Mitigation |
|------|-------|-----------|
| Real-time sync race conditions | 2 | Event sourcing + vector clocks + extensive testing |
| AI generation cost overruns | 3 | Caching, rate limiting, free tier with limits |
| Fintech compliance complexity | 4 | PCI audit early, Stripe's managed solution, legal review |
| User churn post-launch | All | Regular engagement surveys, community management |
| B2B sales cycle length | 5 | Early pilot customer engagement, product-market fit in SMB |

---

## Timeline Overview

```
Jun 2026          Jul 2026          Aug 2026          Sep 2026
|--------S1--------|--------S2--------|--------S3--------|--------S4/5--------|
Week 1-3       Week 4-6       Week 7-9      Week 10-12    Week 13-16
MVP Core   Collaboration    AI            Fintech       Social & B2B
```

---

## Next Steps (After Stage 1)

1. **Gather feedback** from Stage 1 users
2. **Prioritize backlog** for Stage 2 based on engagement metrics
3. **Begin hiring** backend AI specialist (3 weeks before Stage 3)
4. **Partner outreach** for fintech integrations (Stripe, etc.)
5. **B2B discovery calls** with target customers (4+ months before Stage 5)

---

**End of Development Roadmap**
