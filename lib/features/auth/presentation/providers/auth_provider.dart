import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (_) => const AuthRemoteDataSourceImpl(),
);

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSourceImpl(
    ref.watch(sharedPreferencesProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepositoryImpl>(
  (ref) => AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final signupUseCaseProvider = Provider<SignupUseCase>(
  (ref) => SignupUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

class AuthPasswordRecovery extends AuthState {
  const AuthPasswordRecovery();
}

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required this.loginUseCase,
    required this.signupUseCase,
    required this.logoutUseCase,
    required this.repository,
  }) : super(const AuthInitial()) {
    _checkCurrentUser();
    _authSubscription = KumoSupabaseClient.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.passwordRecovery) {
        state = const AuthPasswordRecovery();
      }
    });
  }

  final LoginUseCase loginUseCase;
  final SignupUseCase signupUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepositoryImpl repository;
  StreamSubscription<sb.AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    state = const AuthLoading();
    final result = await repository.getCurrentUser();
    result.fold(
      (_) => state = const AuthUnauthenticated(),
      (user) => state =
          user != null ? AuthAuthenticated(user) : const AuthUnauthenticated(),
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    final result = await loginUseCase(email: email, password: password);
    result.fold(
      (failure) => state = AuthError(failure.message),
      (user) => state = AuthAuthenticated(user),
    );
  }

  Future<void> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthLoading();
    final result = await signupUseCase(
      email: email,
      password: password,
      displayName: displayName,
    );
    result.fold(
      (failure) => state = AuthError(failure.message),
      (user) => state = AuthAuthenticated(user),
    );
  }

  Future<void> logout() async {
    state = const AuthLoading();
    final result = await logoutUseCase();
    result.fold(
      (failure) => state = AuthError(failure.message),
      (_) => state = const AuthUnauthenticated(),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AuthLoading();
    final result = await repository.resetPassword(newPassword: newPassword);
    await result.fold(
      (failure) async => state = AuthError(failure.message),
      (_) async {
        await repository.logout();
        state = const AuthUnauthenticated();
      },
    );
  }

  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    signupUseCase: ref.watch(signupUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    repository: ref.watch(authRepositoryProvider),
  ),
);
