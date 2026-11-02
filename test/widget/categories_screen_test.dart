import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/features/categories/presentation/categories_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/fixtures.dart';

void main() {
  Future<void> showPersonal(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Switch account view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
  }

  testWidgets('categories follow the joint or personal view', (tester) async {
    await pumpApp(
      tester,
      const CategoriesScreen(),
      transactions: Fixtures.specExample(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Joint account'), findsOneWidget);
    expect(find.text('₱0.00'), findsWidgets);
    expect(find.text('₱15,000.00'), findsNothing);

    await showPersonal(tester);

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('₱15,000.00'), findsOneWidget);
    expect(find.text('₱10,000.00'), findsOneWidget);
    expect(find.text('₱5,000.00'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('₱45,000.00'), findsWidgets);
    expect(find.text('₱30,000.00'), findsNothing);
  });
}
