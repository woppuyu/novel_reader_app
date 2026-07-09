import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:novel_reader_app/models/site_config.dart';

/// Wraps a [WebViewController] for a single site tab.
///
/// One [SiteTabController] is created per [SiteConfig] and kept alive for
/// the entire app session — switching tabs in the UI does NOT dispose these.
/// This means each tab preserves its scroll position, session cookies, and
/// browsing history.
class SiteTabController {
  /// The site configuration this controller is bound to.
  final SiteConfig siteConfig;

  /// The underlying WebView controller. Pass this to [WebViewWidget].
  late final WebViewController webViewController;

  Completer<void>? _refreshCompleter;

  double _lastScrollY = 0;

  SiteTabController(
    this.siteConfig, {
    required void Function(bool visible) onScroll,
    required void Function(String name, String url) onLinkLongPress,
    required void Function(String url) onUrlChanged,
  }) {
    // Create and configure the WebViewController once during construction.
    webViewController = WebViewController()
      // Enable JavaScript — most modern novel sites require it.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Listen for custom long press actions inside the WebView.
      ..addJavaScriptChannel(
        'LinkLongPressChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final url = data['url'] as String;
            final text = data['text'] as String;
            onLinkLongPress(text, url);
          } catch (_) {}
        },
      )
      // Allow the WebView to handle all navigation internally (follow links,
      // form submissions, etc.) without popping back to the native browser.
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              onUrlChanged(change.url!);
            }
          },
          onPageFinished: (url) {
            _finishRefresh();
            onUrlChanged(url);
            // Inject long-press listener and CSS callout disable rules
            webViewController.runJavaScript('''
              (function() {
                // 1. Disable native touch callouts / context menus via CSS
                var style = document.getElementById('nr-callout-override');
                if (!style) {
                  style = document.createElement('style');
                  style.id = 'nr-callout-override';
                  style.type = 'text/css';
                  style.innerHTML = '* { -webkit-touch-callout: none !important; }';
                  document.head.appendChild(style);
                }

                // 2. Intercept contextmenu (long press)
                document.addEventListener('contextmenu', function(e) {
                  var target = e.target;
                  while (target && target.tagName !== 'A') {
                    target = target.parentNode;
                  }
                  if (target && target.tagName === 'A' && target.href) {
                    e.preventDefault();
                    var linkData = {
                      url: target.href,
                      text: target.innerText.trim() || target.textContent.trim() || ""
                    };
                    LinkLongPressChannel.postMessage(JSON.stringify(linkData));
                  }
                });
              })();
            ''');
          },
          onWebResourceError: (error) => _finishRefresh(),
        ),
      )
      // Track scroll updates to show/hide the menu button.
      ..setOnScrollPositionChange((change) {
        final currentY = change.y;
        final delta = currentY - _lastScrollY;
        _lastScrollY = currentY;

        // If at the very top, always show the menu button
        if (currentY <= 15) {
          onScroll(true);
        }
        // If scrolling down with significant movement, hide the menu button
        else if (delta > 20) {
          onScroll(false);
        }
        // If scrolling up with significant movement, show the menu button
        else if (delta < -20) {
          onScroll(true);
        }
      })
      // Load the last visited page if available, otherwise the default base URL.
      ..loadRequest(Uri.parse(siteConfig.lastVisitedUrl ?? siteConfig.baseUrl));
  }

  /// Searches the site by replacing the `{query}` placeholder in
  /// [SiteConfig.searchUrlTemplate] with the URL-encoded [query].
  ///
  /// Does nothing if the site has no search template configured.
  void search(String query) {
    final template = siteConfig.searchUrlTemplate;
    if (template == null || template.isEmpty) return;

    // URL-encode the query so spaces and special chars are safe in a URL.
    final encoded = Uri.encodeComponent(query);
    final url = template.replaceAll('{query}', encoded);
    webViewController.loadRequest(Uri.parse(url));
  }

  /// Reloads the site's base URL, effectively "resetting" the tab.
  void reset() {
    webViewController.loadRequest(Uri.parse(siteConfig.baseUrl));
  }

  /// Triggered by the Pull-to-Refresh indicator.
  ///
  /// Reloads the page and returns a [Future] that resolves once the page
  /// finishes loading or encounters an error.
  Future<void> onRefresh() async {
    _refreshCompleter = Completer<void>();
    await webViewController.reload();
    return _refreshCompleter!.future;
  }

  /// Signals that the refresh animation is complete.
  void _finishRefresh() {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      _refreshCompleter!.complete();
    }
  }
}
