import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:novel_reader_app/controllers/site_tab_controller.dart';
import 'package:novel_reader_app/models/site_config.dart';
import 'package:novel_reader_app/models/site_type.dart';
import 'package:novel_reader_app/repository/site_repository.dart';

/// The two main viewing modes in the app.
enum NovelHubMode { reading, query }

/// The central app state for NovelHub.
///
/// Manages two modes: [NovelHubMode.reading] and [NovelHubMode.query].
/// Each mode maintains its own tab configuration and active tab index.
class NovelHubState extends ChangeNotifier {
  final SiteRepository _repository = SiteRepository();

  /// All registered sites.
  List<SiteConfig> sites = [];

  /// Controllers for all registered sites, kept alive.
  List<SiteTabController> controllers = [];

  /// Current mode the user is viewing.
  NovelHubMode currentMode = NovelHubMode.reading;

  /// Active tab index when in Reading Mode.
  int activeReadingIndex = 0;

  /// Active tab index when in Query Mode.
  int activeQueryIndex = 0;


  /// App starts in loading state until SharedPreferences is loaded.
  bool isLoading = true;

  /// Controls the visibility of the floating action menu button.
  /// Hides on scroll down, shows on scroll up or scroll to top.
  bool showFab = true;

  /// Controls whether the FAB is currently docked/minimized to the right edge.
  bool isFabMinimized = false;

  /// Timer to automatically minimize/dock the FAB after 5 seconds of inactivity.
  Timer? _fabIdleTimer;

  /// Resets and starts the 5-second inactivity timer to dock the FAB.
  void resetFabIdleTimer() {
    _fabIdleTimer?.cancel();
    if (!showFab) return; // Only tick when FAB is visible in the layout
    isFabMinimized = false;
    _fabIdleTimer = Timer(const Duration(seconds: 5), () {
      isFabMinimized = true;
      notifyListeners();
    });
  }

  /// Restores the FAB to its full floating state and restarts the idle timer.
  void restoreFab() {
    isFabMinimized = false;
    resetFabIdleTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _fabIdleTimer?.cancel();
    super.dispose();
  }

  /// Prefilled site name from link long press event.
  String? pendingSiteName;

  /// Prefilled site URL from link long press event.
  String? pendingSiteUrl;

  /// Clears the prefilled pending site variables after they have been processed.
  void clearPendingSite() {
    pendingSiteName = null;
    pendingSiteUrl = null;
    notifyListeners();
  }

  /// Handles link long press events from any of the active WebViews.
  /// Cleans up search engine redirect parameters (like Google's /url?q=...)
  /// and strips out multiline innerText noise to get a concise site name.
  void handleLinkLongPress(String name, String url) {
    var cleanedUrl = url.trim();

    // 1. Resolve redirectors (e.g., Google search result redirect links)
    try {
      final uri = Uri.parse(cleanedUrl);
      if (uri.host.contains('google.com') && uri.path == '/url') {
        final target = uri.queryParameters['q'] ?? uri.queryParameters['url'];
        if (target != null && target.isNotEmpty) {
          cleanedUrl = target;
        }
      }
    } catch (_) {}

    // 2. Clean up name text (strip out URL fragments, multiple lines, and limit size)
    var cleanedName = name.trim();
    final lines = cleanedName
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (lines.isNotEmpty) {
      cleanedName = lines.first;
      // If the first line itself is a URL (like google's visual subtexts), try the second line
      if (cleanedName.toLowerCase().startsWith('http') ||
          cleanedName.toLowerCase().contains('www.')) {
        if (lines.length > 1) {
          cleanedName = lines[1];
        }
      }
    }

    // 3. Fallback to domain name if the title is blank or still resembles a URL
    if (cleanedName.isEmpty ||
        cleanedName.toLowerCase().startsWith('http') ||
        cleanedName.toLowerCase().contains('www.')) {
      try {
        final uri = Uri.parse(cleanedUrl);
        var host = uri.host;
        if (host.startsWith('www.')) host = host.substring(4);
        if (host.contains('.')) host = host.split('.').first;
        if (host.isNotEmpty) {
          cleanedName = host[0].toUpperCase() + host.substring(1);
        } else {
          cleanedName = 'New Site';
        }
      } catch (_) {
        cleanedName = 'New Site';
      }
    }

    // 4. Truncate name length if it's too long
    if (cleanedName.length > 40) {
      cleanedName = '${cleanedName.substring(0, 37)}...';
    }

    pendingSiteName = cleanedName;
    pendingSiteUrl = cleanedUrl;
    notifyListeners();
  }

  /// Helper to update FAB visibility from scroll events, triggering a rebuild.
  void updateFabVisibility(bool visible) {
    if (showFab != visible) {
      showFab = visible;
      isFabMinimized = false;
      if (visible) {
        resetFabIdleTimer();
      } else {
        _fabIdleTimer?.cancel();
      }
      notifyListeners();
    } else if (visible && isFabMinimized) {
      // If already visible but minimized, and the user scrolls up, restore the full FAB
      restoreFab();
    }
  }

  // ── Mode-Specific Getters ──────────────────────────────────────────────────

  /// All sites that belong to Reading Mode (i.e. SiteType.reader).
  List<SiteConfig> get readingSites =>
      sites.where((s) => s.type == SiteType.reader).toList();

  /// All sites that belong to Query Mode (i.e. SiteType.search or SiteType.reference).
  List<SiteConfig> get querySites =>
      sites.where((s) => s.type != SiteType.reader).toList();

  /// All controllers that belong to Reading Mode.
  List<SiteTabController> get readingControllers =>
      controllers.where((c) => c.siteConfig.type == SiteType.reader).toList();

  /// All controllers that belong to Query Mode.
  List<SiteTabController> get queryControllers =>
      controllers.where((c) => c.siteConfig.type != SiteType.reader).toList();

  /// Finds the global index in the master [controllers] list for the currently
  /// active controller in the current mode.
  ///
  /// Used by [IndexedStack] to display the correct WebView.
  int get globalActiveIndex {
    if (controllers.isEmpty) return 0;

    SiteTabController activeCtrl;
    if (currentMode == NovelHubMode.reading) {
      if (readingControllers.isEmpty) return 0;
      final idx = activeReadingIndex.clamp(0, readingControllers.length - 1);
      activeCtrl = readingControllers[idx];
    } else {
      if (queryControllers.isEmpty) return 0;
      final idx = activeQueryIndex.clamp(0, queryControllers.length - 1);
      activeCtrl = queryControllers[idx];
    }

    return controllers.indexOf(activeCtrl);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    sites = await _repository.loadSites();
    controllers = sites
        .map((s) => SiteTabController(
              s,
              onScroll: updateFabVisibility,
              onLinkLongPress: handleLinkLongPress,
              onUrlChanged: (url) => handleUrlChanged(s.id, url),
            ))
        .toList();
    isLoading = false;
    restoreFab();
  }

  void setMode(NovelHubMode mode) {
    if (currentMode == mode) return;
    currentMode = mode;
    showFab = true; // Make sure menu button is visible in the new mode
    restoreFab();
  }

  void setActiveTab(int index) {
    if (currentMode == NovelHubMode.reading) {
      if (index >= 0 && index < readingSites.length) {
        activeReadingIndex = index;
      }
    } else {
      if (index >= 0 && index < querySites.length) {
        activeQueryIndex = index;
      }
    }
    showFab = true; // Reset menu button to visible on tab change
    restoreFab();
  }


  /// Registers a new site, creates its controller, and switches the mode/tab
  /// to point to it immediately.
  Future<void> addSite(SiteConfig site) async {
    await _repository.addSite(site);
    sites.add(site);
    controllers.add(SiteTabController(
      site,
      onScroll: updateFabVisibility,
      onLinkLongPress: handleLinkLongPress,
      onUrlChanged: (url) => handleUrlChanged(site.id, url),
    ));

    // Switch mode and index to the newly added site.
    if (site.type == SiteType.reader) {
      currentMode = NovelHubMode.reading;
      activeReadingIndex = readingSites.length - 1;
    } else {
      currentMode = NovelHubMode.query;
      activeQueryIndex = querySites.length - 1;
    }
    showFab = true; // Ensure menu button is visible for the new site
    restoreFab();
  }

  /// Removes a site from registration and adjusts active indexes to keep them in bounds.
  Future<void> removeSite(String id) async {
    final index = sites.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final targetSite = sites[index];
    final isReader = targetSite.type == SiteType.reader;

    await _repository.removeSite(id);
    sites.removeAt(index);
    controllers.removeAt(index);

    // Adjust active indices for the mode the site was removed from.
    if (isReader) {
      final len = readingSites.length;
      if (len > 0) {
        activeReadingIndex = activeReadingIndex.clamp(0, len - 1);
      } else {
        activeReadingIndex = 0;
      }
    } else {
      final len = querySites.length;
      if (len > 0) {
        activeQueryIndex = activeQueryIndex.clamp(0, len - 1);
      } else {
        activeQueryIndex = 0;
      }
    }

    showFab = true; // Make menu button visible if stack changes
    restoreFab();
  }

  /// Handles drag-and-drop tab reordering inside a mode.
  ///
  /// Maps mode-specific indices back to the global [sites] and [controllers] lists
  /// and automatically shifts the active tab indexes so selection doesn't jump.
  /// Persists the new master sites order using SharedPreferences.
  void reorderSites(int oldIndex, int newIndex) {
    final isReading = currentMode == NovelHubMode.reading;
    final currentModeSites = isReading ? readingSites : querySites;

    if (oldIndex < 0 ||
        oldIndex >= currentModeSites.length ||
        newIndex < 0 ||
        newIndex >= currentModeSites.length) {
      return;
    }

    final siteToMove = currentModeSites[oldIndex];
    final globalOldIndex = sites.indexOf(siteToMove);

    // Remove from the master lists
    final site = sites.removeAt(globalOldIndex);
    final ctrl = controllers.removeAt(globalOldIndex);

    // Re-filter the current mode sites list to find insertion point relative to remaining sites
    final remainingSitesOfMode = isReading ? readingSites : querySites;

    int globalNewIndex;
    if (newIndex >= remainingSitesOfMode.length) {
      if (remainingSitesOfMode.isEmpty) {
        globalNewIndex = 0;
      } else {
        final lastSiteOfMode = remainingSitesOfMode.last;
        globalNewIndex = sites.indexOf(lastSiteOfMode) + 1;
      }
    } else {
      final targetSite = remainingSitesOfMode[newIndex];
      globalNewIndex = sites.indexOf(targetSite);
    }

    // Insert back into master lists
    sites.insert(globalNewIndex, site);
    controllers.insert(globalNewIndex, ctrl);

    // Shift active index mapping so the selected tab follows the item we dragged
    if (isReading) {
      if (activeReadingIndex == oldIndex) {
        activeReadingIndex = newIndex;
      } else if (activeReadingIndex > oldIndex && activeReadingIndex <= newIndex) {
        activeReadingIndex--;
      } else if (activeReadingIndex < oldIndex && activeReadingIndex >= newIndex) {
        activeReadingIndex++;
      }
    } else {
      if (activeQueryIndex == oldIndex) {
        activeQueryIndex = newIndex;
      } else if (activeQueryIndex > oldIndex && activeQueryIndex <= newIndex) {
        activeQueryIndex--;
      } else if (activeQueryIndex < oldIndex && activeQueryIndex >= newIndex) {
        activeQueryIndex++;
      }
    }

    // Save the new layout order to local storage
    _repository.saveSites(sites);

    notifyListeners();
  }

  /// Swaps a site configuration between Reading and Query modes.
  /// Rebuilds the tab controller and clamps indices.
  Future<void> toggleSiteMode(String id) async {
    final index = sites.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final oldSite = sites[index];
    final oldIsReader = oldSite.type == SiteType.reader;
    final newType = oldIsReader ? SiteType.search : SiteType.reader;

    final newSite = SiteConfig(
      id: oldSite.id,
      name: oldSite.name,
      baseUrl: oldSite.baseUrl,
      searchUrlTemplate: oldSite.searchUrlTemplate,
      type: newType,
      persistCookies: oldSite.persistCookies,
      iconUrl: oldSite.iconUrl,
    );

    // Swap config in master list and reconstruct its controller
    sites[index] = newSite;
    controllers[index] = SiteTabController(
      newSite,
      onScroll: updateFabVisibility,
      onLinkLongPress: handleLinkLongPress,
      onUrlChanged: (url) => handleUrlChanged(newSite.id, url),
    );

    // Adjust active indices for both modes to prevent index out of bounds
    final readLen = readingSites.length;
    if (readLen > 0) {
      activeReadingIndex = activeReadingIndex.clamp(0, readLen - 1);
    } else {
      activeReadingIndex = 0;
    }

    final queryLen = querySites.length;
    if (queryLen > 0) {
      activeQueryIndex = activeQueryIndex.clamp(0, queryLen - 1);
    } else {
      activeQueryIndex = 0;
    }

    // Save to SharedPreferences
    await _repository.saveSites(sites);
    restoreFab();
  }

  /// Updates the last visited URL of a site config and persists it.
  void handleUrlChanged(String id, String url) {
    final index = sites.indexWhere((s) => s.id == id);
    if (index == -1) return;

    if (sites[index].lastVisitedUrl == url) return;

    sites[index] = sites[index].copyWith(lastVisitedUrl: url);
    _repository.saveSites(sites);
  }

  /// Loads [url] inside an existing site tab, updates its history, and shifts focus.
  void openUrlInSite(String siteId, String url) {
    final index = sites.indexWhere((s) => s.id == siteId);
    if (index == -1) return;

    final targetSite = sites[index];
    final ctrl = controllers[index];

    // Load the URL in the controller
    ctrl.webViewController.loadRequest(Uri.parse(url));

    // Update the lastVisitedUrl state and SharedPreferences
    handleUrlChanged(siteId, url);

    // Switch active mode and tab index to point to this site
    final isReader = targetSite.type == SiteType.reader;
    if (isReader) {
      currentMode = NovelHubMode.reading;
      final readIndex = readingSites.indexWhere((s) => s.id == siteId);
      if (readIndex != -1) activeReadingIndex = readIndex;
    } else {
      currentMode = NovelHubMode.query;
      final queryIndex = querySites.indexWhere((s) => s.id == siteId);
      if (queryIndex != -1) activeQueryIndex = queryIndex;
    }

    showFab = true;
    restoreFab();
  }

  /// Exports all sites and progress into an obfuscated copy-pasteable Base64 string
  /// and automatically copies it to the system clipboard.
  Future<String> exportSaveCode() async {
    try {
      final jsonList = sites.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      final bytes = utf8.encode(jsonString);
      final saveCode = base64.encode(bytes);

      // Copy directly to the system clipboard
      await Clipboard.setData(ClipboardData(text: saveCode));
      return saveCode;
    } catch (e) {
      debugPrint('Export error: $e');
      rethrow;
    }
  }

  /// Restores sites and reading progress from a pasted Base64 save code.
  /// Merges them with the existing list of sites.
  Future<int> importSaveCode(String saveCode) async {
    try {
      final code = saveCode.trim();
      if (code.isEmpty) return 0;

      final decodedBytes = base64.decode(code);
      final jsonString = utf8.decode(decodedBytes);
      final decoded = jsonDecode(jsonString);

      if (decoded is! List) {
        throw const FormatException('Save code is not a valid list representation.');
      }

      final List<SiteConfig> importedSites = [];
      for (final item in decoded) {
        if (item is! Map<String, dynamic> ||
            item['id'] == null ||
            item['name'] == null ||
            item['baseUrl'] == null) {
          throw const FormatException('Invalid SiteConfig structure in save code.');
        }
        importedSites.add(SiteConfig.fromJson(item));
      }

      if (importedSites.isEmpty) {
        return 0;
      }

      // Merge imported sites into existing list based on id or baseUrl
      for (final imported in importedSites) {
        final existingIndex = sites.indexWhere(
          (s) => s.id == imported.id || s.baseUrl == imported.baseUrl,
        );

        if (existingIndex != -1) {
          // Update the configuration, keeping the imported details (including lastVisitedUrl!)
          sites[existingIndex] = imported;
        } else {
          sites.add(imported);
        }
      }

      // Save merged sites list to SharedPreferences
      await _repository.saveSites(sites);

      // Re-initialize all controllers
      controllers = sites
          .map((s) => SiteTabController(
                s,
                onScroll: updateFabVisibility,
                onLinkLongPress: handleLinkLongPress,
                onUrlChanged: (url) => handleUrlChanged(s.id, url),
              ))
          .toList();

      // Reset tabs active index boundaries to be safe
      final readLen = readingSites.length;
      if (readLen > 0) {
        activeReadingIndex = activeReadingIndex.clamp(0, readLen - 1);
      } else {
        activeReadingIndex = 0;
      }

      final queryLen = querySites.length;
      if (queryLen > 0) {
        activeQueryIndex = activeQueryIndex.clamp(0, queryLen - 1);
      } else {
        activeQueryIndex = 0;
      }

      notifyListeners();
      return importedSites.length;
    } catch (e) {
      debugPrint('Import error: $e');
      rethrow;
    }
  }
}
