import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/animated_entrance.dart';

/// Shared layout for authentication screens: brand mark, title, subtitle and
/// a scrollable form that stays usable with the keyboard open.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: showBack
          ? AppBar(backgroundColor: Colors.transparent)
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceLg,
                vertical: AppConstants.spaceMd,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppConstants.spaceMd * 2,
                  maxWidth: 480,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AnimatedEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!showBack) ...[
                            const SizedBox(height: AppConstants.spaceLg),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: scheme.onPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceLg),
                          ],
                          Text(title, style: theme.textTheme.headlineMedium),
                          const SizedBox(height: AppConstants.spaceSm),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceXl),
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: AppConstants.spaceLg),
                            Center(child: footer),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
