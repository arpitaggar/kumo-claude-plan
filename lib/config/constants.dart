/// Application-wide constants and configuration values.
class AppConstants {
  AppConstants._(); // Private constructor

  // API & Environment
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANONKEY',
    defaultValue: 'YOUR_ANON_KEY',
  );

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxEmailLength = 254;
  static const int maxTitleLength = 255;
  static const int maxDescriptionLength = 2000;

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 5);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache
  static const Duration cacheExpiry = Duration(hours: 1);
  static const Duration shortCacheExpiry = Duration(minutes: 5);

  // UI
  static const double defaultPadding = 16;
  static const double defaultBorderRadius = 12;

  // Trip defaults
  static const double defaultTravelBudget = 1000;
  static const String defaultCurrency = 'USD';
  static const int maxTripDurationDays = 365;
  static const int minTripDurationDays = 1;

  // Expense splitting
  static const int maxGroupSize = 500;
  static const double minExpenseAmount = 0.01;
  static const double maxExpenseAmount = 999999.99;

  // API Endpoints (Supabase tables)
  static const String usersTable = 'users';
  static const String itinerariesTable = 'itineraries';
  static const String itineraryEventsTable = 'itinerary_events';
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';
  static const String expensesTable = 'expenses';
  static const String messagesTable = 'messages';
}
