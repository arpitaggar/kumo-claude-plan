# Test-Driven Development (TDD) & Unit Testing Strategy

**For:** Kumo Super-App Flutter Project  
**Last Updated:** June 2026

---

## Table of Contents

1. [TDD Principles & Workflow](#tdd-principles--workflow)
2. [Testing Pyramid](#testing-pyramid)
3. [Testing Setup & Dependencies](#testing-setup--dependencies)
4. [Example 1: Expense-Splitting Logic Unit Test](#example-1-expense-splitting-logic-unit-test)
5. [Example 2: Itinerary State Management (Riverpod) Test](#example-2-itinerary-state-management-riverpod-test)
6. [Testing Best Practices](#testing-best-practices)
7. [Test Naming Conventions](#test-naming-conventions)

---

## TDD Principles & Workflow

### The Red-Green-Refactor Cycle

1. **Red:** Write a failing test that describes desired behavior
2. **Green:** Write minimal code to pass the test
3. **Refactor:** Improve code quality without changing behavior

### Applied to Kumo

For **every** feature (especially domain logic and data layers):

```
┌─────────────────────────────────────────┐
│ 1. Write Failing Test                   │
│    (test/features/expense_split/...)    │
└─────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────┐
│ 2. Implement Domain Logic / Repository  │
│    (lib/features/expense_split/...)     │
│    - Just enough to pass the test       │
└─────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────┐
│ 3. Refactor & Improve                   │
│    - Extract duplications               │
│    - Improve naming                     │
│    - Ensure test still passes           │
└─────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────┐
│ 4. Move to Next Test                    │
│    Repeat for next feature              │
└─────────────────────────────────────────┘
```

### Why TDD for Kumo?

- **Correctness:** Financial logic (expense splitting, card management) must be bug-free
- **Refactoring Confidence:** Changes are safe when tests exist
- **Documentation:** Tests serve as executable documentation
- **Design:** Writing tests first improves API design

---

## Testing Pyramid

```
        /\
       /  \
      /    \  E2E Tests
     /      \ (UI flows, critical paths)
    /        \ ~5% of tests
   /──────────\
  /            \
 /    Widget    \ Widget Tests
/     Tests     \ (UI rendering, interactions)
\______________/ ~15% of tests
\              /
 \   Unit      / Unit Tests
  \  Tests    / (business logic, usecases)
   \ _______ / ~80% of tests
```

---

## Testing Setup & Dependencies

### pubspec.yaml Additions

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # Unit testing
  test: ^1.24.0
  mockito: ^5.4.0

  # Riverpod testing
  riverpod_test: ^3.0.0  # or use hooks_riverpod built-in test support
  
  # Widget testing
  golden_toolkit: ^0.14.0  # for golden file testing

  # Test utilities
  matcher: ^0.12.0
  integration_test:
    sdk: flutter
```

---

## Example 1: Expense-Splitting Logic Unit Test

### File: `test/features/expense_split/domain/usecases/split_expense_usecase_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/expense_split/domain/entities/expense.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/split_expense_usecase.dart';

void main() {
  group('SplitExpenseUsecase', () {
    late SplitExpenseUsecase splitExpenseUsecase;

    setUp(() {
      splitExpenseUsecase = SplitExpenseUsecase();
    });

    group('calculateSplits', () {
      /// Test 1: Even split among N people
      test('splits expense evenly among N people', () {
        // Arrange
        const totalAmount = 100.0;
        const participants = ['alice', 'bob', 'charlie'];

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          participants: participants,
          splitType: SplitType.equal,
        );

        // Assert
        expect(splits.length, equals(3));
        expect(splits['alice'], closeTo(33.33, 0.01));
        expect(splits['bob'], closeTo(33.33, 0.01));
        expect(splits['charlie'], closeTo(33.34, 0.01)); // Rounding up
      });

      /// Test 2: Split with custom percentages
      test('splits based on custom percentages', () {
        // Arrange
        const totalAmount = 1000.0;
        final percentages = {
          'alice': 50.0,
          'bob': 30.0,
          'charlie': 20.0,
        };

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          percentages: percentages,
          splitType: SplitType.percentage,
        );

        // Assert
        expect(splits['alice'], equals(500.0));
        expect(splits['bob'], equals(300.0));
        expect(splits['charlie'], equals(200.0));
      });

      /// Test 3: Split with custom amounts
      test('splits with custom amounts', () {
        // Arrange
        const totalAmount = 1000.0;
        final customAmounts = {
          'alice': 400.0,
          'bob': 350.0,
          'charlie': 250.0,
        };

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          customAmounts: customAmounts,
          splitType: SplitType.custom,
        );

        // Assert
        expect(splits['alice'], equals(400.0));
        expect(splits['bob'], equals(350.0));
        expect(splits['charlie'], equals(250.0));
      });

      /// Test 4: Uneven split (some people pay nothing)
      test('handles partial participation', () {
        // Arrange
        const totalAmount = 100.0;
        final percentages = {
          'alice': 100.0,
          'bob': 0.0,  // Bob doesn't participate
          'charlie': 0.0,
        };

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          percentages: percentages,
          splitType: SplitType.percentage,
        );

        // Assert
        expect(splits['alice'], equals(100.0));
        expect(splits['bob'], equals(0.0));
        expect(splits['charlie'], equals(0.0));
      });

      /// Test 5: Error case — percentages don't sum to 100
      test('throws ValidationException if percentages don\'t sum to 100', () {
        // Arrange
        const totalAmount = 1000.0;
        final invalidPercentages = {
          'alice': 50.0,
          'bob': 30.0,
          // Sum is 80, not 100
        };

        // Act & Assert
        expect(
          () => splitExpenseUsecase.calculateSplits(
            totalAmount: totalAmount,
            percentages: invalidPercentages,
            splitType: SplitType.percentage,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      /// Test 6: Error case — custom amounts exceed total
      test('throws ValidationException if custom amounts exceed total', () {
        // Arrange
        const totalAmount = 100.0;
        final excessiveAmounts = {
          'alice': 60.0,
          'bob': 50.0,
          // Sum is 110, exceeds 100
        };

        // Act & Assert
        expect(
          () => splitExpenseUsecase.calculateSplits(
            totalAmount: totalAmount,
            customAmounts: excessiveAmounts,
            splitType: SplitType.custom,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      /// Test 7: Rounding precision — totals should sum back to original
      test('ensures split amounts sum back to original total (no money lost)', () {
        // Arrange
        const totalAmount = 12.34;
        const participants = ['a', 'b', 'c', 'd', 'e'];

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          participants: participants,
          splitType: SplitType.equal,
        );

        // Assert
        final sum = splits.values.fold<double>(0, (a, b) => a + b);
        expect(sum, closeTo(totalAmount, 0.01)); // Within 1 cent
      });

      /// Test 8: Large group split (stress test)
      test('handles large groups (100+ people)', () {
        // Arrange
        const totalAmount = 10000.0;
        final participants =
            List.generate(150, (i) => 'user_$i');

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          participants: participants,
          splitType: SplitType.equal,
        );

        // Assert
        expect(splits.length, equals(150));
        for (final amount in splits.values) {
          expect(
            amount,
            closeTo(10000.0 / 150, 0.01),
          );
        }
      });

      /// Test 9: Zero amount edge case
      test('handles zero total amount', () {
        // Arrange
        const totalAmount = 0.0;
        const participants = ['alice', 'bob'];

        // Act
        final splits = splitExpenseUsecase.calculateSplits(
          totalAmount: totalAmount,
          participants: participants,
          splitType: SplitType.equal,
        );

        // Assert
        expect(splits['alice'], equals(0.0));
        expect(splits['bob'], equals(0.0));
      });

      /// Test 10: Negative amount rejection
      test('throws ValidationException for negative amounts', () {
        // Act & Assert
        expect(
          () => splitExpenseUsecase.calculateSplits(
            totalAmount: -100.0,
            participants: ['alice', 'bob'],
            splitType: SplitType.equal,
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('calculateBalances', () {
      /// Test 11: Calculate who owes whom
      test('calculates balances for N-way split', () {
        // Arrange
        final expenses = [
          Expense(
            id: 'exp_1',
            amount: 300.0,
            paidBy: 'alice',
            splitAmong: ['alice', 'bob', 'charlie'],
          ),
          Expense(
            id: 'exp_2',
            amount: 150.0,
            paidBy: 'bob',
            splitAmong: ['alice', 'bob'],
          ),
        ];

        // Act
        final balances = splitExpenseUsecase.calculateBalances(expenses);

        // Assert
        // Alice paid: 300, owes: 100 + 75 = 175, balance: +125
        // Bob paid: 150, owes: 100 + 75 = 175, balance: -25
        // Charlie paid: 0, owes: 100, balance: -100
        expect(balances['alice'], equals(125.0));
        expect(balances['bob'], closeTo(-25.0, 0.01));
        expect(balances['charlie'], equals(-100.0));
      });

      /// Test 12: Balanced expenses (no one owes anyone)
      test('returns zero balances when all expenses are balanced', () {
        // Arrange
        final expenses = [
          Expense(
            id: 'exp_1',
            amount: 100.0,
            paidBy: 'alice',
            splitAmong: ['alice', 'bob'],
          ),
          Expense(
            id: 'exp_2',
            amount: 100.0,
            paidBy: 'bob',
            splitAmong: ['alice', 'bob'],
          ),
        ];

        // Act
        final balances = splitExpenseUsecase.calculateBalances(expenses);

        // Assert
        expect(balances['alice'], closeTo(0.0, 0.01));
        expect(balances['bob'], closeTo(0.0, 0.01));
      });
    });
  });
}

/// Custom exception class (defined in app)
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Enum for split types
enum SplitType {
  equal,
  percentage,
  custom,
}

/// Expense model for testing
class Expense {
  final String id;
  final double amount;
  final String paidBy;
  final List<String> splitAmong;

  Expense({
    required this.id,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
  });
}
```

### Running the Test

```bash
# Run single test file
flutter test test/features/expense_split/domain/usecases/split_expense_usecase_test.dart

# Run all tests in expense_split
flutter test test/features/expense_split/

# Run all tests with coverage
flutter test --coverage
```

---

## Example 2: Itinerary State Management (Riverpod) Test

### File: `test/features/itinerary/presentation/providers/itinerary_provider_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/itinerary_repository_impl.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';

// Generate mock classes for unit testing
@GenerateMocks([ItineraryRepository])
import 'itinerary_provider_test.mocks.dart';

void main() {
  group('ItineraryProvider (Riverpod State Management)', () {
    late ProviderContainer container;
    late MockItineraryRepository mockRepository;

    setUp(() {
      mockRepository = MockItineraryRepository();
      container = ProviderContainer(
        overrides: [
          itineraryRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    /// Test 1: Initial state is loading
    test('initial state is ItineraryLoading', () {
      // Act
      final state = container.read(itineraryNotifierProvider);

      // Assert
      expect(state, isA<ItineraryLoading>());
    });

    /// Test 2: Successfully fetch itinerary transitions to loaded state
    test('FetchItinerary event transitions to ItineraryLoaded', () async {
      // Arrange
      final mockItinerary = TravelItinerary(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Tokyo Summer 2026',
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 17),
        ownerId: 'user_alice',
        totalBudget: 5000.0,
        currencyCode: 'USD',
        members: [],
        items: [],
        expenseSummary: ExpenseSummary(
          totalSpent: 0.0,
          spentByCategory: {},
          memberBalances: {},
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockRepository.fetchItinerary('550e8400-e29b-41d4-a716-446655440000'))
          .thenAnswer((_) async => Right(mockItinerary));

      // Act
      container.read(itineraryNotifierProvider.notifier)
          .fetchItinerary('550e8400-e29b-41d4-a716-446655440000');

      // Let async work complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      final state = container.read(itineraryNotifierProvider);
      expect(state, isA<ItineraryLoaded>());
      if (state is ItineraryLoaded) {
        expect(state.itinerary.id, equals('550e8400-e29b-41d4-a716-446655440000'));
        expect(state.itinerary.title, equals('Tokyo Summer 2026'));
      }
    });

    /// Test 3: Handle error when fetch fails
    test('FetchItinerary event transitions to ItineraryError on failure', () async {
      // Arrange
      when(mockRepository.fetchItinerary('invalid_id'))
          .thenAnswer((_) async => Left(ServerFailure('Not found')));

      // Act
      container.read(itineraryNotifierProvider.notifier)
          .fetchItinerary('invalid_id');

      // Let async work complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      final state = container.read(itineraryNotifierProvider);
      expect(state, isA<ItineraryError>());
      if (state is ItineraryError) {
        expect(state.message, contains('Not found'));
      }
    });

    /// Test 4: Update itinerary title locally before server sync
    test('UpdateItinerary optimistically updates UI', () async {
      // Arrange
      final mockItinerary = TravelItinerary(
        id: 'itin_1',
        title: 'Original Title',
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 17),
        ownerId: 'user_alice',
        totalBudget: 5000.0,
        currencyCode: 'USD',
        members: [],
        items: [],
        expenseSummary: ExpenseSummary(
          totalSpent: 0.0,
          spentByCategory: {},
          memberBalances: {},
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // First load the itinerary
      when(mockRepository.fetchItinerary('itin_1'))
          .thenAnswer((_) async => Right(mockItinerary));

      container.read(itineraryNotifierProvider.notifier)
          .fetchItinerary('itin_1');
      await Future.delayed(const Duration(milliseconds: 100));

      // Now update it
      final updatedItinerary = mockItinerary.copyWith(title: 'New Title');
      when(mockRepository.updateItinerary(updatedItinerary))
          .thenAnswer((_) async => Right(updatedItinerary));

      // Act
      container.read(itineraryNotifierProvider.notifier)
          .updateItinerary(updatedItinerary);

      // Assert - optimistic update happens immediately
      var state = container.read(itineraryNotifierProvider);
      expect(state, isA<ItineraryLoaded>());
      if (state is ItineraryLoaded) {
        expect(state.itinerary.title, equals('New Title'));
      }

      // Wait for server confirmation
      await Future.delayed(const Duration(milliseconds: 100));

      state = container.read(itineraryNotifierProvider);
      expect(state, isA<ItineraryLoaded>());
      if (state is ItineraryLoaded) {
        expect(state.itinerary.title, equals('New Title'));
      }
    });

    /// Test 5: Rollback on update failure
    test('UpdateItinerary rolls back on server error', () async {
      // Arrange
      final originalItinerary = TravelItinerary(
        id: 'itin_1',
        title: 'Original Title',
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 17),
        ownerId: 'user_alice',
        totalBudget: 5000.0,
        currencyCode: 'USD',
        members: [],
        items: [],
        expenseSummary: ExpenseSummary(
          totalSpent: 0.0,
          spentByCategory: {},
          memberBalances: {},
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockRepository.fetchItinerary('itin_1'))
          .thenAnswer((_) async => Right(originalItinerary));

      container.read(itineraryNotifierProvider.notifier)
          .fetchItinerary('itin_1');
      await Future.delayed(const Duration(milliseconds: 100));

      // Update fails on server
      final failedUpdate = originalItinerary.copyWith(title: 'Failed Title');
      when(mockRepository.updateItinerary(failedUpdate))
          .thenAnswer((_) async => Left(ServerFailure('Server error')));

      // Act
      container.read(itineraryNotifierProvider.notifier)
          .updateItinerary(failedUpdate);

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - should roll back to original
      final state = container.read(itineraryNotifierProvider);
      expect(state, isA<ItineraryLoaded>());
      if (state is ItineraryLoaded) {
        expect(state.itinerary.title, equals('Original Title'));
      }
    });

    /// Test 6: Cache invalidation when creating new itinerary
    test('CreateItinerary invalidates list cache', () async {
      // Arrange
      final listState = container.read(itineraryListProvider);
      expect(listState, isA<ItineraryListLoading>());

      // Act
      final newItinerary = TravelItinerary(
        id: 'new_itin',
        title: 'New Trip',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 8),
        ownerId: 'user_alice',
        totalBudget: 3000.0,
        currencyCode: 'USD',
        members: [],
        items: [],
        expenseSummary: ExpenseSummary(
          totalSpent: 0.0,
          spentByCategory: {},
          memberBalances: {},
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockRepository.createItinerary(newItinerary))
          .thenAnswer((_) async => Right(newItinerary));

      container.read(itineraryNotifierProvider.notifier)
          .createItinerary(newItinerary);

      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - list cache should be invalidated and refreshed
      final updatedListState = container.read(itineraryListProvider);
      expect(updatedListState, isA<ItineraryListLoaded>());
    });
  });
}

/// Mock implementation placeholder
extension on TravelItinerary {
  TravelItinerary copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerId,
    double? totalBudget,
    String? currencyCode,
  }) {
    return TravelItinerary(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      ownerId: ownerId ?? this.ownerId,
      totalBudget: totalBudget ?? this.totalBudget,
      currencyCode: currencyCode ?? this.currencyCode,
      members: members,
      items: items,
      expenseSummary: expenseSummary,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status,
    );
  }
}
```

### Running the Test

```bash
flutter test test/features/itinerary/presentation/providers/itinerary_provider_test.dart
```

---

## Testing Best Practices

### 1. **Arrange-Act-Assert (AAA) Pattern**

```dart
test('description of what is being tested', () {
  // Arrange: Set up test data and mocks
  final input = TestData();
  when(mockRepo.fetchData()).thenAnswer((_) async => input);

  // Act: Execute the code under test
  final result = await usecase.execute();

  // Assert: Verify the result
  expect(result, equals(expectedOutput));
});
```

### 2. **Use Descriptive Test Names**

```dart
// ❌ BAD
test('test fetch', () { });

// ✅ GOOD
test('fetchItinerary returns ItineraryLoaded when server responds successfully', () { });
```

### 3. **Test One Thing Per Test**

```dart
// ❌ BAD: Testing multiple concerns
test('can create and delete itinerary', () {
  // Create test
  // Delete test
});

// ✅ GOOD: Separate tests
test('createItinerary adds new itinerary to repository', () { });
test('deleteItinerary removes itinerary from repository', () { });
```

### 4. **Mock External Dependencies**

```dart
// ✅ GOOD: Mock Supabase client
@GenerateMocks([SupabaseClient])
void main() {
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
  });

  test('fetches data from Supabase', () async {
    when(mockSupabaseClient.from('table').select())
        .thenAnswer((_) async => [{ 'id': 1 }]);
    
    // Test code
  });
}
```

### 5. **Test Error Cases**

```dart
test('throws ValidationException on invalid input', () {
  expect(
    () => validator.validateEmail('invalid-email'),
    throwsA(isA<ValidationException>()),
  );
});
```

### 6. **Use Golden Files for Widget Tests** (Optional)

```dart
testWidgets('ItineraryCard renders correctly', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ItineraryCard(itinerary: mockItinerary),
    ),
  );

  // Verify against golden file
  await expectLater(
    find.byType(ItineraryCard),
    matchesGoldenFile('golden/itinerary_card.png'),
  );
});
```

---

## Test Naming Conventions

### Unit Tests

```
test/features/{feature_name}/
├── domain/
│   ├── entities/
│   │   └── {entity_name}_test.dart
│   ├── repositories/
│   │   └── {repository_name}_test.dart
│   └── usecases/
│       └── {usecase_name}_test.dart
├── data/
│   ├── datasources/
│   │   ├── {datasource_name}_remote_test.dart
│   │   └── {datasource_name}_local_test.dart
│   ├── models/
│   │   └── {model_name}_test.dart
│   └── repositories/
│       └── {repository_impl_name}_test.dart
└── presentation/
    ├── pages/
    │   └── {page_name}_test.dart
    ├── providers/
    │   └── {provider_name}_test.dart
    └── widgets/
        └── {widget_name}_test.dart
```

### Naming Pattern

```
{action}_{scenario}_{expected_result}_test.dart

Examples:
- split_expense_evenly_among_n_people_test.dart
- fetch_itinerary_on_success_returns_loaded_state_test.dart
- validate_email_with_invalid_input_throws_exception_test.dart
```

---

## Coverage Goals

| Layer | Coverage Target | Rationale |
|-------|-----------------|-----------|
| Domain (Entities, Usecases) | 90%+ | Core business logic; must be bulletproof |
| Data (Repositories, Models) | 80%+ | Database/API interactions; test main paths |
| Presentation (Providers, Pages) | 60%+ | UI logic; integration tests more important |
| Widgets | 50%+ | UI rendering; golden files + manual QA sufficient |

---

## Running All Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate coverage report (requires lcov)
lcov --list coverage/lcov.info

# Watch mode (re-run on file change)
flutter test --watch

# Run specific test file
flutter test test/features/expense_split/domain/usecases/split_expense_usecase_test.dart

# Run tests matching a pattern
flutter test --name "split_expense"

# Run with verbose output
flutter test -v
```

---

**End of Testing Strategy Document**
