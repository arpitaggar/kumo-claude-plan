# Kumo — Unit Test Reference

**Total:** 96 tests · 0 failures  
**Last run:** June 2026  
**Framework:** `flutter_test` · Mocking: `mocktail ^1.0.5`  
**Command:** `flutter test`

---

## Overview

| # | Test file | Class under test | Tests | Layer |
|---|-----------|-----------------|------:|-------|
| 1 | [validators_test.dart](#1-validators) | `Validators` | 29 | Core / Util |
| 2 | [login_usecase_test.dart](#2-login-use-case) | `LoginUseCase` | 5 | Stage 1 · Auth domain |
| 3 | [signup_usecase_test.dart](#3-signup-use-case) | `SignupUseCase` | 4 | Stage 1 · Auth domain |
| 4 | [calculate_settlements_usecase_test.dart](#4-calculate-settlements-use-case) | `CalculateSettlementsUseCase` | 9 | Stage 4 · Expense domain |
| 5 | [add_expense_usecase_test.dart](#5-add-expense-use-case) | `AddExpenseUseCase` | 6 | Stage 4 · Expense domain |
| 6 | [expense_model_test.dart](#6-expense-model) | `ExpenseModel` | 10 | Stage 4 · Expense data |
| 7 | [add_rating_usecase_test.dart](#7-add-rating-use-case) | `AddRatingUseCase` | 8 | Stage 4 · Ratings domain |
| 8 | [rating_model_test.dart](#8-rating-model) | `RatingModel` | 10 | Stage 4 · Ratings data |
| 9 | [ai_generation_datasource_test.dart](#9-ai-generation-datasource) | `AiGenerationDataSourceImpl` | 7 | Stage 3 · AI data |

---

## 1. Validators

**File:** `test/core/utils/validators_test.dart`  
**Class:** `lib/core/utils/validators.dart → Validators`  
**Mocks:** none (pure static utility)

### `Validators.validateEmail` (7 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | throws ValidationException for empty email | throws `ValidationException` |
| 2 | throws ValidationException for null email | throws `ValidationException` |
| 3 | returns true for valid email | `true` |
| 4 | returns true for email with subdomain | `true` |
| 5 | returns false for email without @ | `false` |
| 6 | returns false for email without domain | `false` |
| 7 | returns false for email without TLD | `false` |

### `Validators.validatePassword` (5 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | throws ValidationException for empty password | throws `ValidationException` |
| 2 | throws ValidationException for null password | throws `ValidationException` |
| 3 | throws ValidationException for password shorter than 8 chars | throws `ValidationException` |
| 4 | returns true for valid password | `true` |
| 5 | returns true for exactly 8 chars | `true` |

### `Validators.validateCurrencyCode` (6 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | returns true for USD | `true` |
| 2 | returns true for lowercase usd | `true` (case-insensitive) |
| 3 | returns true for JPY | `true` |
| 4 | returns false for unknown code | `false` |
| 5 | returns false for null | `false` |
| 6 | returns false for empty string | `false` |

### `Validators.validateDateRange` (3 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | does not throw for valid date range | returns normally |
| 2 | does not throw for same start and end date | returns normally |
| 3 | throws ValidationException when start is after end | throws `ValidationException` |

### `Validators.validateNonEmpty` (4 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | does not throw for non-empty string | returns normally |
| 2 | throws ValidationException for empty string | throws `ValidationException` |
| 3 | throws ValidationException for whitespace-only string | throws `ValidationException` |
| 4 | throws ValidationException for null | throws `ValidationException` |

### `Validators.validateUuid` (4 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | returns true for valid UUID | `true` |
| 2 | returns false for invalid UUID | `false` |
| 3 | returns false for empty string | `false` |
| 4 | returns false for null | `false` |

---

## 2. Login Use Case

**File:** `test/features/auth/domain/usecases/login_usecase_test.dart`  
**Class:** `lib/features/auth/domain/usecases/login_usecase.dart → LoginUseCase`  
**Mocks:** `MockAuthRepository extends Mock implements AuthRepository`

### Validation (3 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | returns ValidationFailure for empty email | `Left<ValidationFailure>` · repository never called |
| 2 | returns ValidationFailure for empty password | `Left<ValidationFailure>` · repository never called |
| 3 | returns ValidationFailure for password shorter than 8 chars | `Left<ValidationFailure>` |

### Repository delegation (5 tests)

| # | Test | Expected |
|---|------|----------|
| 4 | calls repository.login with valid credentials | `verify(mockRepo.login(...)).called(1)` |
| 5 | returns Right(user) on successful login | `Right<User>` matching stub |
| 6 | propagates AuthFailure from repository | `Left<AuthFailure>` |
| 7 | propagates NetworkFailure from repository | `Left<NetworkFailure>` |

---

## 3. Signup Use Case

**File:** `test/features/auth/domain/usecases/signup_usecase_test.dart`  
**Class:** `lib/features/auth/domain/usecases/signup_usecase.dart → SignupUseCase`  
**Mocks:** `MockAuthRepository extends Mock implements AuthRepository`

### Validation (3 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | returns ValidationFailure for empty email | `Left<ValidationFailure>` |
| 2 | returns ValidationFailure for empty password | `Left<ValidationFailure>` |
| 3 | returns ValidationFailure for short password | `Left<ValidationFailure>` |

### Repository delegation (4 tests)

| # | Test | Expected |
|---|------|----------|
| 4 | calls repository.signUp with correct arguments | `verify(mockRepo.signUp(...)).called(1)` |
| 5 | returns Right(user) on successful signup | `Right<User>` matching stub |
| 6 | signup without displayName does not pass null displayName to repo | named param omitted in verify |
| 7 | propagates AuthFailure from repository | `Left<AuthFailure>` |

---

## 4. Calculate Settlements Use Case

**File:** `test/features/expense_split/domain/usecases/calculate_settlements_usecase_test.dart`  
**Class:** `lib/features/expense_split/domain/usecases/calculate_settlements_usecase.dart → CalculateSettlementsUseCase`  
**Mocks:** none (pure computation)

### Empty / trivial cases (2 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | returns empty list for no expenses | `[]` |
| 2 | returns empty list when payer is the only member (no splits) | `[]` |

### Two-person scenarios (3 tests)

| # | Test | Expected |
|---|------|----------|
| 3 | one expense: debtor owes payer the share amount | 1 settlement: Bob→Alice, amount=50 |
| 4 | two expenses: net balance is calculated correctly | 1 settlement: Bob→Alice, amount=40 (60-20) |
| 5 | amounts round to two decimal places | amount=33.33 |

### Three-person scenarios (3 tests)

| # | Test | Expected |
|---|------|----------|
| 6 | one expense paid by Alice, split equally | 2 settlements to Alice, each 30 |
| 7 | greedy minimisation: two debtors, one creditor | 2 settlements, total=45 |
| 8 | returns empty when balances cancel out exactly (A→B→C→A) | `[]` |

### Settlement properties (2 tests)

| # | Test | Expected |
|---|------|----------|
| 9 | fromUserId is always the debtor | `fromUserId ≠ toUserId` for all |
| 10 | settlement amounts are all positive | `amount > 0` for all |

---

## 5. Add Expense Use Case

**File:** `test/features/expense_split/domain/usecases/add_expense_usecase_test.dart`  
**Class:** `lib/features/expense_split/domain/usecases/add_expense_usecase.dart → AddExpenseUseCase`  
**Mocks:** `MockExpenseRepository extends Mock implements ExpenseRepository`  
**Fallback:** `FakeExpense extends Fake implements Expense`

| # | Test | Expected |
|---|------|----------|
| 1 | calls repository.addExpense once | `verify(mockRepo.addExpense(any())).called(1)` |
| 2 | trims whitespace from title | captured `expense.title == 'Dinner'` (not `'  Dinner  '`) |
| 3 | expense id is a non-empty UUID string | `id.length == 36` |
| 4 | createdAt is set to a UTC time close to now | within ±1 s of `DateTime.now().toUtc()` |
| 5 | returns Right(expense) on success | `result.isRight() == true` |
| 6 | propagates ServerFailure from repository | `Left<ServerFailure>` |

---

## 6. Expense Model

**File:** `test/features/expense_split/data/models/expense_model_test.dart`  
**Class:** `lib/features/expense_split/data/models/expense_model.dart → ExpenseModel`  
**Mocks:** none (pure serialisation)

### `ExpenseModel.fromJson` (6 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | parses all fields correctly | all field values match fixture JSON |
| 2 | parses splits correctly | 2 splits, correct userId/shareAmount |
| 3 | uses empty splits when splits key missing | `splits == []` |
| 4 | falls back to USD when currency_code missing | `currencyCode == 'USD'` |
| 5 | defaults to ExpenseCategory.other for unknown category | `category == ExpenseCategory.other` |
| 6 | parses integer amount as double | `amount == 90.0` and `amount is double` |

### `ExpenseModel.toJson` (4 tests)

| # | Test | Expected |
|---|------|----------|
| 7 | serialises id correctly | `json['id'] == 'expense-1'` |
| 8 | serialises category as name string | `json['category'] == 'food'` |
| 9 | serialises splits as list of maps | `splits[0]['userId'] == 'bob'` |
| 10 | round-trip: fromJson → toJson → fromJson preserves data | all fields equal after round-trip |

---

## 7. Add Rating Use Case

**File:** `test/features/ratings/domain/usecases/add_rating_usecase_test.dart`  
**Class:** `lib/features/ratings/domain/usecases/add_rating_usecase.dart → AddRatingUseCase`  
**Mocks:** `MockRatingRepository extends Mock implements RatingRepository`  
**Fallback:** `FakeRating extends Fake implements Rating`

| # | Test | Expected |
|---|------|----------|
| 1 | calls repository.addRating once | `verify(mockRepo.addRating(any())).called(1)` |
| 2 | clamps stars above 5 to 5 | `rating.stars == 5` when input is 99 |
| 3 | clamps stars below 1 to 1 | `rating.stars == 1` when input is 0 |
| 4 | empty comment string becomes null | `rating.comment == null` for `'   '` |
| 5 | trims whitespace from comment | `rating.comment == 'Great food!'` |
| 6 | optional itemId is forwarded to rating | `rating.itemId == 'item-42'` |
| 7 | returns Right on success | `result.isRight() == true` |
| 8 | propagates ServerFailure from repository | `Left<ServerFailure>` |

---

## 8. Rating Model

**File:** `test/features/ratings/data/models/rating_model_test.dart`  
**Class:** `lib/features/ratings/data/models/rating_model.dart → RatingModel`  
**Mocks:** none (pure serialisation)

### `RatingModel.fromJson` (7 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | parses all fields correctly | all field values match fixture JSON |
| 2 | parses null itemId correctly | `itemId == null` |
| 3 | parses missing itemId as null | `itemId == null` |
| 4 | parses null comment correctly | `comment == null` |
| 5 | parses stars as int | `stars is int` and `stars ∈ [1, 5]` |
| 6 | createdAt is parsed as UTC | `createdAt.isUtc == true` |

### `RatingModel.toJson` (4 tests)

| # | Test | Expected |
|---|------|----------|
| 7 | serialises id correctly | `json['id'] == 'rating-1'` |
| 8 | serialises target_name correctly | `json['target_name'] == 'Senso-ji Temple'` |
| 9 | includes item_id when present | key exists and `== 'item-1'` |
| 10 | omits item_id when null | key absent from map |
| 11 | omits comment when null | key absent from map |
| 12 | round-trip preserves all fields | all fields equal after round-trip |

---

## 9. AI Generation Datasource

**File:** `test/features/ai_generation/data/datasources/ai_generation_datasource_test.dart`  
**Class:** `lib/features/ai_generation/data/datasources/ai_generation_datasource.dart → AiGenerationDataSourceImpl`  
**Mocks:** `MockDio extends Mock implements Dio` (injected via constructor)

### `generateItinerary` (7 tests)

| # | Test | Expected |
|---|------|----------|
| 1 | parses a valid JSON array from AI response | 2 items with correct title, itemType, location |
| 2 | strips markdown fences and still parses JSON | 1 item parsed from ` ```json ... ``` ` block |
| 3 | items are sorted by startTime ascending | `items[0].title == 'Morning yoga'` before evening item |
| 4 | falls back to tripStart when start_time is missing | `item.startTime == request.startDate.toUtc()` |
| 5 | throws ServerException when content is empty | throws `ServerException` |
| 6 | throws ServerException when JSON cannot be parsed | throws `ServerException` |
| 7 | throws ServerException on DioException | throws `ServerException` |

---

## Running the Tests

```bash
# All tests
flutter test

# Specific file
flutter test test/features/expense_split/domain/usecases/calculate_settlements_usecase_test.dart

# Verbose output
flutter test --reporter expanded

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Dependency

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.5
```

## Mocking Pattern

All tests that mock a repository follow this pattern:

```dart
// 1. Declare mock and (if needed) fake for any()
class MockFooRepository extends Mock implements FooRepository {}
class FakeFoo extends Fake implements Foo {}   // only needed when using any()

void main() {
  // 2. Register fallback value once, before any setUp
  setUpAll(() => registerFallbackValue(FakeFoo()));

  setUp(() {
    // 3. Fresh mock per test
    final mock = MockFooRepository();
    // 4. Stub default behaviour
    when(() => mock.doSomething(any())).thenAnswer(...);
  });
}
```

---

**End of Unit Test Reference**
