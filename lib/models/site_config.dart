import 'package:novel_reader_app/models/site_type.dart';

/// Represents the configuration for a single embedded website (tab).
///
/// This is the core data model of NovelHub. All site metadata lives here,
/// and instances are serialised to/from JSON for persistence via [SiteRepository].
class SiteConfig {
  /// A unique identifier for this site (used to find/remove it in the list).
  final String id;

  /// The human-readable display name shown in the bottom nav bar.
  final String name;

  /// The base URL loaded when the tab is first opened or reset.
  final String baseUrl;

  /// Optional URL template used for searching this site.
  ///
  /// Must contain the literal placeholder `{query}` which will be replaced
  /// by the URL-encoded search term at runtime.
  ///
  /// Example: `https://www.novelupdates.com/?s={query}`
  ///
  /// If null, searching on this tab will do nothing.
  final String? searchUrlTemplate;

  /// What kind of site this is (reader, search index, or reference).
  final SiteType type;

  /// Optional URL pointing to the site's favicon or a custom icon.
  /// Currently unused in the UI (a placeholder globe icon is shown instead).
  final String? iconUrl;

  /// Whether to persist cookies for this site across app restarts.
  ///
  /// Defaults to true. When false, you could choose to clear cookies on exit
  /// (not yet implemented — the flag is here for future use).
  final bool persistCookies;

  const SiteConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.searchUrlTemplate,
    required this.type,
    this.iconUrl,
    this.persistCookies = true,
  });

  /// Deserialises a [SiteConfig] from a JSON map (as stored in SharedPreferences).
  factory SiteConfig.fromJson(Map<String, dynamic> json) {
    return SiteConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      searchUrlTemplate: json['searchUrlTemplate'] as String?,
      type: siteTypeFromString(json['type'] as String? ?? 'reader'),
      iconUrl: json['iconUrl'] as String?,
      persistCookies: json['persistCookies'] as bool? ?? true,
    );
  }

  /// Serialises this [SiteConfig] to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'searchUrlTemplate': searchUrlTemplate,
      'type': siteTypeToString(type),
      'iconUrl': iconUrl,
      'persistCookies': persistCookies,
    };
  }

  /// The default sites seeded on first launch (starts empty by default).
  static List<SiteConfig> get defaultSites => [];
}
