import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader_app/state/novel_hub_state.dart';
import 'package:novel_reader_app/models/site_type.dart';
import 'package:novel_reader_app/screens/add_site_screen.dart';
import 'package:webview_refresher/webview_refresher.dart';

/// The main screen of NovelHub.
///
/// Implements a 100% full-screen WebView layout to maximize reading area.
/// All controls (mode toggle, tab switching, search, deletion, and site registration)
/// are moved into a bottom sheet Control Panel accessed via a floating menu button.
class NovelHubScreen extends StatelessWidget {
  const NovelHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NovelHubState>();

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading NovelHub…'),
            ],
          ),
        ),
      );
    }

    final isReadingMode = state.currentMode == NovelHubMode.reading;
    final currentSites = isReadingMode ? state.readingSites : state.querySites;

    // Check if a link was long-pressed inside WebView to show pre-filled Add Site sheet
    if (state.pendingSiteUrl != null) {
      final prefilledName = state.pendingSiteName ?? '';
      final prefilledUrl = state.pendingSiteUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.clearPendingSite();
        _openAddSite(
          context,
          initialName: prefilledName,
          initialUrl: prefilledUrl,
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Try navigating the active WebView back first
        if (state.controllers.isNotEmpty) {
          final activeController = state.controllers[state.globalActiveIndex];
          if (await activeController.webViewController.canGoBack()) {
            await activeController.webViewController.goBack();
            return;
          }
        }

        // If the webview cannot go back, close the app
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ── Full-Screen Body ──────────────────────────────────────────────
            // SafeArea ensures notch/status bar clipping is handled on mobile screens.
            SafeArea(
              top: true,
              bottom: false,
              child: currentSites.isEmpty
                  ? _EmptyState(
                      mode: state.currentMode,
                      onAddSite: () => _openAddSite(context),
                    )
                  : IndexedStack(
                      // Uses state.globalActiveIndex to map current active mode tab
                      // to its master controller list index.
                      index: state.globalActiveIndex,
                      children: state.controllers
                          .map((ctrl) => WebviewRefresher(
                                key: ValueKey(ctrl.siteConfig.id),
                                controller: ctrl.webViewController,
                                onRefresh: ctrl.onRefresh,
                              ))
                          .toList(),
                    ),
            ),

            // ── Floating Action Menu Button (Auto-hiding / Docked overlay) ────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              right: !state.showFab
                  ? -60 // Slide completely off-screen when hidden by scroll
                  : (state.isFabMinimized ? 0 : 16),
              bottom: state.isFabMinimized ? 120 : 16, // Elevate when docked to avoid system overlaps
              child: AnimatedScale(
                scale: state.showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: state.isFabMinimized
                    ? _MinimizedFabHandle(onTap: state.restoreFab)
                    : _FullFab(
                        onTap: () {
                          state.restoreFab(); // Reset idle timer
                          _openControlPanel(context);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the consolidated navigation/search Control Panel.
  void _openControlPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ControlPanelSheet(),
    );
  }

  /// Opens the Add Site form bottom sheet.
  static void _openAddSite(
    BuildContext context, {
    String? initialName,
    String? initialUrl,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddSiteScreen(
        initialName: initialName,
        initialUrl: initialUrl,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget: NovelHub Control Panel (Bottom Sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ControlPanelSheet extends StatelessWidget {
  const _ControlPanelSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NovelHubState>();
    final theme = Theme.of(context);
    final isReadingMode = state.currentMode == NovelHubMode.reading;
    final currentSites = isReadingMode ? state.readingSites : state.querySites;
    final activeIndex =
        isReadingMode ? state.activeReadingIndex : state.activeQueryIndex;

    return Padding(
      // Padding pushes control panel content out of the screen bottom safe area.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sheet Drag Handle ──────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Top Mode Switcher (Segmented Selector) ──────────────────────────
          Center(
            child: SegmentedButton<NovelHubMode>(
              segments: const [
                ButtonSegment<NovelHubMode>(
                  value: NovelHubMode.reading,
                  icon: Icon(Icons.menu_book),
                  label: Text('Reading Mode'),
                ),
                ButtonSegment<NovelHubMode>(
                  value: NovelHubMode.query,
                  icon: Icon(Icons.travel_explore),
                  label: Text('Query Mode'),
                ),
              ],
              selected: {state.currentMode},
              onSelectionChanged: (newSelection) {
                state.setMode(newSelection.first);
              },
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 16),

          // ── Mode Title ─────────────────────────────────────────────────────
          Text(
            isReadingMode ? 'Reading Tabs' : 'Query Tabs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // ── List of Active Mode's Sites ────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: currentSites.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Text(
                      isReadingMode
                          ? 'No reading sites added yet.'
                          : 'No query sites added yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    itemCount: currentSites.length,
                    onReorderItem: state.reorderSites,
                    itemBuilder: (context, index) {
                      final site = currentSites[index];
                      final isSelected = index == activeIndex;
                      return ListTile(
                        key: ValueKey(site.id),
                        dense: true,
                        leading: Icon(
                          isReadingMode ? Icons.book : Icons.language,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                        title: Text(
                          site.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          site.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        selected: isSelected,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                _showDeleteConfirmDialog(context, state, site);
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(Icons.drag_handle, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          state.setActiveTab(index);
                          Navigator.pop(context); // Close panel
                        },
                        onLongPress: () {
                          _showSwitchModeDialog(context, state, site);
                        },
                      );
                    },
                  ),
          ),

          // ── Add Site Action Row ────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close control sheet first
              NovelHubScreen._openAddSite(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New Site'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Prompts the user to confirm deletion of a site.
  void _showDeleteConfirmDialog(
    BuildContext context,
    NovelHubState state,
    dynamic site,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete "${site.name}"?'),
          content: const Text(
            'Are you sure you want to delete this website? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                state.removeSite(site.id);
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts the user to confirm moving a site configuration to the other mode.
  void _showSwitchModeDialog(
    BuildContext context,
    NovelHubState state,
    dynamic site,
  ) {
    final isReading = site.type == SiteType.reader;
    final sourceMode = isReading ? 'Reading Mode' : 'Query Mode';
    final targetMode = isReading ? 'Query Mode' : 'Reading Mode';

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Move "${site.name}"?'),
          content: Text(
            'Do you want to switch this website from $sourceMode to $targetMode?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: Text('Move to $targetMode'),
              onPressed: () {
                state.toggleSiteMode(site.id);
                Navigator.of(context).pop(); // Close dialog
              },
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget: Empty state screen
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final NovelHubMode mode;
  final VoidCallback onAddSite;

  const _EmptyState({
    required this.mode,
    required this.onAddSite,
  });

  @override
  Widget build(BuildContext context) {
    final isReading = mode == NovelHubMode.reading;
    final title = isReading ? 'No reading sites' : 'No query sites';
    final description = isReading
        ? 'Add your web novel reading sites (like Royal Road, custom blogs) here.'
        : 'Add novel search directories, forums, or reference pages here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReading ? Icons.menu_book_outlined : Icons.search_off_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddSite,
              icon: const Icon(Icons.add),
              label: const Text('Add Site'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget: Docked / Minimized FAB handle on right screen edge
// ─────────────────────────────────────────────────────────────────────────────

class _MinimizedFabHandle extends StatelessWidget {
  final VoidCallback onTap;

  const _MinimizedFabHandle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(-1, 1),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.chevron_left,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widget: Full circular explore FAB
// ─────────────────────────────────────────────────────────────────────────────

class _FullFab extends StatelessWidget {
  final VoidCallback onTap;

  const _FullFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.85,
      child: FloatingActionButton(
        onPressed: onTap,
        tooltip: 'Control Panel',
        child: const Icon(Icons.explore),
      ),
    );
  }
}
