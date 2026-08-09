import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/expense_split/data/datasources/expense_remote_datasource.dart';
import 'package:kumo_claude/features/expense_split/data/models/expense_model.dart';
import 'package:kumo_claude/features/expense_split/data/repositories/expense_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseRemoteDataSource extends Mock
    implements ExpenseRemoteDataSource {}

void main() {
  late MockExpenseRemoteDataSource dataSource;
  late ExpenseRepositoryImpl repository;

  final tExpense = ExpenseModel.fromJson({
    'id': 'expense-1',
    'itinerary_id': 'it-1',
    'title': 'Dinner',
    'amount': 90.0,
    'currency_code': 'USD',
    'category': 'food',
    'payer_id': 'alice',
    'payer_name': 'Alice',
    'splits': <Map<String, dynamic>>[],
    'created_at': '2026-06-01T12:00:00.000Z',
  });

  setUp(() {
    dataSource = MockExpenseRemoteDataSource();
    repository = ExpenseRepositoryImpl(dataSource: dataSource);
  });

  group('watchExpenses', () {
    // Regression coverage: this stream used to be built with
    // `.map(Right.new).handleError((e) => Left(...))` — Stream.handleError's
    // callback return value is silently discarded, so a data-source stream
    // error used to vanish instead of ever reaching subscribers as a
    // Left(Failure). See the matching fix's comment in
    // lib/features/expense_split/data/repositories/expense_repository_impl.dart.
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchExpenses('it-1'),
      ).thenAnswer((_) => Stream.value([tExpense]));

      final result = await repository.watchExpenses('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (expenses) => expect(expenses, [tExpense]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchExpenses('it-1')).thenAnswer(
          (_) => Stream<List<ExpenseModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchExpenses('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
