import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/account_view_provider.dart';
import '../../domain/home_account_view.dart';

/// Title control that switches the shared joint / personal view.
class AccountViewButton extends ConsumerWidget {
  const AccountViewButton({
    super.key,
    this.style,
  });

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(homeAccountViewProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = Text(
      view.label,
      style: style ?? theme.textTheme.headlineSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return PopupMenuButton<HomeAccountView>(
      tooltip: 'Switch account view',
      initialValue: view,
      onSelected: (value) => ref.read(homeAccountViewProvider.notifier).select(value),
      itemBuilder: (context) => [
        for (final choice in HomeAccountView.values)
          PopupMenuItem(
            value: choice,
            child: Text(choice.label),
          ),
      ],
      child: Row(
        children: [
          Flexible(child: label),
          Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurface),
        ],
      ),
    );
  }
}
