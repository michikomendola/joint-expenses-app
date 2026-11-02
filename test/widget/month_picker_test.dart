import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/core/utils/date_utils.dart';
import 'package:joint_expenses/core/widgets/month_picker.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('All time sits in the calendar and clears the month', (tester) async {
    YearMonth? picked = const YearMonth(2026, 10);
    var changed = false;

    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: MonthChip(
            value: const YearMonth(2026, 10),
            allowAll: true,
            compact: true,
            onChanged: (value) {
              changed = true;
              picked = value;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Oct 2026'));
    await tester.pumpAndSettle();

    expect(find.text('All time'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('a month-only calendar does not offer All time', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: MonthChip(
            value: const YearMonth(2026, 10),
            compact: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Oct 2026'));
    await tester.pumpAndSettle();

    expect(find.text('All time'), findsNothing);
    expect(find.text('This month'), findsOneWidget);
  });
}
