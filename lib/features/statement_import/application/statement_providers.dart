import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/models/expense_scope.dart';
import '../../../data/models/household.dart';
import '../../../data/repositories/statement_repository.dart';
import '../../categories/application/category_providers.dart';
import '../../households/application/household_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../domain/banks/parser_registry.dart';
import '../domain/installment_matcher.dart';
import '../domain/merchant_categorizer.dart';
import '../domain/pdf_layout_extractor.dart';
import '../domain/review_line.dart';
import '../domain/statement_models.dart';

enum ImportFilter { all, needsReview, personal, joint, installments, excluded }

/// Opens the system document picker. Overridden in tests so the consent
/// dialog can be checked without a platform channel.
typedef StatementFilePicker = Future<FilePickerResult?> Function();

final statementFilePickerProvider = Provider<StatementFilePicker>((ref) {
  return () {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
  };
});

class StatementSession {
  const StatementSession({
    required this.extraction,
    required this.cardholders,
    required this.lines,
    this.filter = ImportFilter.all,
    this.cardholderFilter,
    this.selectedIds = const {},
    this.bulkMode = false,
    this.importing = false,
    this.summary,
    this.error,
  });

  final StatementExtraction extraction;
  final List<DetectedCardholder> cardholders;
  final List<ReviewLine> lines;
  final ImportFilter filter;
  final String? cardholderFilter;
  final Set<String> selectedIds;
  final bool bulkMode;
  final bool importing;
  final ImportSummary? summary;
  final String? error;

  List<ReviewLine> get visible {
    Iterable<ReviewLine> out = lines;
    switch (filter) {
      case ImportFilter.all:
        out = out.where((l) => l.extracted.detectedType.isImportCandidate);
      case ImportFilter.needsReview:
        out = out.where((l) => l.needsClassification || l.status == ReviewStatus.possibleDuplicate);
      case ImportFilter.personal:
        out = out.where((l) => l.expenseScope == ExpenseScope.personal);
      case ImportFilter.joint:
        out = out.where((l) => l.expenseScope == ExpenseScope.joint);
      case ImportFilter.installments:
        out = out.where((l) => l.extracted.isInstallment);
      case ImportFilter.excluded:
        out = out.where(
          (l) =>
              l.status == ReviewStatus.excluded ||
              !l.extracted.detectedType.isImportCandidate,
        );
    }
    if (cardholderFilter != null) {
      out = out.where((l) => l.extracted.cardholderHash == cardholderFilter);
    }
    return out.toList(growable: false);
  }

  int get purchaseCount =>
      lines.where((l) => l.extracted.detectedType == DetectedLineType.purchase).length;
  int get installmentCount => lines.where((l) => l.extracted.isInstallment).length;
  int get needsReviewCount => lines.where((l) => l.needsClassification).length;
  int get alreadyImportedCount =>
      lines.where((l) => l.status == ReviewStatus.alreadyImported).length;
  int get readyCount => lines.where((l) => l.canImport).length;
  int get candidateCount =>
      lines.where((l) => l.extracted.detectedType.isImportCandidate).length;

  StatementSession copyWith({
    List<DetectedCardholder>? cardholders,
    List<ReviewLine>? lines,
    ImportFilter? filter,
    String? cardholderFilter,
    bool clearCardholderFilter = false,
    Set<String>? selectedIds,
    bool? bulkMode,
    bool? importing,
    ImportSummary? summary,
    String? error,
    bool clearError = false,
    bool clearSummary = false,
  }) =>
      StatementSession(
        extraction: extraction,
        cardholders: cardholders ?? this.cardholders,
        lines: lines ?? this.lines,
        filter: filter ?? this.filter,
        cardholderFilter:
            clearCardholderFilter ? null : (cardholderFilter ?? this.cardholderFilter),
        selectedIds: selectedIds ?? this.selectedIds,
        bulkMode: bulkMode ?? this.bulkMode,
        importing: importing ?? this.importing,
        summary: clearSummary ? null : (summary ?? this.summary),
        error: clearError ? null : (error ?? this.error),
      );
}

final statementSessionProvider =
    NotifierProvider<StatementSessionNotifier, StatementSession?>(
  StatementSessionNotifier.new,
);

class StatementSessionNotifier extends Notifier<StatementSession?> {
  StatementSession? _session;

  @override
  StatementSession? build() => _session;

  Future<void> analyzeFile(PlatformFile file) async {
    final bytes = await _fileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw const PdfExtractionException('empty', 'Could not read the selected file.');
    }
    await analyzeBytes(bytes, fileName: file.name);
  }

  Future<void> analyzeBytes(Uint8List bytes, {String? fileName}) async {
    final fingerprint = sha256.convert(bytes).toString();
    final layout = PdfLayoutExtractor.extract(bytes);
    final parser = BankParserRegistry.detect(layout);
    final extraction = parser.parse(
      lines: layout,
      fileFingerprint: fingerprint,
      fileName: fileName,
    );
    await loadExtraction(extraction);
  }

  Future<void> loadExtraction(StatementExtraction extraction) async {
    _session = await _hydrate(extraction);
    state = _session;
  }

  Future<StatementSession> _hydrate(StatementExtraction extraction) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    final categories = ref.read(categoriesProvider).value ?? const <CategoryModel>[];
    final members = ref.read(householdMembersProvider).value ?? const <HouseholdMember>[];

    var keys = <String>{};
    var fingerprints = <String>{};
    var plans = <SavedInstallmentPlan>[];
    var prefs = <String, String>{};
    var mappings = <String, String>{};
    if (householdId != null) {
      try {
        final repo = ref.read(statementRepositoryProvider);
        keys = await repo.importedKeys(householdId);
        fingerprints = await repo.importedFingerprints(householdId);
        plans = await repo.installmentPlans(householdId);
        prefs = await repo.merchantPrefs(householdId);
        mappings = await repo.cardholderMappings(householdId);
      } catch (_) {
        // Still show extracted purchases if duplicate lookup is unavailable.
      }
    }

    final alreadyStatement = fingerprints.contains(extraction.fingerprint);

    final cardholders = [
      for (final c in extraction.cardholders)
        c.copyWith(
          mappedUserId: mappings[c.identifierHash] ?? _guessMember(c.displayName, members),
        ),
    ];

    final lines = extraction.lines.map((line) {
      final key = ExternalKeys.forLine(fingerprint: extraction.fingerprint, line: line);
      final category = MerchantCategorizer.suggest(
        merchant: line.description,
        categories: categories,
        remembered: prefs,
      );
      var status = line.detectedType.isImportCandidate
          ? ReviewStatus.needsReview
          : ReviewStatus.excluded;
      if (!line.detectedType.isImportCandidate) {
        status = ReviewStatus.excluded;
      } else if (alreadyStatement || keys.contains(key)) {
        status = ReviewStatus.alreadyImported;
      } else if (line.transactionDate == null || line.amount == null) {
        status = ReviewStatus.needsAttention;
      }

      SavedInstallmentPlan? plan;
      var previously = false;
      ExpenseScope? scope;
      String? assigned;
      if (line.isInstallment && status != ReviewStatus.alreadyImported) {
        final cardId = cardholders
            .where((c) => c.identifierHash == line.cardholderHash)
            .map((c) => c.identifierHash)
            .firstOrNull;
        final match = InstallmentMatcher.match(
          charge: line,
          plans: plans,
          cardholderId: cardId,
        );
        if (match.kind == PlanMatchKind.ambiguous) {
          status = ReviewStatus.possibleDuplicate;
        } else if (match.isConfident) {
          plan = match.plan;
          previously = true;
          scope = ExpenseScope.fromString(plan!.expenseScope);
          assigned = plan.assignedUserId;
          status = ReviewStatus.classified;
        }
      }

      return ReviewLine(
        extracted: line,
        status: status,
        expenseScope: scope,
        assignedUserId: assigned,
        categoryId: plan?.categoryId ?? category?.id,
        matchedPlan: plan,
        previouslyAssigned: previously,
        selected: status != ReviewStatus.excluded && status != ReviewStatus.alreadyImported,
        externalKey: key,
      );
    }).toList(growable: false);

    return StatementSession(
      extraction: extraction,
      cardholders: cardholders,
      lines: lines,
    );
  }

  String? _guessMember(String cardName, List<HouseholdMember> members) {
    final tokens = cardName.toUpperCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    HouseholdMember? best;
    var bestScore = 0;
    for (final member in members) {
      final name = member.displayName.toUpperCase().split(RegExp(r'\s+')).toSet();
      final score = tokens.intersection(name).length;
      if (score > bestScore) {
        bestScore = score;
        best = member;
      }
    }
    return bestScore >= 2 ? best?.userId : null;
  }

  void mapCardholder(String hash, String? userId) {
    final session = state;
    if (session == null) return;
    _set(session.copyWith(
      cardholders: [
        for (final c in session.cardholders)
          if (c.identifierHash == hash)
            c.copyWith(mappedUserId: userId, clearMappedUser: userId == null)
          else
            c,
      ],
    ));
  }

  void setFilter(ImportFilter filter) {
    final session = state;
    if (session == null) return;
    _set(session.copyWith(filter: filter));
  }

  void setCardholderFilter(String? hash) {
    final session = state;
    if (session == null) return;
    _set(session.copyWith(
      cardholderFilter: hash,
      clearCardholderFilter: hash == null,
    ));
  }

  void classify(String id, ExpenseScope scope, {String? assignedUserId}) {
    _updateLine(
      id,
      (line) => line.copyWith(
        expenseScope: scope,
        assignedUserId: scope == ExpenseScope.joint ? null : assignedUserId,
        clearAssigned: scope == ExpenseScope.joint,
        status: ReviewStatus.classified,
        selected: true,
      ),
    );
  }

  void setCategory(String id, String categoryId) {
    _updateLine(id, (line) => line.copyWith(categoryId: categoryId));
  }

  void exclude(String id, {bool excluded = true}) {
    _updateLine(
      id,
      (line) => line.copyWith(
        status: excluded ? ReviewStatus.excluded : ReviewStatus.needsReview,
        selected: !excluded,
        clearScope: excluded,
        clearAssigned: excluded,
      ),
    );
  }

  void toggleSelect(String id) {
    _updateLine(id, (line) => line.copyWith(selected: !line.selected));
  }

  void toggleBulk(String id) {
    final session = state;
    if (session == null) return;
    final next = {...session.selectedIds};
    if (!next.add(id)) next.remove(id);
    _set(session.copyWith(selectedIds: next, bulkMode: true));
  }

  void bulkClassify(ExpenseScope scope, {String? assignedUserId}) {
    final session = state;
    if (session == null) return;
    final ids = session.selectedIds;
    _set(session.copyWith(
      lines: [
        for (final line in session.lines)
          if (ids.contains(line.extracted.id))
            line.copyWith(
              expenseScope: scope,
              assignedUserId: scope == ExpenseScope.joint ? null : assignedUserId,
              clearAssigned: scope == ExpenseScope.joint,
              status: ReviewStatus.classified,
              selected: true,
            )
          else
            line,
      ],
      selectedIds: {},
      bulkMode: false,
    ));
  }

  void bulkExclude() {
    final session = state;
    if (session == null) return;
    final ids = session.selectedIds;
    _set(session.copyWith(
      lines: [
        for (final line in session.lines)
          if (ids.contains(line.extracted.id))
            line.copyWith(status: ReviewStatus.excluded, selected: false)
          else
            line,
      ],
      selectedIds: {},
      bulkMode: false,
    ));
  }

  void bulkCategory(String categoryId) {
    final session = state;
    if (session == null) return;
    final ids = session.selectedIds;
    _set(session.copyWith(
      lines: [
        for (final line in session.lines)
          if (ids.contains(line.extracted.id)) line.copyWith(categoryId: categoryId) else line,
      ],
    ));
  }

  void _updateLine(String id, ReviewLine Function(ReviewLine) update) {
    final session = state;
    if (session == null) return;
    _set(session.copyWith(
      lines: [
        for (final line in session.lines)
          if (line.extracted.id == id) update(line) else line,
      ],
    ));
  }

  Future<ImportSummary?> importReady() async {
    final session = state;
    final householdId = ref.read(currentHouseholdIdProvider);
    if (session == null || householdId == null) return null;
    _set(session.copyWith(importing: true, clearError: true));
    try {
      final summary = await ref.read(statementRepositoryProvider).importReviewed(
            householdId: householdId,
            extraction: session.extraction,
            lines: session.lines,
            cardholders: session.cardholders,
          );
      ref.invalidate(monthTransactionsProvider);
      _set(session.copyWith(importing: false, summary: summary));
      return summary;
    } catch (error) {
      _set(session.copyWith(importing: false, error: error.toString()));
      return null;
    }
  }

  void clear() {
    _session = null;
    state = null;
  }

  void _set(StatementSession session) {
    _session = session;
    state = session;
  }
}

Future<Uint8List?> _fileBytes(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
  if (file.path == null || file.path!.isEmpty) return null;
  try {
    return await File(file.path!).readAsBytes();
  } catch (_) {
    return null;
  }
}
