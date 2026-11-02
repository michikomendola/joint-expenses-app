import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/category.dart';
import '../../../data/models/expense_scope.dart';
import '../../../data/models/household.dart';
import '../../../data/models/transaction_type.dart';
import '../../categories/application/category_providers.dart';
import '../../households/application/household_providers.dart';
import '../application/statement_providers.dart';
import '../domain/review_line.dart';
import '../domain/statement_models.dart';

class StatementReviewScreen extends ConsumerWidget {
  const StatementReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(statementSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review statement')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No statement is loaded.'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(AppRoutes.statementImport),
                  child: const Text('Import a statement'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _ReviewBody(session: session);
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.session});
  final StatementSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(householdMembersProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final visible = session.visible;
    final extraction = session.extraction;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review credit card statement'),
        actions: [
          if (session.bulkMode)
            TextButton(
              onPressed: () => ref.read(statementSessionProvider.notifier).bulkExclude(),
              child: const Text('Exclude'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Header(session: session),
                if (extraction.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    extraction.warnings.first,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppConstants.spaceMd),
                _CardholderMaps(session: session),
                const SizedBox(height: AppConstants.spaceMd),
                _Filters(session: session),
                const SizedBox(height: AppConstants.spaceSm),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nothing in this filter.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                else
                  for (final line in visible)
                    _LineCard(
                      line: line,
                      session: session,
                      members: members,
                      categories: categories,
                    ),
              ],
            ),
          ),
          _BottomBar(session: session),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final StatementSession session;

  @override
  Widget build(BuildContext context) {
    final e = session.extraction;
    final date = e.statementDate == null ? 'Unknown date' : AppDateUtils.mediumDate(e.statementDate!);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank: ${e.bankName}  ·  Statement: $date'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'Cardholders ${e.cardholders.length}'),
              _Chip(label: 'Purchases ${session.purchaseCount}'),
              _Chip(label: 'Installments ${session.installmentCount}'),
              _Chip(label: 'Needs review ${session.needsReviewCount}'),
              _Chip(label: 'Already imported ${session.alreadyImportedCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _CardholderMaps extends ConsumerWidget {
  const _CardholderMaps({required this.session});
  final StatementSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(householdMembersProvider).value ?? const [];
    if (session.cardholders.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cardholders', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'This is whose card was swiped — not who should pay. Classify each expense separately.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final card in session.cardholders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${card.displayName} · ${card.kind.label}'),
              subtitle: Text(card.maskedIdentifier),
              trailing: DropdownButton<String?>(
                value: card.mappedUserId,
                hint: const Text('Map to member'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Unmapped')),
                  for (final m in members)
                    DropdownMenuItem<String?>(value: m.userId, child: Text(m.displayName)),
                ],
                onChanged: (id) =>
                    ref.read(statementSessionProvider.notifier).mapCardholder(card.identifierHash, id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.session});
  final StatementSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ImportFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_label(filter)),
                selected: session.filter == filter,
                onSelected: (_) => ref.read(statementSessionProvider.notifier).setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }

  String _label(ImportFilter filter) => switch (filter) {
        ImportFilter.all => 'All',
        ImportFilter.needsReview => 'Needs review',
        ImportFilter.personal => 'Personal',
        ImportFilter.joint => 'Joint',
        ImportFilter.installments => 'Installments',
        ImportFilter.excluded => 'Excluded',
      };
}

class _LineCard extends ConsumerWidget {
  const _LineCard({
    required this.line,
    required this.session,
    required this.members,
    required this.categories,
  });

  final ReviewLine line;
  final StatementSession session;
  final List<HouseholdMember> members;
  final List<CategoryModel> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final e = line.extracted;
    final card = session.cardholders.where((c) => c.identifierHash == e.cardholderHash).firstOrNull;
    final amount = e.amount == null
        ? '—'
        : CurrencyFormatter.format(e.amount!, currency: e.currency);
    final date = e.transactionDate == null ? 'No date' : AppDateUtils.mediumDate(e.transactionDate!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (e.description ?? 'Unknown merchant').toUpperCase(),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  amount,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: (e.amount?.isNegative ?? false) ? colors.income : colors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                date,
                if (e.detectedType.isImportCandidate) 'CC',
                if (e.isInstallment && e.installmentNumber != null && e.totalInstallments != null)
                  'Installment ${e.installmentNumber} of ${e.totalInstallments}',
                if (card != null) 'Card: ${card.displayName}',
                e.detectedType.label,
                line.status.label,
              ].join('  ·  '),
              style: theme.textTheme.bodySmall,
            ),
            if (line.previouslyAssigned && line.assignedUserId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Previously assigned to ${_name(line.assignedUserId)}',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            if (e.summary != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (e.summary!.originalPurchaseDate != null)
                      'Original purchase ${AppDateUtils.mediumDate(e.summary!.originalPurchaseDate!)}',
                    if (e.summary!.originalPurchaseAmount != null)
                      'Original ${CurrencyFormatter.format(e.summary!.originalPurchaseAmount!, currency: e.currency)}',
                    if (e.summary!.remainingBalance != null)
                      'Remaining ${CurrencyFormatter.format(e.summary!.remainingBalance!, currency: e.currency)} (not an expense)',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (e.originalCurrency != null && e.originalAmount != null)
              Text(
                'Billed in PHP. Original ${e.originalCurrency} ${e.originalAmount!.toDecimalString()}',
                style: theme.textTheme.bodySmall,
              ),
            if (e.detectedType.isImportCandidate && line.status != ReviewStatus.alreadyImported) ...[
              const SizedBox(height: 10),
              Text('Who is this expense for?', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final member in members)
                    ChoiceChip(
                      label: Text('Personal — ${member.displayName}'),
                      selected: line.expenseScope == ExpenseScope.personal &&
                          line.assignedUserId == member.userId,
                      onSelected: (_) => ref
                          .read(statementSessionProvider.notifier)
                          .classify(e.id, ExpenseScope.personal, assignedUserId: member.userId),
                    ),
                  ChoiceChip(
                    label: const Text('Joint expense'),
                    selected: line.expenseScope == ExpenseScope.joint,
                    onSelected: (_) => ref
                        .read(statementSessionProvider.notifier)
                        .classify(e.id, ExpenseScope.joint),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: line.categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in categories)
                    if (c.type == TransactionType.expense)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) {
                  if (id != null) {
                    ref.read(statementSessionProvider.notifier).setCategory(e.id, id);
                  }
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref.read(statementSessionProvider.notifier).exclude(
                        e.id,
                        excluded: line.status != ReviewStatus.excluded,
                      ),
                  child: Text(line.status == ReviewStatus.excluded ? 'Include again' : 'Skip'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _name(String? id) {
    for (final member in members) {
      if (member.userId == id) return member.displayName;
    }
    return 'a household member';
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.session});
  final StatementSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = session.readyCount;
    final total = session.candidateCount - session.alreadyImportedCount;
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$ready of $total purchases reviewed'),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Import expenses',
                loading: session.importing,
                onPressed: ready == 0
                    ? null
                    : () async {
                        final summary =
                            await ref.read(statementSessionProvider.notifier).importReady();
                        if (!context.mounted || summary == null) {
                          if (context.mounted && session.error != null) {
                            AppSnackBar.error(context, session.error);
                          }
                          return;
                        }
                        await showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Import complete'),
                            content: Text(
                              summary.duplicateStatement
                                  ? 'This statement was already imported. No new expenses were added.'
                                  : 'Imported ${summary.imported}\n'
                                      'Already imported ${summary.alreadyImported}\n'
                                      'Skipped ${summary.skipped}\n'
                                      'Needs attention ${summary.failed}',
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () {
                                  ref.read(statementSessionProvider.notifier).clear();
                                  Navigator.pop(context);
                                  context.go(AppRoutes.transactions);
                                },
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
