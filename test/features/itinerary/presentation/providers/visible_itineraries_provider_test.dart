import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockFetchItinerariesUseCase extends Mock
    implements FetchItinerariesUseCase {}

User _user(String id) =>
    User(id: id, email: '$id@example.com', createdAt: DateTime.utc(2026));

Organization _org(String id) => Organization(
  id: id,
  name: 'Acme Corp',
  slug: id,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip({
  required String id,
  required String ownerId,
  String? orgId,
  List<GroupMember> members = const [],
}) => TravelItinerary(
  id: id,
  title: id,
  ownerId: ownerId,
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2026, 6, 7),
  totalBudget: 1000,
  currencyCode: 'USD',
  members: members,
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  orgId: orgId,
);

void main() {
  setUpAll(initTestSupabase);

  Future<ProviderContainer> buildContainer({
    required List<TravelItinerary> allTrips,
    required bool workModeActive,
    Organization? workOrg,
  }) async {
    final authRepo = MockAuthRepository();
    when(
      authRepo.getCurrentUser,
    ).thenAnswer((_) async => Right(_user('user-1')));
    final logoutUseCase = MockLogoutUseCase();
    when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

    final fetchItinerariesUseCase = MockFetchItinerariesUseCase();
    when(
      () => fetchItinerariesUseCase('user-1'),
    ).thenAnswer((_) async => Right(allTrips));

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: MockLoginUseCase(),
            signupUseCase: MockSignupUseCase(),
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: MockDeleteAccountUseCase(),
            repository: authRepo,
          ),
        ),
        fetchItinerariesUseCaseProvider.overrideWithValue(
          fetchItinerariesUseCase,
        ),
        isWorkModeActiveProvider.overrideWithValue(workModeActive),
        currentWorkOrgProvider.overrideWithValue(workOrg),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authNotifierProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await container
        .read(itineraryListProvider.notifier)
        .loadItineraries('user-1');
    return container;
  }

  test('Private Mode shows only untagged (personal) trips — org-tagged '
      'trips are excluded even if the user owns them', () async {
    final personalOwn = _trip(id: 'personal-own', ownerId: 'user-1');
    final workOwn = _trip(id: 'work-own', ownerId: 'user-1', orgId: 'org-1');
    final container = await buildContainer(
      allTrips: [personalOwn, workOwn],
      workModeActive: false,
    );

    final visible = container.read(visibleItinerariesProvider);

    expect(visible.map((t) => t.id), [personalOwn.id]);
  });

  test(
    'Work Mode shows only the current org\'s trips the user owns or is a '
    'member of — never an admin-oversight view of teammates\' trips',
    () async {
      final org = _org('org-1');
      final ownedAtOrg = _trip(id: 'owned', ownerId: 'user-1', orgId: 'org-1');
      final memberAtOrg = _trip(
        id: 'member',
        ownerId: 'user-2',
        orgId: 'org-1',
        members: [
          GroupMember(
            userId: 'user-1',
            userName: 'Me',
            role: GroupMemberRole.editor,
            joinedAt: DateTime.utc(2026),
          ),
        ],
      );
      final teammateOnlyAtOrg = _trip(
        id: 'teammate-only',
        ownerId: 'user-2',
        orgId: 'org-1',
      );
      final differentOrg = _trip(
        id: 'different-org',
        ownerId: 'user-1',
        orgId: 'org-2',
      );
      final personal = _trip(id: 'personal', ownerId: 'user-1');

      final container = await buildContainer(
        allTrips: [
          ownedAtOrg,
          memberAtOrg,
          teammateOnlyAtOrg,
          differentOrg,
          personal,
        ],
        workModeActive: true,
        workOrg: org,
      );

      final visible = container.read(visibleItinerariesProvider);

      expect(visible.map((t) => t.id).toSet(), {ownedAtOrg.id, memberAtOrg.id});
    },
  );
}
