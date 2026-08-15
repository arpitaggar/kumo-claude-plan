# Kumo Project Documentation

**Project:** Kumo - Collaborative Travel Super-App  
**Version:** 1.0.0  
**Last Updated:** August 2026

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

## Development Workflow

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

- Pre-commit hooks: `dart format`, `flutter analyze`, and an age-gate migration-coverage check (SEC-033 future-proofing — every new Supabase table must either get the `require_age_verified()` trigger or an explicit exemption comment) — enforced locally via `./scripts/install-git-hooks.sh` (run once per clone; see `scripts/CLAUDE.md`). Not yet wired into a CI service — currently solo development with no PR review process.
- Pull request: Unit tests, code coverage
- Merge to main: Deploy to staging
- Release tag: Deploy to production

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
