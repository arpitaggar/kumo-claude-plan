import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/confirm_age_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/password_reset_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/update_password_page.dart';
import '../features/auth/presentation/providers/age_gate_provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/expense_split/presentation/pages/add_expense_page.dart';
import '../features/gamification/presentation/pages/achievements_page.dart';
import '../features/hitchhiker/presentation/pages/hitchhiker_screen.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/itinerary/domain/entities/trip_segment.dart';
import '../features/itinerary/presentation/pages/add_edit_item_page.dart';
import '../features/itinerary/presentation/pages/add_edit_trip_segment_page.dart';
import '../features/itinerary/presentation/pages/create_itinerary_page.dart';
import '../features/itinerary/presentation/pages/invite_member_page.dart';
import '../features/itinerary/presentation/pages/itinerary_detail_page.dart';
import '../features/legal/presentation/pages/privacy_policy_page.dart';
import '../features/legal/presentation/pages/terms_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../features/organization/presentation/pages/create_organization_page.dart';
import '../features/organization/presentation/pages/join_organization_page.dart';
import '../features/organization/presentation/pages/org_cost_fields_settings_page.dart';
import '../features/organization/presentation/pages/org_join_codes_page.dart';
import '../features/organization/presentation/pages/org_pending_approvals_page.dart';
import '../features/organization/presentation/pages/organization_members_page.dart';
import '../features/organization/presentation/pages/organizations_list_page.dart';
import '../features/profile/presentation/pages/edit_profile_page.dart';
import '../features/profile/presentation/pages/notification_preferences_page.dart';
import '../features/settings/presentation/pages/privacy_settings_page.dart';
import '../features/shell/inbox_page.dart';
import '../features/shell/profile_page.dart';
import '../features/shell/trips_page.dart';
import '../features/social/presentation/pages/discover_page.dart';
import '../features/social/presentation/pages/public_profile_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../shared/widgets/kumo_shell.dart';

/// Right-to-left slide transition used for all full-screen push routes.
Page<T> _slidePage<T>(Widget child, GoRouterState state) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          ),
    );

/// Lets code outside the widget tree (e.g. a notification-tap handler)
/// navigate without needing a `WidgetRef`/`BuildContext` of its own.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashPage()),
      ),

      // ── Hitchhiker (no shell, no auth — see _RouterNotifier.redirect) ──────
      GoRoute(
        path: '/hitchhiker/:token',
        pageBuilder: (context, state) => NoTransitionPage(
          child: HitchhikerScreen(token: state.pathParameters['token']!),
        ),
      ),

      // ── Auth (no shell) ────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => _slidePage(const SignupPage(), state),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            _slidePage(const PasswordResetPage(), state),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) =>
            _slidePage(const UpdatePasswordPage(), state),
      ),
      GoRoute(
        path: '/legal/privacy-policy',
        pageBuilder: (context, state) =>
            _slidePage(const PrivacyPolicyPage(), state),
      ),
      GoRoute(
        path: '/legal/terms',
        pageBuilder: (context, state) => _slidePage(const TermsPage(), state),
      ),
      GoRoute(
        path: '/confirm-age',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ConfirmAgePage()),
      ),

      // ── Onboarding (no shell) ──────────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingPage()),
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

      // ── Full-screen routes (slide transition) ──────────────────────────────
      GoRoute(
        path: '/create-trip',
        pageBuilder: (context, state) =>
            _slidePage(const CreateItineraryPage(), state),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            _slidePage(const EditProfilePage(), state),
      ),
      GoRoute(
        path: '/profile/notifications',
        pageBuilder: (context, state) =>
            _slidePage(const NotificationPreferencesPage(), state),
      ),
      GoRoute(
        path: '/u/:userId',
        pageBuilder: (context, state) => _slidePage(
          PublicProfilePage(userId: state.pathParameters['userId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _slidePage(const NotificationsPage(), state),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (context, state) =>
            _slidePage(const PrivacySettingsPage(), state),
      ),
      GoRoute(
        path: '/organizations',
        pageBuilder: (context, state) =>
            _slidePage(const OrganizationsListPage(), state),
      ),
      GoRoute(
        path: '/achievements',
        pageBuilder: (context, state) =>
            _slidePage(const AchievementsPage(), state),
      ),
      GoRoute(
        path: '/organizations/new',
        pageBuilder: (context, state) =>
            _slidePage(const CreateOrganizationPage(), state),
      ),
      GoRoute(
        path: '/organizations/join',
        pageBuilder: (context, state) => _slidePage(
          JoinOrganizationPage(initialCode: state.uri.queryParameters['code']),
          state,
        ),
      ),
      GoRoute(
        path: '/organizations/:id/members',
        pageBuilder: (context, state) => _slidePage(
          OrganizationMembersPage(orgId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/organizations/:id/approvals',
        pageBuilder: (context, state) => _slidePage(
          OrgPendingApprovalsPage(orgId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/organizations/:id/cost-fields',
        pageBuilder: (context, state) => _slidePage(
          OrgCostFieldsSettingsPage(orgId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/organizations/:id/join-codes',
        pageBuilder: (context, state) => _slidePage(
          OrgJoinCodesPage(orgId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (context, state) => _slidePage(
          ItineraryDetailPage(id: state.pathParameters['id']!),
          state,
        ),
        routes: [
          GoRoute(
            path: 'chat',
            pageBuilder: (context, state) => _slidePage(
              ChatPage(itineraryId: state.pathParameters['id']!),
              state,
            ),
          ),
          GoRoute(
            path: 'item',
            pageBuilder: (context, state) => _slidePage(
              AddEditItemPage(itineraryId: state.pathParameters['id']!),
              state,
            ),
          ),
          GoRoute(
            path: 'item/:itemId',
            pageBuilder: (context, state) => _slidePage(
              AddEditItemPage(
                itineraryId: state.pathParameters['id']!,
                itemId: state.pathParameters['itemId'],
              ),
              state,
            ),
          ),
          GoRoute(
            path: 'invite',
            pageBuilder: (context, state) => _slidePage(
              InviteMemberPage(itineraryId: state.pathParameters['id']!),
              state,
            ),
          ),
          GoRoute(
            path: 'expense/new',
            pageBuilder: (context, state) => _slidePage(
              AddExpensePage(itineraryId: state.pathParameters['id']!),
              state,
            ),
          ),
          GoRoute(
            path: 'segment',
            pageBuilder: (context, state) => _slidePage(
              AddEditTripSegmentPage(
                itineraryId: state.pathParameters['id']!,
                continueFromSegment: state.extra as TripSegment?,
              ),
              state,
            ),
          ),
          GoRoute(
            path: 'segment/:segmentId',
            pageBuilder: (context, state) => _slidePage(
              AddEditTripSegmentPage(
                itineraryId: state.pathParameters['id']!,
                segmentId: state.pathParameters['segmentId'],
              ),
              state,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
});

// Listens to auth + onboarding state and notifies GoRouter to re-run redirect
// without recreating the router (which would reset to initialLocation).
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref
      ..listen<AuthState>(
        authNotifierProvider,
        (prev, next) => notifyListeners(),
      )
      ..listen<bool?>(onboardingProvider, (prev, next) => notifyListeners())
      ..listen<bool?>(ageGateProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);
    final onboardingState = _ref.read(onboardingProvider);
    final ageGateState = _ref.read(ageGateProvider);
    final isAuthenticated = authState is AuthAuthenticated;
    final isPasswordRecovery = authState is AuthPasswordRecovery;
    // Only ever true for an invite-created (Crew) account that hasn't
    // completed confirm_age_and_finish_signup() yet — direct signup can't
    // reach an authenticated state at all without passing the age gate
    // first (see stage44_age_gate.sql). Takes priority over every other
    // authenticated route, including onboarding and deep links: nothing
    // beyond /confirm-age should be reachable until this resolves.
    final needsAgeConfirmation = isAuthenticated && ageGateState == false;
    final loc = state.matchedLocation;

    // Splash handles its own navigation — never redirect away from it.
    if (loc == '/splash') {
      return null;
    }

    // A Hitchhiker has no account and no session at all (see
    // docs/ARCHITECTURE.md) — this route must be reachable completely
    // independent of whatever auth state this device happens to be in, and
    // must never redirect to /login, /onboarding, or /confirm-age. Checked
    // before any of those gates, not just excluded from isOnAuthRoute below.
    if (loc.startsWith('/hitchhiker/')) {
      return null;
    }
    // kumo://hitchhiker?token=XYZ — same custom-scheme convention as the
    // kumo://join deep link just below.
    if (state.uri.host == 'hitchhiker' || state.uri.path == '/hitchhiker') {
      final token = state.uri.queryParameters['token'];
      return token != null && token.isNotEmpty ? '/hitchhiker/$token' : null;
    }

    // kumo://join?code=XYZ — org self-serve join-code deep link (stage35's
    // QR/manual-entry flow is the primary UX; this is a scan-free
    // alternative for a link shared by email/Slack). Not a plain GoRoute
    // path pattern: a custom-scheme URI's authority (`join`) surfaces as
    // `state.uri.host`, not `.path`, on at least one platform, so both are
    // checked defensively rather than assuming one shape.
    //
    // Only handled here when already signed in. An unauthenticated tap
    // falls through to the normal /login gate below and the code is lost —
    // the user re-enters/re-scans it after logging in. Deliberately not
    // preserved across the auth gate: doing that cleanly needs either a
    // provider write from inside redirect() or threading a query param
    // through every intermediate redirect hop (onboarding, etc.), and this
    // whole deep-link path has no device/simulator available to verify
    // against in this environment — see docs/Checklist.md.
    if (isAuthenticated &&
        !needsAgeConfirmation &&
        (state.uri.host == 'join' || state.uri.path == '/join')) {
      final code = state.uri.queryParameters['code'];
      return code != null && code.isNotEmpty
          ? '/organizations/join?code=${Uri.encodeQueryComponent(code)}'
          : '/organizations/join';
    }

    final isOnAuthRoute =
        loc == '/login' ||
        loc == '/signup' ||
        loc == '/forgot-password' ||
        loc == '/reset-password' ||
        loc == '/legal/privacy-policy' ||
        loc == '/legal/terms';

    if (isPasswordRecovery) {
      return loc == '/reset-password' ? null : '/reset-password';
    }
    if (!isAuthenticated && !isOnAuthRoute) {
      return '/login';
    }
    if (needsAgeConfirmation) {
      return loc == '/confirm-age' ? null : '/confirm-age';
    }
    if (isAuthenticated && isOnAuthRoute) {
      return onboardingState == false ? '/onboarding' : '/home';
    }
    if (isAuthenticated && onboardingState == false && loc != '/onboarding') {
      return '/onboarding';
    }
    return null;
  }
}
