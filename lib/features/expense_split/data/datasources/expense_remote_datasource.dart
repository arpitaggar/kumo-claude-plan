import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/expense_model.dart';

abstract class ExpenseRemoteDataSource {
  Stream<List<ExpenseModel>> watchExpenses(String itineraryId);
  Future<ExpenseModel> addExpense(ExpenseModel model);
  Future<void> deleteExpense(String expenseId);
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  const ExpenseRemoteDataSourceImpl();

  static const _table = 'expenses';

  @override
  Stream<List<ExpenseModel>> watchExpenses(String itineraryId) =>
      KumoSupabaseClient.client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('itinerary_id', itineraryId)
          .order('created_at')
          .map((rows) => rows.map(ExpenseModel.fromJson).toList());

  @override
  Future<ExpenseModel> addExpense(ExpenseModel model) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_table)
          .insert(model.toJson())
          .select();
      return ExpenseModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .delete()
          .eq('id', expenseId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
