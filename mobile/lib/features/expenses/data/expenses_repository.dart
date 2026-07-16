import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'expense_dto.dart';

class ExpensesRepository {
  ExpensesRepository(this._dio);

  final Dio _dio;

  Future<List<Expense>> listExpenses(String groupId) async {
    final res = await _dio.get<List<dynamic>>('/groups/$groupId/expenses');
    final data = res.data ?? const [];
    return data
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates an expense. [entries] pairs each participant member id with an
  /// optional value whose meaning depends on [method]: exact -> minor units,
  /// percentage -> whole percent, shares -> weight; ignored for equal.
  Future<Expense> createExpense({
    required String groupId,
    required String description,
    required int amountMinor,
    required String paidBy,
    required String method,
    required List<({String memberId, int? value})> entries,
    String? category,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/groups/$groupId/expenses',
      data: {
        'description': description,
        'amount_minor': amountMinor,
        'paid_by': paidBy,
        'split': {
          'method': method,
          'entries': entries
              .map((e) => {'member_id': e.memberId, 'value': ?e.value})
              .toList(),
        },
        'category': ?category,
      },
    );
    return Expense.fromJson(res.data!);
  }

  Future<Expense> updateExpense({
    required String groupId,
    required String expenseId,
    required String description,
    required int amountMinor,
    required String paidBy,
    required String method,
    required List<({String memberId, int? value})> entries,
    String? category,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/groups/$groupId/expenses/$expenseId',
      data: {
        'description': description,
        'amount_minor': amountMinor,
        'paid_by': paidBy,
        'split': {
          'method': method,
          'entries': entries
              .map((e) => {'member_id': e.memberId, 'value': ?e.value})
              .toList(),
        },
        'category': ?category,
      },
    );
    return Expense.fromJson(res.data!);
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
  }) async {
    await _dio.delete<void>('/groups/$groupId/expenses/$expenseId');
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(dioProvider));
});
