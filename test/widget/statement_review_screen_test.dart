import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/features/statement_import/application/statement_providers.dart';
import 'package:joint_expenses/features/statement_import/domain/banks/bpi_parser.dart';
import 'package:joint_expenses/features/statement_import/domain/statement_models.dart';
import 'package:joint_expenses/features/statement_import/presentation/statement_review_screen.dart';

import '../helpers/pdf_lines.dart';
import '../helpers/pump_app.dart';

void main() {
  StatementExtraction extraction() {
    return BpiParser().parse(
      lines: bpiSampleLayout(),
      fileFingerprint: 'test-fingerprint',
      fileName: 'sample.pdf',
    );
  }

  testWidgets('review keeps extracted purchases after analyze then navigate', (tester) async {
    await pumpApp(
      tester,
      _AnalyzeThenReview(extraction: extraction()),
      household: null,
    );

    await tester.pumpAndSettle();

    expect(find.text('No statement is loaded.'), findsNothing);
    expect(find.text('Review credit card statement'), findsOneWidget);
    expect(find.text('Cardholders 2'), findsOneWidget);
    expect(find.text('Purchases 4'), findsOneWidget);
    expect(find.text('Installments 13'), findsOneWidget);
    expect(find.text('Needs review 17'), findsOneWidget);
  });
}

class _AnalyzeThenReview extends ConsumerStatefulWidget {
  const _AnalyzeThenReview({required this.extraction});

  final StatementExtraction extraction;

  @override
  ConsumerState<_AnalyzeThenReview> createState() => _AnalyzeThenReviewState();
}

class _AnalyzeThenReviewState extends ConsumerState<_AnalyzeThenReview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(statementSessionProvider.notifier).loadExtraction(widget.extraction);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const StatementReviewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
