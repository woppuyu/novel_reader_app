import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader_app/state/novel_hub_state.dart';

/// A full-screen dialog Settings page overlay.
///
/// Holds application preferences and clipboard-based import/export features.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NovelHubState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          _sectionHeader(theme, 'Backup & Sync'),
          ListTile(
            leading: Icon(Icons.copy, color: theme.colorScheme.primary),
            title: const Text('Export Save Code'),
            subtitle: const Text('Compress and copy all tabs and history to clipboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final code = await state.exportSaveCode();
                if (context.mounted) {
                  _showExportDialog(context, code);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.paste, color: theme.colorScheme.primary),
            title: const Text('Import Save Code'),
            subtitle: const Text('Restore sites and reading history from save code'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showImportDialog(context, state);
            },
          ),
          const Divider(),
          _sectionHeader(theme, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('NovelHub'),
            subtitle: Text('Version 1.0.0\nDistraction-free multi-site reader container.'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context, String code) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('Save Code Copied'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your backup save code has been copied to your clipboard. Paste it in a secure place or another device to restore.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: SelectableText(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog(BuildContext context, NovelHubState state) {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Import Save Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your backup save code below to restore your sites and progress:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Paste save code here...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  filled: true,
                ),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final code = controller.text.trim();
                if (code.isEmpty) return;
                Navigator.pop(dialogContext); // Close dialog first

                try {
                  final count = await state.importSaveCode(code);
                  if (count > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully imported $count sites and progress!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No sites found in save code.'),
                        backgroundColor: Colors.amber,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Import failed: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }
}
