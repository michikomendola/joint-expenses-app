import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/system_insets.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/statement_providers.dart';
import '../domain/pdf_layout_extractor.dart';
import '../domain/banks/parser_registry.dart';

class StatementUploadScreen extends ConsumerStatefulWidget {
  const StatementUploadScreen({super.key});

  @override
  ConsumerState<StatementUploadScreen> createState() => _StatementUploadScreenState();
}

class _StatementUploadScreenState extends ConsumerState<StatementUploadScreen> {
  PlatformFile? _file;
  bool _working = false;
  int _step = 0;

  Future<void> _pick() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => const _FileAccessDialog(),
    );
    if (allowed != true || !mounted) return;
    final result = await ref.read(statementFilePickerProvider)();
    if (!mounted || result == null || result.files.isEmpty) return;
    setState(() => _file = result.files.single);
  }

  Future<void> _process() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _working = true;
      _step = 0;
    });
    try {
      for (var i = 0; i < 4; i++) {
        if (!mounted) return;
        setState(() => _step = i);
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
      await ref.read(statementSessionProvider.notifier).analyzeFile(file);
      if (!mounted) return;
      context.push(AppRoutes.statementReview);
    } on PdfExtractionException catch (error) {
      if (mounted) AppSnackBar.error(context, error.message);
    } on UnsupportedStatementException catch (error) {
      if (mounted) AppSnackBar.error(context, error.message);
    } catch (error) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not read this statement. $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the analyzed session alive while this screen is in the stack.
    ref.watch(statementSessionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = _file;

    return Scaffold(
      appBar: AppBar(title: const Text('Import statement')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomPadding(context, base: 32)),
        children: [
          Text(
            'Upload your credit card statement to automatically identify purchases, installments, and shared expenses.',
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          AppCard(
            onTap: _working ? null : _pick,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 44, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  file == null ? 'Select a BPI PDF' : file.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  file == null
                      ? 'Selectable-text statements only. Scanned copies need OCR later.'
                      : _sizeLabel(file.size),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (file != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _working
                        ? null
                        : () => setState(() => _file = null),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Remove file'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceLg),
          if (_working) ...[
            Text('Analyzing your statement', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _Step(done: _step >= 0, label: 'Reading transaction details'),
            _Step(done: _step >= 1, label: 'Identifying cardholders'),
            _Step(done: _step >= 2, label: 'Detecting installments'),
            _Step(done: _step >= 3, label: 'Checking previously imported transactions'),
            const SizedBox(height: AppConstants.spaceLg),
          ],
          PrimaryButton(
            label: 'Analyze statement',
            icon: Icons.document_scanner_outlined,
            loading: _working,
            onPressed: file == null ? null : _process,
          ),
          const SizedBox(height: 12),
          Text(
            'You will be asked before a file is opened. Only the PDF you choose is read, on this device. Nothing is saved until you review and confirm. Full card numbers are hashed and never shown.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Prominent disclosure required before the app reads a bank statement.
/// The system file picker, which grants access to that one PDF, opens only
/// after the user taps Allow.
class _FileAccessDialog extends StatelessWidget {
  const _FileAccessDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.folder_open_rounded, color: theme.colorScheme.primary),
      title: const Text('Allow access to a statement file?'),
      content: const SingleChildScrollView(
        child: Text(
          'Joint Expenses will open your device\'s file picker so you can choose one PDF statement.\n\n'
          'The app reads only that file, and only to find purchases, installments, and cardholders. '
          'It does not browse the rest of your files. The PDF stays on this device. '
          'Transactions are saved to your household only after you review and confirm them.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Don't allow"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.label});
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: done ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
