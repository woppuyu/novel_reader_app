import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_app/models/site_config.dart';

/// Handles loading and saving the list of [SiteConfig]s using SharedPreferences.
///
/// All sites are stored as a single JSON array string under [_storageKey].
/// On the very first launch (key not found), it seeds the list with
/// [SiteConfig.defaultSites].
class SiteRepository {
  static const String _storageKey = 'novel_hub_sites';

  /// Loads the list of sites from storage.
  ///
  /// Returns [SiteConfig.defaultSites] and saves them if no data exists yet
  /// (i.e., first launch).
  Future<List<SiteConfig>> loadSites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      // First launch — seed with defaults and persist them.
      final defaults = SiteConfig.defaultSites;
      await saveSites(defaults);
      return defaults;
    }

    // Decode the stored JSON array and deserialise each item.
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((item) => SiteConfig.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Persists the entire [sites] list, overwriting any previously saved data.
  Future<void> saveSites(List<SiteConfig> sites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(sites.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Appends [site] to the stored list and saves.
  Future<void> addSite(SiteConfig site) async {
    final sites = await loadSites();
    sites.add(site);
    await saveSites(sites);
  }

  /// Removes the site with the given [id] from the stored list and saves.
  /// Does nothing if no site with that id is found.
  Future<void> removeSite(String id) async {
    final sites = await loadSites();
    sites.removeWhere((s) => s.id == id);
    await saveSites(sites);
  }
}
