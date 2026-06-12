# Kumo Project Documentation

**Project:** Kumo - Collaborative Travel Super-App  
**Version:** 1.0.0  
**Last Updated:** June 2026

---

## Quick Start

### Prerequisites
- Flutter 3.13+
- Dart 3.12+
- Supabase account
- (Optional) Xcode for iOS, Android Studio for Android

### Setup

```bash
# Clone the repo
git clone <repo-url>
cd kumo_claude

# Install dependencies
flutter pub get

# Generate code (Riverpod, Isar, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Create .env file
cp .env.example .env
# Edit .env with your Supabase credentials

# Run the app
flutter run
```

---

## Architecture Overview

### Clean Architecture Layers

Kumo follows **Clean Architecture** with three distinct layers:

#### 1. **Domain Layer** (`lib/features/{feature}/domain/`)
- **Purpose:** Business logic, independent of frameworks
- **Contains:** Entities, repositories (abstract), usecases
- **No dependencies:** On data layer, presentation, or external libraries
- **Example:** `lib/features/auth/domain/entities/user.dart`

#### 2. **Data Layer** (`lib/features/{feature}/data/`)
- **Purpose:** Fetch and persist data from external sources
- **Contains:** Models, datasources (local/remote), repository implementations
- **Dependencies:** Domain layer only (via interfaces)
- **Example:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

#### 3. **Presentation Layer** (`lib/features/{feature}/presentation/`)
- **Purpose:** UI, state management, user interactions
- **Contains:** Pages, widgets, Riverpod providers
- **Dependencies:** Domain layer (usecases, entities)
- **State Management:** Riverpod (functional, reactive, testable)
- **Example:** `lib/features/auth/presentation/pages/login_page.dart`

### Why This Architecture?

✅ **Testability:** Each layer can be tested independently  
✅ **Maintainability:** Clear separation of concerns  
✅ **Scalability:** Easy to add new features without touching existing code  
✅ **Reusability:** Domain logic is framework-agnostic  
✅ **Flexibility:** Swap implementations (e.g., Supabase → REST API) without affecting domain

---

## State Management: Riverpod

### Why Riverpod?

- **Functional Reactivity:** No event/state classes, just functions
- **Dependency Injection:** Built-in, compile-time safe
- **Testability:** Override providers in tests with `.overrideWithValue()`
- **Performance:** Fine-grained reactivity; only affected widgets rebuild
- **Async Support:** First-class `AsyncValue` for loading/error/data states

### Provider Types

#### 1. **StateNotifier** (for complex state)
```dart
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state++;
}

final counterProvider = StateNotifierProvider((ref) => CounterNotifier());
```

#### 2. **FutureProvider** (for async operations)
```dart
final userProvider = FutureProvider((ref) async {
  return await ref.read(authRepositoryProvider).getCurrentUser();
});
```

#### 3. **StateProvider** (for simple state)
```dart
final nameProvider = StateProvider((ref) => '');
```

#### 4. **StreamProvider** (for streams)
```dart
final messagesProvider = StreamProvider((ref) {
  return supabaseClient.from('messages').stream();
});
```

### Example: Auth State Management

```dart
// Domain: Usecase
class LoginUseCase {
  Future<Either<Failure, User>> call(String email, String password) { ... }
}

// Presentation: Provider
final authProvider = StateNotifierProvider((ref) {
  final usecase = ref.watch(loginUsecaseProvider);
  return AuthNotifier(usecase);
});

// Widget: Usage
Consumer(builder: (context, ref, child) {
  final auth = ref.watch(authProvider);
  
  return auth.when(
    loading: () => LoadingWidget(),
    error: (err, st) => ErrorWidget(err),
    data: (user) => HomeWidget(user),
  );
});
```

---

## Folder Structure

```
lib/
├── config/                          # App configuration
│   ├── constants.dart              # Constants (timeouts, table names, etc.)
│   ├── environment.dart            # Environment-specific config
│   └── theme.dart                  # Material 3 theme
├── core/                           # Shared infrastructure
│   ├── error/
│   │   ├── exception.dart         # Exception classes
│   │   └── failure.dart           # Failure sealed class (type-safe errors)
│   ├── network/
│   │   └── supabase_client.dart   # Supabase initialization & wrapper
│   ├── utils/
│   │   ├── validators.dart        # Input validation utilities
│   │   ├── logger.dart            # Logging wrapper
│   │   └── formatters.dart        # Currency, date, number formatting
│   └── shared_preferences/         # Local storage wrapper (Stage 1+)
├── features/                       # Feature-based modules
│   ├── auth/                       # Authentication feature
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   └── auth_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── login_usecase.dart
│   │   │       ├── signup_usecase.dart
│   │   │       └── logout_usecase.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   ├── signup_page.dart
│   │       │   └── password_reset_page.dart
│   │       ├── widgets/
│   │       │   ├── email_input_field.dart
│   │       │   └── password_input_field.dart
│   │       └── providers/
│   │           └── auth_provider.dart
│   ├── itinerary/                  # Itinerary feature
│   │   ├── data/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── travel_itinerary.dart
│   │   │   ├── repositories/
│   │   │   │   └── itinerary_repository.dart
│   │   │   └── usecases/
│   │   │       ├── fetch_itinerary_usecase.dart
│   │   │       ├── create_itinerary_usecase.dart
│   │   │       └── update_itinerary_usecase.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   ├── chat/                       # Real-time chat (Stage 2+)
│   ├── expense_split/              # Expense splitting (Stage 4+)
│   ├── ai_generation/              # AI itinerary generation (Stage 3+)
│   └── [other features...]
├── shared/                         # Shared UI & utilities
│   ├── extensions/
│   │   └── context_extensions.dart # Shortcuts like context.theme
│   ├── mixins/
│   ├── widgets/
│   │   ├── app_scaffold.dart
│   │   ├── loading_widget.dart
│   │   └── error_widget.dart
│   └── animations/
└── main.dart                       # App entry point
```

---

## Error Handling Strategy

### Exceptions vs. Failures

- **Exceptions:** Thrown for unexpected errors (crash-level)
- **Failures:** Returned as `Either<Failure, T>` for expected errors (domain-level)

### Exception Hierarchy

```dart
KumoException
├── NetworkException
├── AuthException
├── ServerException
├── ValidationException
├── NotFoundException
├── LocalStorageException
└── UnexpectedException
```

### Failure Sealed Class

```dart
sealed class Failure extends Equatable {
  final String message;
  // ...
}

class NetworkFailure extends Failure { }
class AuthFailure extends Failure { }
class ServerFailure extends Failure { }
// ... more failure types
```

### Usage Pattern

```dart
// Repository returns Either<Failure, T>
Future<Either<Failure, User>> login(String email, String password) async {
  try {
    final user = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return Right(userFromSupabaseUser(user.user!));
  } on AuthException catch (e) {
    return Left(AuthFailure.invalidCredentials());
  } on NetworkException catch (e) {
    return Left(NetworkFailure.noInternet());
  }
}

// Use in presentation
final result = await loginUsecase(email, password);
result.fold(
  (failure) => showErrorSnackbar(failure.message),
  (user) => navigateToHome(),
);
```

---

## Testing Strategy

### Three-Tier Pyramid

```
        E2E Tests (UI flows)           5%
       Widget Tests (UI rendering)    15%
      Unit Tests (business logic)     80%
```

### Test File Organization

```
test/
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       └── login_usecase_test.dart
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl_test.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── login_page_test.dart
│   └── itinerary/
│       └── ...
└── utils/
    └── test_helpers.dart
```

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/features/auth/domain/usecases/login_usecase_test.dart

# Watch mode
flutter test --watch
```

---

## Conventions & Best Practices

### Naming

- **Classes:** PascalCase (`AuthRepository`, `LoginUseCase`)
- **Variables/Functions:** camelCase (`currentUser`, `getItineraries()`)
- **Constants:** UPPER_SNAKE_CASE (`MAX_PASSWORD_LENGTH`)
- **Files:** snake_case (`auth_repository.dart`)
- **Prefixes:** Use meaningful prefixes
  - `_private` for private members
  - `is` for booleans (`isAuthenticated`, `isEmpty`)
  - `on` for event handlers (`onTap`, `onChanged`)

### Comments & Documentation

- **Public APIs:** Use `///` (Dartdoc) with `@param`, `@returns`, `@throws`
- **Complex Logic:** Inline comments explaining "why", not "what"
- **No Noise:** Remove comments that just reiterate code
- **Example:**
  ```dart
  /// Validates email format using RFC 5322 regex.
  ///
  /// @param email The email to validate
  /// @returns true if valid, false otherwise
  /// @throws ValidationException if email is empty
  bool validateEmail(String? email) { ... }
  ```

### Imports

- **Group imports:** Dart → Flutter → Packages → Local
- **Avoid:** Wildcard imports (`import '.../*'`)
- **Example:**
  ```dart
  import 'dart:async';
  
  import 'package:flutter/material.dart';
  import 'package:riverpod/riverpod.dart';
  
  import 'package:kumo_claude/core/error/failure.dart';
  import 'features/auth/domain/repositories/auth_repository.dart';
  ```

### Code Style

- **Formatting:** Use `dart format` (run via `flutter format`)
- **Analysis:** Run `flutter analyze` regularly
- **Null Safety:** Use non-null by default; `?` only when necessary
- **Const:** Use `const` for immutable values and widgets

### Avoid

- ❌ Naked Futures (always handle with `.then()`, async/await, or Riverpod)
- ❌ Mutable global state (use Riverpod providers instead)
- ❌ Deep nesting (extract functions/widgets)
- ❌ Overly broad exception catching (catch specific exceptions)
- ❌ Synchronous blocking calls on main thread

---

## Development Workflow

### Adding a New Feature

1. **Start with Domain:** Define entities and repository interface
2. **Write Tests:** Test-driven development (TDD) first
3. **Implement Data:** Datasources and repository implementation
4. **Add Presentation:** Pages, widgets, Riverpod providers
5. **Integration Test:** Full flow in test environment
6. **Code Review:** Peer review before merge

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/user-profile

# Commit with meaningful messages
git commit -m "Add user profile page with edit functionality"

# Push and create PR
git push origin feature/user-profile
# Create PR on GitHub
```

### CI/CD Pipeline

- Pre-commit hooks: `dart format`, `flutter analyze`
- Pull request: Unit tests, code coverage
- Merge to main: Deploy to staging
- Release tag: Deploy to production

---

## Performance Optimization

### Tips

- **Lazy Load:** Don't load all itineraries at once; use pagination
- **Cache:** Isar local cache for frequently accessed data
- **Riverpod:** Use fine-grained providers to minimize rebuilds
- **Images:** Lazy load, use `Image.network` with caching
- **Profiles:** Use `flutter analyze` and DevTools for performance insights

### Benchmarks

- **Target:** UI frame rate 60 FPS (16ms per frame)
- **API Calls:** <2s max (target <500ms)
- **UI Load:** <1s from tap to render

---

## Security Best Practices

- **Tokens:** Store in secure Keychain/Keystore, never log
- **HTTPS Only:** No HTTP fallback
- **Secrets:** Use `.env` files; never commit to git
- **Input Validation:** Validate at boundaries (user input, API responses)
- **Error Leaking:** Don't expose sensitive details in error messages

---

## Deployment

### Environments

```
Development → Staging → Production
  (debug)    (release)   (release)
```

### Build & Release

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release

# App Store
cd ios && fastlane deploy_app_store

# Google Play
cd android && fastlane deploy_google_play
```

---

## Useful Resources

- [Clean Architecture](https://resocoder.com/flutter-clean-architecture)
- [Riverpod Documentation](https://riverpod.dev)
- [Supabase Flutter SDK](https://supabase.com/docs/guides/realtime/quickstarts/flutter)
- [Flutter Performance](https://flutter.dev/perf)
- [Dart Effective Dart](https://dart.dev/guides/language/effective-dart)

---

## FAQ

**Q: How do I add a new datasource (e.g., REST API)?**  
A: Create a new datasource class in `data/datasources/`, implement the interface in the repository.

**Q: When should I use Isar vs. Riverpod cache?**  
A: Isar for persistent offline data; Riverpod for session state (lost on app restart).

**Q: Can I use BLoC instead of Riverpod?**  
A: Not recommended; BLoC adds boilerplate. Riverpod is simpler for this project.

**Q: How do I handle real-time updates?**  
A: Use Riverpod's `StreamProvider` with Supabase realtime subscriptions.

---

**End of CLAUDE.md**
