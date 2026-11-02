import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joint_expenses/features/statement_import/application/statement_providers.dart';
import 'package:joint_expenses/features/statement_import/presentation/statement_upload_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('asks for file access before opening the picker', (tester) async {
    var picks = 0;
    await pumpApp(
      tester,
      const StatementUploadScreen(),
      overrides: [
        statementFilePickerProvider.overrideWithValue(() async {
          picks++;
          return null;
        }),
      ],
    );

    await tester.tap(find.text('Select a BPI PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Allow access to a statement file?'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text("Don't allow"), findsOneWidget);
    expect(picks, 0);

    await tester.tap(find.text("Don't allow"));
    await tester.pumpAndSettle();

    expect(find.text('Allow access to a statement file?'), findsNothing);
    expect(find.text('Select a BPI PDF'), findsOneWidget);
    expect(picks, 0);
  });

  testWidgets('opens the file picker only after Allow', (tester) async {
    var picks = 0;
    await pumpApp(
      tester,
      const StatementUploadScreen(),
      overrides: [
        statementFilePickerProvider.overrideWithValue(() async {
          picks++;
          return const FilePickerResult([]);
        }),
      ],
    );

    await tester.tap(find.text('Select a BPI PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(find.text('Select a BPI PDF'), findsOneWidget);
  });
}
