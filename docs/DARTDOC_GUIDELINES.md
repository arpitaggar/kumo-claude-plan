# Dartdoc Guidelines & In-Code Documentation Standards

**For:** Kumo Super-App Flutter Project  
**Last Updated:** June 2026

---

## Table of Contents

1. [Dartdoc Syntax Overview](#dartdoc-syntax-overview)
2. [Documentation Best Practices](#documentation-best-practices)
3. [Example: TravelItinerary Data Model](#example-travelitinerary-data-model)
4. [Example: AiItineraryRepository Abstract Class](#example-aiitineraryrepository-abstract-class)
5. [Common Patterns & Templates](#common-patterns--templates)

---

## Dartdoc Syntax Overview

Dartdoc is Dart's standard documentation format using triple-slash `///` comments. It supports **Markdown** for rich formatting.

### Basic Structure

```dart
/// Brief one-line summary of the class/method.
///
/// Longer description with more context and details.
/// Can span multiple lines. Supports **bold**, *italic*, [links].
///
/// Example:
/// ```dart
/// final itinerary = TravelItinerary(
///   title: 'Tokyo Trip',
///   startDate: DateTime(2026, 6, 10),
/// );
/// ```
class MyClass {
  // implementation
}
```

### Key Documentation Markers

| Marker | Usage | Example |
|--------|-------|---------|
| `///` | Documentation comment | `/// This method does X` |
| `@param` | Parameter documentation | `@param userId The unique user identifier` |
| `@return` / `@returns` | Return value documentation | `@returns Future<Itinerary> The created itinerary` |
| `@throws` | Exception documentation | `@throws UnauthorizedException if user is not authenticated` |
| `{@template name}` | Reusable doc snippets | Can reference with `{@macro name}` |
| `[ClassName]` | Cross-reference to class | `[TravelItinerary] for more details` |

---

## Documentation Best Practices

### 1. **All Public APIs Must Be Documented**

```dart
// ❌ BAD: No documentation
class AuthRepository {
  Future<User> login(String email, String password) async { }
}

// ✅ GOOD: Comprehensive documentation
/// Repository for user authentication operations.
///
/// Handles login, signup, token refresh, and logout flows.
/// Uses Supabase as the backend authentication provider.
class AuthRepository {
  /// Authenticates a user with email and password.
  ///
  /// @param email The user's email address
  /// @param password The user's plaintext password (encrypted over TLS)
  ///
  /// @returns A [Future] that resolves to the authenticated [User]
  ///
  /// @throws [UnauthorizedException] if credentials are invalid
  /// @throws [NetworkException] if backend is unreachable
  /// @throws [ServerException] if backend returns a 5xx error
  ///
  /// Example:
  /// ```dart
  /// final user = await authRepository.login(
  ///   'user@example.com',
  ///   'securePassword123',
  /// );
  /// print(user.name); // Output: John Doe
  /// ```
  Future<User> login(String email, String password) async { }
}
```

### 2. **Parameters, Returns, and Exceptions**

```dart
/// Calculates the total expense for a trip, including tips.
///
/// @param baseAmount The base cost before tip
/// @param tipPercentage The tip as a percentage (0-100)
/// @param currencyCode ISO 4217 currency code (e.g., 'USD', 'JPY')
///
/// @returns The total amount as a [double], rounded to 2 decimal places
///
/// @throws [ArgumentError] if baseAmount is negative
/// @throws [ArgumentError] if tipPercentage is not between 0-100
/// @throws [FormatException] if currencyCode is not a valid ISO 4217 code
double calculateTotalWithTip(
  double baseAmount,
  double tipPercentage,
  String currencyCode,
) {
  // implementation
}
```

### 3. **Use Markdown for Rich Formatting**

```dart
/// Generates an AI-powered itinerary using one of two modes.
///
/// ## Skeletal Mode
/// Fast, template-based generation. Returns a basic structure in seconds.
/// Best for: Quick previews, limited API budget.
///
/// ## Concierge Mode
/// Full LLM-powered generation with web search and personalization.
/// Best for: Premium users, highly customized trips.
///
/// **Warning:** Concierge mode may incur higher API costs.
///
/// See also: [SkeletalAiMode] and [ConciergeAiMode]
Future<Itinerary> generateItinerary({
  required AiModeEnum mode,
  required String destination,
}) async { }
```

### 4. **Cross-References and Links**

```dart
/// Splits an expense among group members.
///
/// See [ExpenseSplitter] for the domain logic,
/// [SplitExpenseUsecase] for the use case,
/// and [ExpenseRepository] for persistence.
///
/// Related: [calculateTotalWithTip], [validateAmount]
///
/// For more details, refer to the [ARCHITECTURE.md] document.
class SplitExpenseEntity { }
```

### 5. **Deprecated Items**

```dart
/// **Deprecated:** Use [newCalculateTotal] instead.
/// This method will be removed in version 2.0.
@Deprecated('Use newCalculateTotal instead. Removed in 2.0.')
double calculateTotal(double amount) { }
```

---

## Example: TravelItinerary Data Model

```dart
/// Represents a complete travel itinerary for a group or individual.
///
/// An itinerary is the core entity in Kumo, containing all trip details:
/// destinations, dates, activities, accommodations, and expense tracking.
///
/// ## Structure
/// - **Metadata:** ID, title, owner, creation date
/// - **Trip Details:** Start/end dates, destinations, budget
/// - **Collaborators:** Group members with roles (viewer, editor, owner)
/// - **Content:** Activities, accommodations, transportation, notes
/// - **Financial:** Budget, expenses, splits, payment status
///
/// ## Lifecycle
/// 1. Create: User creates new itinerary or is invited to existing one
/// 2. Edit: Collaborative editing with real-time sync (see [ARCHITECTURE.md])
/// 3. Execute: Trip happens, expenses are logged
/// 4. Archive: After trip ends, itinerary moves to archive
///
/// @see [ItineraryRepository] for database operations
/// @see [ItineraryEvent] for change tracking via event sourcing
class TravelItinerary {
  /// Unique identifier for this itinerary (UUID format).
  ///
  /// @example "550e8400-e29b-41d4-a716-446655440000"
  final String id;

  /// Title/name of the trip.
  ///
  /// Examples: "Tokyo Summer 2026", "Paris Honeymoon"
  /// Constraints: 1-255 characters, non-empty
  final String title;

  /// Brief description of the trip's purpose and highlights.
  ///
  /// Constraints: 0-2000 characters
  /// Example: "A week exploring Tokyo temples, museums, and nightlife"
  final String? description;

  /// UUID of the user who created/owns this itinerary.
  ///
  /// The owner can transfer ownership to another group member.
  /// @see [transferOwnership]
  final String ownerId;

  /// UTC date when the trip starts.
  ///
  /// Constraints: Must be after [createdAt], typically in the future
  final DateTime startDate;

  /// UTC date when the trip ends.
  ///
  /// Constraints: Must be after [startDate], cannot be more than 1 year in future
  final DateTime endDate;

  /// Total trip budget in the specified currency.
  ///
  /// @param None (read-only after creation; modify via [updateBudget])
  /// @example 5000.00 (in USD)
  /// Constraints: Non-negative, max 999,999.99
  final double totalBudget;

  /// ISO 4217 currency code for all amounts in this itinerary.
  ///
  /// Examples: "USD", "JPY", "EUR"
  /// Immutable after creation.
  final String currencyCode;

  /// List of group members invited to this itinerary.
  ///
  /// Each member has a [GroupMember] entity with role and permissions.
  /// @see [GroupMember]
  /// @see [addMember]
  /// @see [removeMember]
  final List<GroupMember> members;

  /// Ordered list of daily activities and bookings.
  ///
  /// Sorted chronologically by [ItineraryItem.startTime].
  /// Each item can be an activity, accommodation, flight, etc.
  final List<ItineraryItem> items;

  /// Summary of expenses split among group members.
  ///
  /// Updated in real-time as new expenses are added.
  /// @see [ExpenseSplitter]
  final ExpenseSummary expenseSummary;

  /// Timestamp when this itinerary was created (UTC).
  ///
  /// Set automatically by backend; not user-modifiable.
  final DateTime createdAt;

  /// Timestamp when this itinerary was last modified (UTC).
  ///
  /// Updated automatically whenever any field changes.
  final DateTime updatedAt;

  /// Status of the itinerary.
  ///
  /// - `draft`: In preparation, not yet shared
  /// - `active`: Trip is happening or upcoming
  /// - `completed`: Trip has finished
  /// - `archived`: Moved to archive by user
  final ItineraryStatusEnum status;

  /// Constructor for creating a new [TravelItinerary].
  ///
  /// @param id Unique identifier (generated by backend if omitted)
  /// @param title The name of the trip
  /// @param startDate When the trip begins
  /// @param endDate When the trip ends
  /// @param ownerId UUID of the owner
  /// @param members Initial group members (can be empty)
  /// @param items Initial itinerary items (can be empty)
  /// @param totalBudget Total trip budget
  /// @param currencyCode ISO currency code
  /// @param status Initial status (default: draft)
  ///
  /// @throws [ArgumentError] if title is empty
  /// @throws [ArgumentError] if startDate is after endDate
  /// @throws [ArgumentError] if totalBudget is negative
  /// @throws [FormatException] if currencyCode is invalid
  ///
  /// Example:
  /// ```dart
  /// final itinerary = TravelItinerary(
  ///   id: '550e8400-e29b-41d4-a716-446655440000',
  ///   title: 'Tokyo Summer 2026',
  ///   startDate: DateTime(2026, 6, 10),
  ///   endDate: DateTime(2026, 6, 17),
  ///   ownerId: 'user_alice',
  ///   totalBudget: 5000.00,
  ///   currencyCode: 'USD',
  ///   members: [...],
  ///   items: [...],
  /// );
  /// ```
  const TravelItinerary({
    required this.id,
    required this.title,
    this.description,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.totalBudget,
    required this.currencyCode,
    required this.members,
    required this.items,
    required this.expenseSummary,
    required this.createdAt,
    required this.updatedAt,
    this.status = ItineraryStatusEnum.draft,
  });

  /// Validates the itinerary before saving.
  ///
  /// Checks:
  /// - Non-empty title and description
  /// - Valid date range (startDate before endDate)
  /// - Valid budget amounts
  /// - All members have unique IDs
  /// - Currency code is ISO 4217 compliant
  ///
  /// @returns `true` if valid, `false` otherwise
  ///
  /// @throws [ValidationException] with details of first validation error
  bool validate() {
    if (title.isEmpty) {
      throw ValidationException('Itinerary title cannot be empty');
    }
    if (startDate.isAfter(endDate)) {
      throw ValidationException('Start date must be before end date');
    }
    return true;
  }

  /// Adds a new member to the itinerary group.
  ///
  /// Emits a real-time event that syncs to all connected clients.
  /// Duplicate user IDs are silently ignored.
  ///
  /// @param member The [GroupMember] to add
  ///
  /// @returns `true` if member was added, `false` if already exists
  ///
  /// @throws [UnauthorizedException] if caller is not owner or editor
  /// @throws [NetworkException] if sync fails
  ///
  /// Example:
  /// ```dart
  /// final added = itinerary.addMember(
  ///   GroupMember(userId: 'user_bob', role: GroupMemberRole.editor),
  /// );
  /// if (added) print('Member added!');
  /// ```
  Future<bool> addMember(GroupMember member) async {
    // implementation
  }

  /// Removes a member from the itinerary group.
  ///
  /// The owner cannot be removed. If the owner leaves, ownership
  /// transfers to the longest-tenured editor, or the itinerary
  /// is moved to personal workspace.
  ///
  /// @param userId The UUID of the member to remove
  ///
  /// @returns `true` if member was removed, `false` if not found
  ///
  /// @throws [UnauthorizedException] if caller lacks permission
  /// @throws [StateException] if trying to remove the only member
  ///
  /// Example:
  /// ```dart
  /// await itinerary.removeMember('user_bob');
  /// ```
  Future<bool> removeMember(String userId) async {
    // implementation
  }

  /// Converts this [TravelItinerary] to a JSON map (for storage/transport).
  ///
  /// Note: Sensitive data (e.g., payment info) is omitted.
  ///
  /// @returns A JSON-serializable [Map]
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      // ... other fields
    };
  }

  /// Constructs a [TravelItinerary] from a JSON map.
  ///
  /// @param json The source JSON map
  ///
  /// @returns A [TravelItinerary] instance
  ///
  /// @throws [FormatException] if JSON is malformed or missing required fields
  factory TravelItinerary.fromJson(Map<String, dynamic> json) {
    return TravelItinerary(
      id: json['id'],
      title: json['title'],
      // ... parse other fields
    );
  }
}

/// Enum representing the status of an itinerary.
enum ItineraryStatusEnum {
  /// Itinerary is being drafted, not yet shared.
  draft,

  /// Itinerary is active (trip is upcoming or ongoing).
  active,

  /// Trip has finished.
  completed,

  /// Itinerary has been archived by the user.
  archived,
}

/// Represents a member in a group itinerary.
class GroupMember {
  /// UUID of the user.
  final String userId;

  /// Name of the user for display.
  final String userName;

  /// Role within the group (viewer, editor, owner).
  final GroupMemberRole role;

  /// Timestamp when this user was added to the group.
  final DateTime joinedAt;

  const GroupMember({
    required this.userId,
    required this.userName,
    required this.role,
    required this.joinedAt,
  });
}

/// Enum for group member roles.
enum GroupMemberRole {
  /// Can only view the itinerary.
  viewer,

  /// Can view and edit the itinerary.
  editor,

  /// Full ownership and control.
  owner,
}

/// Summary of expenses for an itinerary.
class ExpenseSummary {
  /// Total spent so far.
  final double totalSpent;

  /// Breakdown by category.
  final Map<String, double> spentByCategory;

  /// Individual balances (positive = owed to user, negative = owes).
  final Map<String, double> memberBalances;

  const ExpenseSummary({
    required this.totalSpent,
    required this.spentByCategory,
    required this.memberBalances,
  });
}

/// Represents a single item in an itinerary (activity, accommodation, etc.).
class ItineraryItem {
  /// Unique identifier for this item.
  final String id;

  /// Type of item (activity, flight, hotel, etc.).
  final String itemType;

  /// Title/name of the activity or booking.
  final String title;

  /// When the item starts.
  final DateTime startTime;

  /// When the item ends (optional).
  final DateTime? endTime;

  /// Optional location information.
  final String? location;

  const ItineraryItem({
    required this.id,
    required this.itemType,
    required this.title,
    required this.startTime,
    this.endTime,
    this.location,
  });
}
```

---

## Example: AiItineraryRepository Abstract Class

```dart
/// Abstract repository for AI-powered itinerary generation.
///
/// Defines the contract for generating itineraries using two distinct modes:
/// - **Skeletal Mode:** Fast, template-based generation
/// - **Concierge Mode:** Full LLM-powered, personalized generation
///
/// Implementations handle backend communication, error handling, and caching.
///
/// Example usage:
/// ```dart
/// final repo = AiItineraryRepository.instance;
/// final skeletal = await repo.generateSkeletalItinerary(
///   destination: 'Tokyo',
///   startDate: DateTime(2026, 6, 10),
/// );
/// ```
abstract class AiItineraryRepository {
  /// Generates a lightweight, template-based itinerary skeleton.
  ///
  /// ## Why Skeletal Mode?
  /// - **Speed:** Returns in <1 second
  /// - **Cost:** Minimal API usage
  /// - **Use Case:** Quick previews, trip planning inspiration
  ///
  /// Returns a basic daily structure with generic activities that users
  /// can customize further. No personalization or web search involved.
  ///
  /// @param destination The travel destination (e.g., "Tokyo", "Paris")
  /// @param startDate The trip start date (UTC)
  /// @param endDate The trip end date (UTC)
  /// @param interests Optional list of user interests (e.g., ["food", "history"])
  /// @param budget Optional total budget for the trip
  /// @param currencyCode ISO 4217 currency code (default: "USD")
  ///
  /// @returns A [Future] resolving to a [SkeletalItinerary] with daily templates
  ///
  /// @throws [InternetException] if backend is unreachable
  /// @throws [PromptException] if destination is too vague
  /// @throws [ServerException] if backend returns an error
  /// @throws [TimeoutException] if request exceeds 5 seconds
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final itinerary = await repo.generateSkeletalItinerary(
  ///     destination: 'Tokyo',
  ///     startDate: DateTime(2026, 6, 10),
  ///     endDate: DateTime(2026, 6, 17),
  ///     interests: ['temples', 'food', 'shopping'],
  ///     budget: 2000.0,
  ///     currencyCode: 'USD',
  ///   );
  ///   print('Generated ${itinerary.dailyActivities.length} days');
  /// } on ServerException catch (e) {
  ///   print('AI service error: ${e.message}');
  /// }
  /// ```
  Future<SkeletalItinerary> generateSkeletalItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? interests,
    double? budget,
    String currencyCode = 'USD',
  });

  /// Generates a comprehensive, personalized itinerary using LLM reasoning.
  ///
  /// ## Why Concierge Mode?
  /// - **Personalization:** Considers user interests, trip context, and history
  /// - **Intelligence:** Uses Claude/GPT-4 with web search for real recommendations
  /// - **Detail:** Includes specific restaurants, events, optimal routes
  /// - **Cost:** Higher API usage (premium users only)
  ///
  /// This mode uses agentic AI (CrewAI or LangChain) to search the web for:
  /// - Current events during the trip dates
  /// - Seasonal considerations
  /// - Restaurant/museum availability
  /// - Transportation options and timing
  ///
  /// The response is a fully fleshed-out, ready-to-execute itinerary.
  ///
  /// @param destination The travel destination (e.g., "Tokyo")
  /// @param startDate Trip start date (UTC)
  /// @param endDate Trip end date (UTC)
  /// @param interests List of user interests (required for good results)
  /// @param budget Total trip budget
  /// @param currencyCode ISO currency code
  /// @param groupSize Number of travelers (default: 1)
  /// @param travelStyle Travel preference (e.g., "luxury", "budget", "active")
  /// @param dietaryRestrictions List of dietary restrictions (e.g., ["vegan"])
  /// @param preferredLanguage Language for itinerary (default: "en")
  ///
  /// @returns A [Future] resolving to a [ConciergeItinerary]
  ///
  /// @throws [UnauthorizedException] if user is not a premium subscriber
  /// @throws [InternetException] if backend is unreachable
  /// @throws [QuotaExceededException] if user has exceeded monthly generation limit
  /// @throws [ServerException] if LLM service fails
  /// @throws [TimeoutException] if generation exceeds 30 seconds
  ///
  /// Example:
  /// ```dart
  /// final concierge = await repo.generateConciergeItinerary(
  ///   destination: 'Kyoto',
  ///   startDate: DateTime(2026, 6, 10),
  ///   endDate: DateTime(2026, 6, 15),
  ///   interests: ['temples', 'traditional_culture', 'food'],
  ///   budget: 5000.0,
  ///   currencyCode: 'USD',
  ///   groupSize: 2,
  ///   travelStyle: 'luxury',
  ///   dietaryRestrictions: ['vegan'],
  /// );
  ///
  /// for (final day in concierge.days) {
  ///   print('Day ${day.number}: ${day.activities.length} activities');
  /// }
  /// ```
  Future<ConciergeItinerary> generateConciergeItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> interests,
    required double budget,
    required String currencyCode,
    int groupSize = 1,
    String travelStyle = 'balanced',
    List<String>? dietaryRestrictions,
    String preferredLanguage = 'en',
  });

  /// Refines an existing itinerary based on user feedback.
  ///
  /// Uses iterative refinement to adjust activities, timings, or budget
  /// without regenerating from scratch (faster, cheaper).
  ///
  /// @param itineraryId UUID of the itinerary to refine
  /// @param feedbackPrompt User's feedback or requested changes
  /// Example: "Add more nightlife activities, reduce museums"
  ///
  /// @returns A [Future] resolving to an updated [ConciergeItinerary]
  ///
  /// @throws [NotFoundException] if itinerary not found
  /// @throws [UnauthorizedException] if caller doesn't own the itinerary
  /// @throws [ServerException] if refinement fails
  ///
  /// Example:
  /// ```dart
  /// final refined = await repo.refineItinerary(
  ///   itineraryId: 'itin_12345',
  ///   feedbackPrompt: 'Please add more street food experiences',
  /// );
  /// ```
  Future<ConciergeItinerary> refineItinerary({
    required String itineraryId,
    required String feedbackPrompt,
  });

  /// Retrieves cached generations for a given destination.
  ///
  /// Returns recently generated itineraries to reduce redundant API calls.
  /// Useful for showing similar trips the user or their friends have generated.
  ///
  /// @param destination The destination to search for
  /// @param mode The generation mode ('skeletal' or 'concierge')
  /// @param limit Maximum number of results (default: 10)
  ///
  /// @returns List of [CachedGeneration] entries
  ///
  /// @throws [ServerException] if cache lookup fails
  Future<List<CachedGeneration>> getCachedGenerations({
    required String destination,
    required String mode,
    int limit = 10,
  });
}

/// Lightweight itinerary structure for skeletal generation.
class SkeletalItinerary {
  /// Destination name.
  final String destination;

  /// Trip duration in days.
  final int numDays;

  /// Daily breakdown with generic activities.
  /// Key: "day_1", "day_2", etc.
  /// Value: List of [Activity] objects.
  final Map<String, List<Activity>> dailyActivities;

  /// Estimated total cost (if budget was provided).
  final double? estimatedCost;

  /// Currency code.
  final String currencyCode;

  const SkeletalItinerary({
    required this.destination,
    required this.numDays,
    required this.dailyActivities,
    this.estimatedCost,
    required this.currencyCode,
  });
}

/// Comprehensive, personalized itinerary for concierge generation.
class ConciergeItinerary {
  /// Destination name.
  final String destination;

  /// Start date of trip.
  final DateTime startDate;

  /// End date of trip.
  final DateTime endDate;

  /// Daily itinerary breakdown.
  final List<DayPlan> days;

  /// Booking recommendations (flights, hotels, etc.).
  final List<BookingRecommendation> bookings;

  /// Local tips and insights.
  final String localInsights;

  /// Budget breakdown by category.
  final Map<String, double> budgetBreakdown;

  /// Total estimated cost.
  final double estimatedCost;

  /// Currency code.
  final String currencyCode;

  const ConciergeItinerary({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.bookings,
    required this.localInsights,
    required this.budgetBreakdown,
    required this.estimatedCost,
    required this.currencyCode,
  });
}

/// Single day plan within a concierge itinerary.
class DayPlan {
  /// Day number (1-indexed).
  final int dayNumber;

  /// Date of this day.
  final DateTime date;

  /// Ordered list of activities for the day.
  final List<Activity> activities;

  /// Recommendations for meals.
  final List<MealRecommendation> meals;

  const DayPlan({
    required this.dayNumber,
    required this.date,
    required this.activities,
    required this.meals,
  });
}

/// Single activity or attraction.
class Activity {
  /// Activity ID.
  final String id;

  /// Name of the activity.
  final String name;

  /// Detailed description.
  final String description;

  /// Start time for this activity.
  final DateTime startTime;

  /// Duration in minutes.
  final int durationMinutes;

  /// Location/address.
  final String location;

  /// Latitude for map integration.
  final double? latitude;

  /// Longitude for map integration.
  final double? longitude;

  /// Estimated cost.
  final double cost;

  /// Tags (e.g., "museum", "food", "nature").
  final List<String> tags;

  const Activity({
    required this.id,
    required this.name,
    required this.description,
    required this.startTime,
    required this.durationMinutes,
    required this.location,
    this.latitude,
    this.longitude,
    required this.cost,
    required this.tags,
  });
}

/// Meal recommendation (breakfast, lunch, dinner).
class MealRecommendation {
  /// Type of meal.
  final String mealType; // "breakfast", "lunch", "dinner"

  /// Restaurant name.
  final String restaurantName;

  /// Cuisine type.
  final String cuisine;

  /// Estimated cost per person.
  final double costPerPerson;

  /// Address/location.
  final String location;

  const MealRecommendation({
    required this.mealType,
    required this.restaurantName,
    required this.cuisine,
    required this.costPerPerson,
    required this.location,
  });
}

/// Booking recommendation (flight, hotel, etc.).
class BookingRecommendation {
  /// Type of booking.
  final String bookingType; // "flight", "hotel", "car_rental"

  /// Recommended provider.
  final String provider; // "booking.com", "expedia", etc.

  /// URL to booking page.
  final String bookingUrl;

  /// Price.
  final double price;

  const BookingRecommendation({
    required this.bookingType,
    required this.provider,
    required this.bookingUrl,
    required this.price,
  });
}

/// Cached generation entry.
class CachedGeneration {
  /// Generation ID.
  final String id;

  /// Destination.
  final String destination;

  /// Mode (skeletal or concierge).
  final String mode;

  /// When this was generated.
  final DateTime generatedAt;

  const CachedGeneration({
    required this.id,
    required this.destination,
    required this.mode,
    required this.generatedAt,
  });
}
```

---

## Common Patterns & Templates

### Pattern 1: Class Documentation

```dart
/// Brief description of what the class does.
///
/// Longer explanation including:
/// - Purpose and responsibility
/// - Usage context
/// - Related classes/interfaces
///
/// Example:
/// ```dart
/// final instance = MyClass(...);
/// ```
class MyClass {
  // implementation
}
```

### Pattern 2: Method Documentation

```dart
/// Verb-based description of what the method does.
///
/// @param paramName Description of parameter
/// @param anotherParam Description of another parameter
///
/// @returns Description of return value
///
/// @throws ExceptionType If/when this exception is thrown
///
/// Example:
/// ```dart
/// final result = await myMethod(param: 'value');
/// ```
Future<ReturnType> myMethod({
  required String param,
}) async {
  // implementation
}
```

### Pattern 3: Enum Documentation

```dart
/// Enum representing possible statuses.
enum MyEnum {
  /// Description of first value.
  first,

  /// Description of second value.
  second,
}
```

### Pattern 4: Extension Documentation

```dart
/// Extensions on [String] for validation purposes.
extension StringValidation on String {
  /// Returns true if this string is a valid email address.
  ///
  /// Uses RFC 5322 simplified regex for validation.
  bool isValidEmail() {
    // implementation
  }
}
```

---

## Checklist for Documentation Review

- [ ] All public classes have `///` documentation
- [ ] All public methods have `///` documentation
- [ ] Parameters documented with `@param`
- [ ] Return values documented with `@returns`
- [ ] Exceptions documented with `@throws`
- [ ] At least one code example provided
- [ ] No broken cross-references
- [ ] Grammar and spelling correct
- [ ] Markdown formatting is clean
- [ ] No outdated information

---

**End of Dartdoc Guidelines Document**
