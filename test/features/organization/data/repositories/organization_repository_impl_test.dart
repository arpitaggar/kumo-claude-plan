import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/data/datasources/organization_remote_datasource.dart';
import 'package:kumo_claude/features/organization/data/models/org_cost_field_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_cost_field_option_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_feature_override_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_join_code_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_member_model.dart';
import 'package:kumo_claude/features/organization/data/models/organization_model.dart';
import 'package:kumo_claude/features/organization/data/models/pending_expense_approval_model.dart';
import 'package:kumo_claude/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRemoteDataSource extends Mock
    implements OrganizationRemoteDataSource {}

void main() {
  late MockOrganizationRemoteDataSource dataSource;
  late OrganizationRepositoryImpl repository;

  final tOrg = OrganizationModel(
    id: 'org-1',
    name: 'Acme Corp',
    slug: 'acme-corp',
    ownerId: 'user-1',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  final tMember = OrgMemberModel(
    id: 'member-1',
    orgId: 'org-1',
    userId: 'user-2',
    userName: 'Bob',
    role: OrgMemberRole.member,
    joinedAt: DateTime.utc(2026),
  );

  final tApproval = PendingExpenseApprovalModel(
    expenseId: 'expense-1',
    itineraryId: 'it-1',
    tripTitle: 'Chiang Mai Trip',
    payerId: 'user-1',
    payerName: 'Alice',
    title: 'Dinner',
    amount: 90,
    currencyCode: 'USD',
    category: 'food',
    submittedAt: DateTime.utc(2026, 6),
  );

  const tField = OrgCostFieldModel(
    id: 'field-1',
    orgId: 'org-1',
    label: 'Department',
    fieldType: CostFieldType.select,
    separator: '-',
    sortOrder: 0,
  );

  const tOption = OrgCostFieldOptionModel(
    id: 'option-1',
    fieldId: 'field-1',
    value: 'Sales',
    code: 'SAL',
    sortOrder: 0,
  );

  final tJoinCode = OrgJoinCodeModel(
    id: 'code-1',
    orgId: 'org-1',
    role: OrgMemberRole.member,
    code: 'ABC123XYZ0',
    usesCount: 0,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026),
  );

  setUpAll(() {
    registerFallbackValue(OrgMemberRole.member);
    registerFallbackValue(CostFieldType.select);
  });

  setUp(() {
    dataSource = MockOrganizationRemoteDataSource();
    repository = OrganizationRepositoryImpl(dataSource: dataSource);
  });

  group('createOrganization', () {
    test('returns Right(org) on success', () async {
      when(
        () => dataSource.createOrganization(
          name: any(named: 'name'),
          slug: any(named: 'slug'),
        ),
      ).thenAnswer((_) async => tOrg);

      final result = await repository.createOrganization(
        name: 'Acme Corp',
        slug: 'acme-corp',
      );

      result.fold((_) => fail('expected Right'), (org) => expect(org, tOrg));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.createOrganization(
          name: any(named: 'name'),
          slug: any(named: 'slug'),
        ),
      ).thenThrow(ServerException(message: 'slug taken'));

      final result = await repository.createOrganization(
        name: 'Acme Corp',
        slug: 'acme-corp',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchMyOrganizations', () {
    test('returns Right(orgs) on success', () async {
      when(
        () => dataSource.fetchMyOrganizations(),
      ).thenAnswer((_) async => [tOrg]);

      final result = await repository.fetchMyOrganizations();

      result.fold(
        (_) => fail('expected Right'),
        (orgs) => expect(orgs, [tOrg]),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(
        () => dataSource.fetchMyOrganizations(),
      ).thenThrow(Exception('boom'));

      final result = await repository.fetchMyOrganizations();

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchOrgMembers', () {
    test('returns Right(members) on success', () async {
      when(
        () => dataSource.fetchOrgMembers(any()),
      ).thenAnswer((_) async => [tMember]);

      final result = await repository.fetchOrgMembers('org-1');

      result.fold(
        (_) => fail('expected Right'),
        (members) => expect(members, [tMember]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchOrgMembers(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchOrgMembers('org-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('inviteMember', () {
    test('returns Right(member) on success', () async {
      when(
        () => dataSource.inviteMember(
          orgId: any(named: 'orgId'),
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => tMember);

      final result = await repository.inviteMember(
        orgId: 'org-1',
        email: 'bob@example.com',
        role: OrgMemberRole.member,
      );

      result.fold(
        (_) => fail('expected Right'),
        (member) => expect(member, tMember),
      );
    });

    test('maps NotFoundException to NotFoundFailure', () async {
      when(
        () => dataSource.inviteMember(
          orgId: any(named: 'orgId'),
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenThrow(NotFoundException(message: 'no account for this email'));

      final result = await repository.inviteMember(
        orgId: 'org-1',
        email: 'nobody@example.com',
        role: OrgMemberRole.member,
      );

      result.fold(
        (f) => expect(f, isA<NotFoundFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.inviteMember(
          orgId: any(named: 'orgId'),
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.inviteMember(
        orgId: 'org-1',
        email: 'bob@example.com',
        role: OrgMemberRole.member,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateMemberRole', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.updateMemberRole(
          orgMemberId: any(named: 'orgMemberId'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updateMemberRole(
        orgMemberId: 'member-1',
        role: OrgMemberRole.admin,
      );

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.updateMemberRole(
          orgMemberId: any(named: 'orgMemberId'),
          role: any(named: 'role'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.updateMemberRole(
        orgMemberId: 'member-1',
        role: OrgMemberRole.admin,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('removeMember', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.removeMember(any())).thenAnswer((_) async {});

      final result = await repository.removeMember('member-1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.removeMember(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.removeMember('member-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchPendingApprovals', () {
    test('returns Right(approvals) on success', () async {
      when(
        () => dataSource.fetchPendingApprovals(any()),
      ).thenAnswer((_) async => [tApproval]);

      final result = await repository.fetchPendingApprovals('org-1');

      result.fold(
        (_) => fail('expected Right'),
        (approvals) => expect(approvals, [tApproval]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchPendingApprovals(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchPendingApprovals('org-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('approveExpense', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.approveExpense(any())).thenAnswer((_) async {});

      final result = await repository.approveExpense('expense-1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.approveExpense(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.approveExpense('expense-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('rejectExpense', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.rejectExpense(any(), any()),
      ).thenAnswer((_) async {});

      final result = await repository.rejectExpense('expense-1', 'too high');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.rejectExpense(any(), any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.rejectExpense('expense-1', 'too high');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchOrgCostFields', () {
    test('returns Right(fields) on success', () async {
      when(
        () => dataSource.fetchOrgCostFields(any()),
      ).thenAnswer((_) async => [tField]);

      final result = await repository.fetchOrgCostFields('org-1');

      result.fold(
        (_) => fail('expected Right'),
        (fields) => expect(fields, [tField]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchOrgCostFields(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchOrgCostFields('org-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('createCostField', () {
    test(
      'returns Right(field) on success, defaulting separator/sourceFieldIds',
      () async {
        when(
          () => dataSource.createCostField(
            orgId: any(named: 'orgId'),
            label: any(named: 'label'),
            fieldType: any(named: 'fieldType'),
            separator: any(named: 'separator'),
            sourceFieldIds: any(named: 'sourceFieldIds'),
          ),
        ).thenAnswer((_) async => tField);

        final result = await repository.createCostField(
          orgId: 'org-1',
          label: 'Department',
          fieldType: CostFieldType.select,
        );

        verify(
          () => dataSource.createCostField(
            orgId: 'org-1',
            label: 'Department',
            fieldType: CostFieldType.select,
            separator: '-',
            sourceFieldIds: const [],
          ),
        ).called(1);
        result.fold(
          (_) => fail('expected Right'),
          (field) => expect(field, tField),
        );
      },
    );

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.createCostField(
          orgId: any(named: 'orgId'),
          label: any(named: 'label'),
          fieldType: any(named: 'fieldType'),
          separator: any(named: 'separator'),
          sourceFieldIds: any(named: 'sourceFieldIds'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.createCostField(
        orgId: 'org-1',
        label: 'Department',
        fieldType: CostFieldType.select,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteCostField', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.deleteCostField(any())).thenAnswer((_) async {});

      final result = await repository.deleteCostField('field-1');

      expect(result, const Right<Failure, void>(null));
    });

    test(
      'maps ServerException to ServerFailure (e.g. field still in use)',
      () async {
        when(
          () => dataSource.deleteCostField(any()),
        ).thenThrow(ServerException(message: 'field still in use'));

        final result = await repository.deleteCostField('field-1');

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('addCostFieldOption', () {
    test('returns Right(option) on success', () async {
      when(
        () => dataSource.addCostFieldOption(
          fieldId: any(named: 'fieldId'),
          value: any(named: 'value'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => tOption);

      final result = await repository.addCostFieldOption(
        fieldId: 'field-1',
        value: 'Sales',
        code: 'SAL',
      );

      result.fold(
        (_) => fail('expected Right'),
        (option) => expect(option, tOption),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.addCostFieldOption(
          fieldId: any(named: 'fieldId'),
          value: any(named: 'value'),
          code: any(named: 'code'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.addCostFieldOption(
        fieldId: 'field-1',
        value: 'Sales',
        code: 'SAL',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteCostFieldOption', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.deleteCostFieldOption(any()),
      ).thenAnswer((_) async {});

      final result = await repository.deleteCostFieldOption('option-1');

      expect(result, const Right<Failure, void>(null));
    });

    test(
      'maps ServerException to ServerFailure (e.g. option still assigned)',
      () async {
        when(
          () => dataSource.deleteCostFieldOption(any()),
        ).thenThrow(ServerException(message: 'option still assigned'));

        final result = await repository.deleteCostFieldOption('option-1');

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('previewCostCenterCode', () {
    test('returns Right(code) on success', () async {
      when(
        () => dataSource.previewCostCenterCode(
          orgId: any(named: 'orgId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => 'SAL-FAL');

      final result = await repository.previewCostCenterCode(
        orgId: 'org-1',
        selections: const {'field-1': 'option-1'},
      );

      result.fold(
        (_) => fail('expected Right'),
        (code) => expect(code, 'SAL-FAL'),
      );
    });

    test('returns Right(null) when the selections are incomplete', () async {
      when(
        () => dataSource.previewCostCenterCode(
          orgId: any(named: 'orgId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => null);

      final result = await repository.previewCostCenterCode(
        orgId: 'org-1',
        selections: const {},
      );

      result.fold((_) => fail('expected Right'), (code) => expect(code, null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.previewCostCenterCode(
          orgId: any(named: 'orgId'),
          selections: any(named: 'selections'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.previewCostCenterCode(
        orgId: 'org-1',
        selections: const {'field-1': 'option-1'},
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchJoinCodes', () {
    test('returns Right(codes) on success', () async {
      when(
        () => dataSource.fetchJoinCodes(any()),
      ).thenAnswer((_) async => [tJoinCode]);

      final result = await repository.fetchJoinCodes('org-1');

      result.fold(
        (_) => fail('expected Right'),
        (codes) => expect(codes, [tJoinCode]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchJoinCodes(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchJoinCodes('org-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('generateJoinCode', () {
    test('returns Right(code) on success', () async {
      when(
        () => dataSource.generateJoinCode(
          orgId: any(named: 'orgId'),
          role: any(named: 'role'),
          costFieldOptionId: any(named: 'costFieldOptionId'),
          expiresAt: any(named: 'expiresAt'),
          maxUses: any(named: 'maxUses'),
        ),
      ).thenAnswer((_) async => tJoinCode);

      final result = await repository.generateJoinCode(
        orgId: 'org-1',
        role: OrgMemberRole.member,
      );

      result.fold(
        (_) => fail('expected Right'),
        (code) => expect(code, tJoinCode),
      );
    });

    test(
      'maps ServerException to ServerFailure (e.g. caller is not an admin)',
      () async {
        when(
          () => dataSource.generateJoinCode(
            orgId: any(named: 'orgId'),
            role: any(named: 'role'),
            costFieldOptionId: any(named: 'costFieldOptionId'),
            expiresAt: any(named: 'expiresAt'),
            maxUses: any(named: 'maxUses'),
          ),
        ).thenThrow(ServerException(message: 'Only org admins can do this'));

        final result = await repository.generateJoinCode(
          orgId: 'org-1',
          role: OrgMemberRole.member,
        );

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('revokeJoinCode', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.revokeJoinCode(any())).thenAnswer((_) async {});

      final result = await repository.revokeJoinCode('code-1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.revokeJoinCode(any()),
      ).thenThrow(ServerException(message: 'Only org admins can do this'));

      final result = await repository.revokeJoinCode('code-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('redeemJoinCode', () {
    test('returns Right(org) on success', () async {
      when(
        () => dataSource.redeemJoinCode(any()),
      ).thenAnswer((_) async => tOrg);

      final result = await repository.redeemJoinCode('ABC123XYZ0');

      result.fold((_) => fail('expected Right'), (org) => expect(org, tOrg));
    });

    for (final message in [
      'This code is invalid',
      'This code has been revoked',
      'This code has expired',
      'This code has already been used the maximum number of times',
      'You are already a member of this organization',
    ]) {
      test('passes the RPC-raised message "$message" through unchanged as a '
          'ServerFailure', () async {
        when(
          () => dataSource.redeemJoinCode(any()),
        ).thenThrow(ServerException(message: message));

        final result = await repository.redeemJoinCode('ABC123XYZ0');

        result.fold(
          (f) => expect(f.message, message),
          (_) => fail('expected Left'),
        );
      });
    }
  });

  group('setOrgDefaultApprovalThreshold', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.setOrgDefaultApprovalThreshold(
          orgId: any(named: 'orgId'),
          threshold: any(named: 'threshold'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: 100,
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => dataSource.setOrgDefaultApprovalThreshold(
          orgId: 'org-1',
          threshold: 100,
        ),
      ).called(1);
    });

    test('maps ServerException to ServerFailure (e.g. not an admin)', () async {
      when(
        () => dataSource.setOrgDefaultApprovalThreshold(
          orgId: any(named: 'orgId'),
          threshold: any(named: 'threshold'),
        ),
      ).thenThrow(ServerException(message: 'not an admin'));

      final result = await repository.setOrgDefaultApprovalThreshold(
        orgId: 'org-1',
        threshold: 100,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('setCostFieldOptionApprovalThreshold', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.setCostFieldOptionApprovalThreshold(
          optionId: any(named: 'optionId'),
          threshold: any(named: 'threshold'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.setCostFieldOptionApprovalThreshold(
        optionId: 'option-1',
        threshold: 25,
      );

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.setCostFieldOptionApprovalThreshold(
          optionId: any(named: 'optionId'),
          threshold: any(named: 'threshold'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.setCostFieldOptionApprovalThreshold(
        optionId: 'option-1',
        threshold: 25,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchFeatureOverrides', () {
    const tOverride = OrgFeatureOverrideModel(
      id: 'ovr-1',
      costFieldOptionId: 'option-1',
      featureKey: 'google_maps',
      enabled: true,
    );

    test('returns Right(overrides) on success', () async {
      when(
        () => dataSource.fetchFeatureOverrides(any()),
      ).thenAnswer((_) async => [tOverride]);

      final result = await repository.fetchFeatureOverrides('option-1');

      result.fold(
        (_) => fail('expected Right'),
        (overrides) => expect(overrides, [tOverride]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchFeatureOverrides(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchFeatureOverrides('option-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('setFeatureOverride', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.setFeatureOverride(
          optionId: any(named: 'optionId'),
          featureKey: any(named: 'featureKey'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.setFeatureOverride(
        optionId: 'option-1',
        featureKey: 'google_maps',
        enabled: true,
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => dataSource.setFeatureOverride(
          optionId: 'option-1',
          featureKey: 'google_maps',
          enabled: true,
        ),
      ).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.setFeatureOverride(
          optionId: any(named: 'optionId'),
          featureKey: any(named: 'featureKey'),
          enabled: any(named: 'enabled'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.setFeatureOverride(
        optionId: 'option-1',
        featureKey: 'google_maps',
        enabled: true,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
