import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/realtime_sync.dart';
import '../../features/transactions/presentation/transaction_form_sheet.dart';
import '../constants/app_constants.dart';

/// Bottom navigation scaffold hosting the four tabs. Each tab keeps its own
/// navigator and scroll state; switching tabs cross-fades between them.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshHouseholdData(ref);
    }
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab pops to its root (standard M3 behaviour).
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the realtime channel alive for as long as the shell is mounted.
    ref.watch(realtimeSyncProvider);

    final index = widget.navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: _AnimatedBranchContainer(
        currentIndex: index,
        children: widget.children,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-transaction-fab',
        onPressed: () => TransactionFormSheet.show(context),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Stack of branch navigators that fades between tabs while preserving the
/// state of inactive branches.
class _AnimatedBranchContainer extends StatelessWidget {
  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _BranchItem(
            active: i == currentIndex,
            child: children[i],
          ),
      ],
    );
  }
}

class _BranchItem extends StatelessWidget {
  const _BranchItem({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // AnimatedOpacity sits *outside* TickerMode so the fade-out still runs
    // after the branch's own tickers are muted.
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: AppConstants.animMedium,
          curve: Curves.easeOut,
          child: TickerMode(enabled: active, child: child),
        ),
      ),
    );
  }
}
