import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/money.dart';
import '../../features/statement_import/domain/installment_matcher.dart';
import '../../features/statement_import/domain/review_line.dart';
import '../../features/statement_import/domain/statement_models.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

final statementRepositoryProvider = Provider<StatementRepository>((ref) {
  return StatementRepository(ref.watch(supabaseClientProvider));
});

class ImportSummary {
  const ImportSummary({
    required this.importId,
    required this.imported,
    required this.alreadyImported,
    required this.skipped,
    required this.failed,
    required this.duplicateStatement,
  });

  factory ImportSummary.fromJson(Map<String, dynamic> json) => ImportSummary(
        importId: json['import_id'] as String?,
        imported: (json['imported'] as num?)?.toInt() ?? 0,
        alreadyImported: (json['already_imported'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        duplicateStatement: json['duplicate_statement'] == true,
      );

  final String? importId;
  final int imported;
  final int alreadyImported;
  final int skipped;
  final int failed;
  final bool duplicateStatement;
}

class StatementRepository {
  StatementRepository(this._client);

  final SupabaseClient _client;

  Future<Set<String>> importedKeys(String householdId) async {
    final rows = await _client
        .from('transactions')
        .select('external_transaction_key')
        .eq('household_id', householdId)
        .not('external_transaction_key', 'is', null);
    return {
      for (final row in rows)
        if (row['external_transaction_key'] is String)
          row['external_transaction_key'] as String,
    };
  }

  Future<Set<String>> importedFingerprints(String householdId) async {
    final rows = await _client
        .from('statement_imports')
        .select('statement_fingerprint')
        .eq('household_id', householdId)
        .eq('status', 'imported');
    return {
      for (final row in rows)
        if (row['statement_fingerprint'] is String)
          row['statement_fingerprint'] as String,
    };
  }

  Future<List<SavedInstallmentPlan>> installmentPlans(String householdId) async {
    final rows = await _client
        .from('installment_plans')
        .select()
        .eq('household_id', householdId);
    return rows.map((row) {
      return SavedInstallmentPlan(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        normalizedMerchant: row['normalized_merchant_name'] as String,
        monthlyAmount: Money.fromJson(row['monthly_amount']),
        totalInstallments: (row['total_installments'] as num).toInt(),
        expenseScope: row['expense_scope'] as String,
        cardholderId: row['cardholder_id'] as String?,
        assignedUserId: row['assigned_user_id'] as String?,
        originalPurchaseDate: row['original_purchase_date'] != null
            ? DateTime.tryParse(row['original_purchase_date'] as String)
            : null,
        originalPurchaseAmount: row['original_purchase_amount'] != null
            ? Money.fromJson(row['original_purchase_amount'])
            : null,
        categoryId: row['category_id'] as String?,
        status: row['status'] as String? ?? 'active',
      );
    }).toList(growable: false);
  }

  Future<Map<String, String>> merchantPrefs(String householdId) async {
    final rows = await _client
        .from('merchant_category_prefs')
        .select('normalized_merchant, category_id')
        .eq('household_id', householdId);
    return {
      for (final row in rows)
        row['normalized_merchant'] as String: row['category_id'] as String,
    };
  }

  Future<Map<String, String>> cardholderMappings(String householdId) async {
    final rows = await _client
        .from('statement_cardholders')
        .select('external_card_identifier_hash, mapped_user_id')
        .eq('household_id', householdId);
    return {
      for (final row in rows)
        if (row['mapped_user_id'] is String)
          row['external_card_identifier_hash'] as String: row['mapped_user_id'] as String,
    };
  }

  Future<ImportSummary> importReviewed({
    required String householdId,
    required StatementExtraction extraction,
    required List<ReviewLine> lines,
    required List<DetectedCardholder> cardholders,
  }) async {
    final payload = {
      'household_id': householdId,
      'bank_name': extraction.bankName,
      'statement_date': extraction.statementDate?.toIso8601String().split('T').first,
      'payment_due_date': extraction.paymentDueDate?.toIso8601String().split('T').first,
      'statement_fingerprint': extraction.fingerprint,
      'statement_reference': extraction.statementReference,
      'file_name': extraction.fileName,
      'currency': extraction.currency,
      'cardholders': [
        for (final c in cardholders)
          {
            'external_card_identifier_hash': c.identifierHash,
            'masked_identifier': c.maskedIdentifier,
            'display_name': c.displayName,
            'card_type': c.kind.dbValue,
            'mapped_user_id': c.mappedUserId,
          },
      ],
      'lines': [for (final line in lines) line.toImportJson()],
    };
    final result = await _client.rpc<Map<String, dynamic>>(
      'import_statement_expenses',
      params: {'p_payload': payload},
    );
    return ImportSummary.fromJson(result);
  }

  Future<TransactionModel> updateClassification({
    required String transactionId,
    required String scope,
    String? assignedUserId,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_expense_classification',
      params: {
        'p_transaction_id': transactionId,
        'p_expense_scope': scope,
        'p_assigned_user_id': assignedUserId,
      },
    );
    return TransactionModel.fromJson(row);
  }
}
