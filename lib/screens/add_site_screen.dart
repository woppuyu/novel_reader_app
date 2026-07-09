import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader_app/models/site_config.dart';
import 'package:novel_reader_app/models/site_type.dart';
import 'package:novel_reader_app/state/novel_hub_state.dart';

/// A bottom-sheet form for adding a new site to NovelHub.
///
/// Collects: name, base URL, search URL template, and site type.
/// On submit it calls [NovelHubState.addSite] and closes the sheet.
class AddSiteScreen extends StatefulWidget {
  final String? initialName;
  final String? initialUrl;

  const AddSiteScreen({
    super.key,
    this.initialName,
    this.initialUrl,
  });

  @override
  State<AddSiteScreen> createState() => _AddSiteScreenState();
}

class _AddSiteScreenState extends State<AddSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _searchTemplateController = TextEditingController();
  SiteType _selectedType = SiteType.reader;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _baseUrlController.text = widget.initialUrl ?? '';
  }

  String _normalizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final lowercase = trimmed.toLowerCase();
    if (!lowercase.startsWith('http://') && !lowercase.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _searchTemplateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Build a unique id from the current timestamp.
    final id = 'site_${DateTime.now().millisecondsSinceEpoch}';

    final normalizedBaseUrl = _normalizeUrl(_baseUrlController.text);
    final searchTemplateRaw = _searchTemplateController.text.trim();
    final normalizedSearchTemplate = searchTemplateRaw.isEmpty
        ? null
        : _normalizeUrl(searchTemplateRaw);

    final newSite = SiteConfig(
      id: id,
      name: _nameController.text.trim(),
      baseUrl: normalizedBaseUrl,
      searchUrlTemplate: normalizedSearchTemplate,
      type: _selectedType,
      persistCookies: true,
    );

    // Add the site via state (which also persists it).
    context.read<NovelHubState>().addSite(newSite);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Push the form above the keyboard when it opens.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.add_circle_outline),
                  const SizedBox(width: 8),
                  Text(
                    'Add New Site',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // ── Site Name ─────────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Site Name *',
                  hintText: 'e.g. Royal Road',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // ── Base URL ──────────────────────────────────────────────────
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL *',
                  hintText: 'https://www.example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Base URL is required';
                  final normalized = _normalizeUrl(v);
                  final uri = Uri.tryParse(normalized);
                  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                    return 'Enter a valid URL (e.g. example.com)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── Search URL Template ───────────────────────────────────────
              TextFormField(
                controller: _searchTemplateController,
                decoration: const InputDecoration(
                  labelText: 'Search URL Template (optional)',
                  hintText: 'https://example.com/search?q={query}',
                  helperText:
                      'Use {query} as the placeholder for the search term.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Site Type dropdown ────────────────────────────────────────
              DropdownButtonFormField<SiteType>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Site Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SiteType.reader,
                    child: Text(
                      'Reader (web novel reading site)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: SiteType.search,
                    child: Text(
                      'Search (novel discovery / tracking)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: SiteType.reference,
                    child: Text(
                      'Reference (wiki / lookup)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
              const SizedBox(height: 20),

              // ── Submit button ─────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Add Site'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
