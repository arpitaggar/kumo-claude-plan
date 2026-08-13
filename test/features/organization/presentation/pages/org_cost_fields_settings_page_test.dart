import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/core/premium/premium_feature.dart';
import 'package:kumo_claude/core/premium/premium_providers.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field_option.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/add_org_cost_field_option_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/create_org_cost_field_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/delete_org_cost_field_option_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/delete_org_cost_field_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_cost_field_option_approval_threshold_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_feature_override_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/set_org_default_approval_threshold_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/org_cost_fields_settings_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

const _orgId = 'org-1';

Organization _org({double? threshold}) => Organization(
  id: _orgId,
  name: 'Acme Corp',
  slug: _orgId,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  defaultApprovalThreshold: threshold,
);

OrgCostFieldOption _option({
  String id = 'opt-1',
  String value = 'Sales',
  String code = 'SAL',
  double? threshold,
}) => OrgCostFieldOption(
  id: id,
  fieldId: 'field-1',
  value: value,
  code: code,
  sortOrder: 0,
  approvalThreshold: threshold,
);

OrgCostField _selectField({
  String id = 'field-1',
  String label = 'Department',
  List<OrgCostFieldOption> options = const [],
}) => OrgCostField(
  id: id,
  orgId: _orgId,
  label: label,
  fieldType: CostFieldType.select,
  separator: '-',
  sortOrder: 0,
  options: options,
);

void main() {
  late MockOrganizationRepository mockRepo;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    registerFallbackValue(CostFieldType.select);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<OrgCostField> fields = const [],
    Organization? org,
    List<PremiumFeature> features = const [],
  }) async {
    final router = GoRouter(
      initialLocation: '/cost-fields',
      routes: [
        GoRoute(
          path: '/cost-fields',
          builder: (_, _) => const OrgCostFieldsSettingsPage(orgId: _orgId),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orgCostFieldsProvider(_orgId).overrideWith((ref) async => fields),
          myOrganizationsProvider.overrideWith((ref) async => [org ?? _org()]),
          featureFlagsProvider.overrideWith(
            (ref) async => {for (final f in features) f.featureKey: f},
          ),
          createOrgCostFieldUseCaseProvider.overrideWithValue(
            CreateOrgCostFieldUseCase(mockRepo),
          ),
          deleteOrgCostFieldUseCaseProvider.overrideWithValue(
            DeleteOrgCostFieldUseCase(mockRepo),
          ),
          addOrgCostFieldOptionUseCaseProvider.overrideWithValue(
            AddOrgCostFieldOptionUseCase(mockRepo),
          ),
          deleteOrgCostFieldOptionUseCaseProvider.overrideWithValue(
            DeleteOrgCostFieldOptionUseCase(mockRepo),
          ),
          setOrgDefaultApprovalThresholdUseCaseProvider.overrideWithValue(
            SetOrgDefaultApprovalThresholdUseCase(mockRepo),
          ),
          setCostFieldOptionApprovalThresholdUseCaseProvider.overrideWithValue(
            SetCostFieldOptionApprovalThresholdUseCase(mockRepo),
          ),
          setFeatureOverrideUseCaseProvider.overrideWithValue(
            SetFeatureOverrideUseCase(mockRepo),
          ),
          // The department-settings sheet always reads this for whichever
          // option it was opened for; every test in this file only ever
          // opens it for 'opt-1', so one static override covers all of them
          // — same "bypass the usecase chain entirely" approach the family
          // providers above use, avoiding a real organizationRepositoryProvider
          // build (which would need live Supabase).
          featureOverridesProvider(
            'opt-1',
          ).overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state renders when the org has no cost fields yet', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.textContaining('No cost-tracking fields yet'), findsOneWidget);
    // Regression: the threshold card used to be nested inside the non-empty
    // fields ListView, so an org with zero cost fields had no way at all to
    // set an org-wide default threshold. Now always rendered — see the fix
    // in org_cost_fields_settings_page.dart.
    expect(find.text('Default approval threshold'), findsOneWidget);
  });

  testWidgets('renders a select field with its option count, and the org '
      'default threshold summary', (tester) async {
    await pumpPage(
      tester,
      fields: [
        _selectField(options: [_option()]),
      ],
      org: _org(threshold: 50),
    );

    expect(find.text('Department'), findsOneWidget);
    expect(find.text('1 value'), findsOneWidget);
    expect(find.text('Auto-approves expenses under 50.0'), findsOneWidget);
  });

  testWidgets('a generated field shows its computed-from summary instead '
      'of an option count', (tester) async {
    await pumpPage(
      tester,
      fields: [
        _selectField(options: [_option()]),
        const OrgCostField(
          id: 'field-2',
          orgId: _orgId,
          label: 'Cost Center',
          fieldType: CostFieldType.generated,
          separator: '-',
          sortOrder: 1,
          sourceFieldIds: ['field-1'],
        ),
      ],
    );

    expect(find.text('Cost Center'), findsOneWidget);
    expect(find.text('Generated from Department'), findsOneWidget);
  });

  testWidgets(
    'expanding a select field shows its options with codes and thresholds',
    (tester) async {
      await pumpPage(
        tester,
        fields: [
          _selectField(options: [_option(threshold: 25)]),
        ],
      );

      await tester.tap(find.text('Department'));
      await tester.pumpAndSettle();

      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('SAL · auto-approves under 25.0'), findsOneWidget);
    },
  );

  testWidgets('adding a field calls the usecase with the entered label', (
    tester,
  ) async {
    when(
      () => mockRepo.createCostField(
        orgId: any(named: 'orgId'),
        label: any(named: 'label'),
        fieldType: any(named: 'fieldType'),
        separator: any(named: 'separator'),
        sourceFieldIds: any(named: 'sourceFieldIds'),
      ),
    ).thenAnswer((_) async => Right(_selectField(label: 'Project')));

    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Project');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    verify(
      () => mockRepo.createCostField(
        orgId: _orgId,
        label: 'Project',
        fieldType: CostFieldType.select,
        separator: '-',
        sourceFieldIds: const [],
      ),
    ).called(1);
  });

  testWidgets('adding a field with an empty label never calls the usecase', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepo.createCostField(
        orgId: any(named: 'orgId'),
        label: any(named: 'label'),
        fieldType: any(named: 'fieldType'),
        separator: any(named: 'separator'),
        sourceFieldIds: any(named: 'sourceFieldIds'),
      ),
    );
  });

  testWidgets('deleting a field confirms then calls the usecase', (
    tester,
  ) async {
    when(
      () => mockRepo.deleteCostField('field-1'),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester, fields: [_selectField()]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete field?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.deleteCostField('field-1')).called(1);
  });

  testWidgets('a failed field deletion shows the failure message', (
    tester,
  ) async {
    when(() => mockRepo.deleteCostField('field-1')).thenAnswer(
      (_) async => const Left(
        ServerFailure('This value is in use and can\'t be deleted'),
      ),
    );

    await pumpPage(tester, fields: [_selectField()]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text("This value is in use and can't be deleted"),
      findsOneWidget,
    );
  });

  testWidgets('adding an option to a select field calls the usecase with '
      'value and code', (tester) async {
    when(
      () => mockRepo.addCostFieldOption(
        fieldId: any(named: 'fieldId'),
        value: any(named: 'value'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => Right(_option()));

    await pumpPage(tester, fields: [_selectField()]);

    await tester.tap(find.text('Department'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add value'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Marketing');
    await tester.enterText(fields.at(1), 'MKT');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    verify(
      () => mockRepo.addCostFieldOption(
        fieldId: 'field-1',
        value: 'Marketing',
        code: 'MKT',
      ),
    ).called(1);
  });

  testWidgets('editing the org default threshold calls the usecase with '
      'the parsed amount', (tester) async {
    when(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: any(named: 'orgId'),
        threshold: any(named: 'threshold'),
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester);

    await tester.tap(find.text('Default approval threshold'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    verify(
      () => mockRepo.setOrgDefaultApprovalThreshold(
        orgId: _orgId,
        threshold: 100,
      ),
    ).called(1);
  });

  testWidgets('opening department settings shows the threshold row and '
      'toggles a gated feature override', (tester) async {
    when(
      () => mockRepo.setFeatureOverride(
        optionId: any(named: 'optionId'),
        featureKey: any(named: 'featureKey'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(
      tester,
      fields: [
        _selectField(options: [_option()]),
      ],
      features: const [
        PremiumFeature(featureKey: 'ai_itinerary', requiresPremium: true),
      ],
    );

    await tester.tap(find.text('Department'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Sales'), findsWidgets);
    expect(find.text('Approval threshold'), findsOneWidget);
    expect(find.text('ai_itinerary'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    verify(
      () => mockRepo.setFeatureOverride(
        optionId: 'opt-1',
        featureKey: 'ai_itinerary',
        enabled: true,
      ),
    ).called(1);
  });

  testWidgets('department settings with no gated features shows the '
      'nothing-to-grant message', (tester) async {
    await pumpPage(
      tester,
      fields: [
        _selectField(options: [_option()]),
      ],
    );

    await tester.tap(find.text('Department'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('No premium features to grant yet.'), findsOneWidget);
  });
}
