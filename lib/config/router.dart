import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/password_reset_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/update_password_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/expense_split/presentation/pages/add_expense_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/itinerary/presentation/pages/add_edit_item_page.dart';
import '../features/itinerary/presentation/pages/create_itinerary_page.dart';
import '../features/itinerary/presentation/pages/invite_member_page.dart';
import '../features/itinerary/presentation/pages/itinerary_detail_page.dart';
import '../features/profile/presentation/pages/edit_profile_page.dart';
import '../features/settings/presentation/pages/privacy_settings_page.dart';
import '../features/shell/discover_page.dart';
import '../features/shell/inbox_page.dart';
import '../features/shell/profile_page.dart';
import '../features/shell/trips_page.dart';
import '../shared/widgets/kumo_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState is AuthAuthenticated;
      final isPasswordRecovery = authState is AuthPasswordRecovery;
      final loc = state.matchedLocation;
      final isOnAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password' ||
          loc == '/reset-password';

      if (isPasswordRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (!isAuthenticated && !isOnAuthRoute) {
        return '/login';
      }
      if (isAuthenticated && isOnAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      // ── Auth (no shell) ────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            const MaterialPage(child: SignupPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: PasswordResetPage()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: UpdatePasswordPage()),
      ),

      // ── Main app shell (bottom nav) ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => KumoShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/trips',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TripsPage()),
          ),
          GoRoute(
            path: '/inbox',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InboxPage()),
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DiscoverPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      ),

      // ── Full-screen routes (no shell) ──────────────────────────────────────
      GoRoute(
        path: '/create-trip',
        pageBuilder: (context, state) =>
            const MaterialPage(child: CreateItineraryPage()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            const MaterialPage(child: EditProfilePage()),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) =>
            const MaterialPage(child: PrivacySettingsPage()),
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (context, state) => MaterialPage(
          child: ItineraryDetailPage(id: state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'chat',
            pageBuilder: (context, state) => MaterialPage(
              child: ChatPage(itineraryId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'item',
            pageBuilder: (context, state) => MaterialPage(
              child: AddEditItemPage(
                itineraryId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'item/:itemId',
            pageBuilder: (context, state) => MaterialPage(
              child: AddEditItemPage(
                itineraryId: state.pathParameters['id']!,
                itemId: state.pathParameters['itemId'],
              ),
            ),
          ),
          GoRoute(
            path: 'invite',
            pageBuilder: (context, state) => MaterialPage(
              child: InviteMemberPage(
                itineraryId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'expense/new',
            pageBuilder: (context, state) => MaterialPage(
              child: AddExpensePage(
                itineraryId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
