# NovelHub

NovelHub is a modern, distraction-free, 100% full-screen web novel reader and search directory manager built with Flutter. It separates your active consumption (Reading Mode) from directories and lookup tools (Query Mode) and maximizes screen real estate by hiding browser toolbars inside an animated, auto-docking floating control button.

---

## 🌟 Key Features

*   **📖 Dual Operation Modes**:
    *   **Reading Mode**: Dedicated tabs for your active novel reading websites (e.g. Royal Road, custom author blogs).
    *   **Query Mode**: Dedicated tabs for discovery and tracking directories (e.g. NovelUpdates, Wikipedia, lookup pages).
*   **📱 Maximum Reading Space**: 100% full-screen WebView rendering. App headers, tab selectors, search bars, and controllers are consolidated inside a bottom sheet Control Panel, keeping your view completely clear of clutter.
*   **⏱️ Auto-Hide Floating Explore Button**: The floating explore menu button auto-minimizes and docks to the right side of the screen as a subtle arrow handle after 5 seconds of inactivity. Tapping the handle or scrolling back up restores the button instantly.
*   **🔗 Link Long-Press Prefill**: Tap-and-hold (long-press) any hyperlink inside a WebView to trigger the "Add New Site" form with the site name and destination URL already pre-filled. It automatically strips Google search redirection wrappers and removes heading subtext noise.
*   **🔀 Drag-and-Drop Tab Reordering**: Easily rearrange the order of your site tabs inside the Control Panel using built-in drag handles. Your custom order is saved instantly.
*   **🔄 Native Gestures & Navigation**:
    *   **Pull-to-Refresh**: Swipe down from the top of any WebView to reload the active web page.
    *   **Smart Back Navigation**: Pressing your phone's hardware back button steps back through the WebView's browsing history instead of closing the app. If you are on the homepage, it exits cleanly.
*   **💾 Local Persistence**: All site settings, custom tabs, and cookie/session states are saved locally so you remain logged in and your layouts persist across app launches.

---

## 🚀 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel, version 3.16+)
*   Dart SDK (version 3.0+)
*   An Android/iOS device or emulator with internet connectivity.

### Running the App
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/<your-username>/novel_reader_app.git
    cd novel_reader_app
    ```
2.  **Get Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run in Debug Mode**:
    ```bash
    flutter run
    ```

---

## 📁 Project Architecture

```
lib/
├── controllers/
│   └── site_tab_controller.dart # Manages individual WebViewController instance scroll/refresh states
├── models/
│   ├── site_config.dart        # Model defining website metadata, schema, and queries
│   └── site_type.dart          # Enum for site types (reader, search, reference)
├── repository/
│   └── site_repository.dart    # SharedPreferences local disk storage coordinator
├── screens/
│   ├── add_site_screen.dart    # Bottom sheet form to configure and register new sites
│   └── novel_hub_screen.dart   # Main Scaffold, PopScope, and floating docking gesture layer
└── state/
    └── novel_hub_state.dart    # Central state provider mapping index shifting and tab management
```

---

## 💡 Quick Tips

1.  **Adding a Site**: Tap the floating explore button in the bottom right, select **Add New Site**, and type a name and URL (e.g. `royalroad.com`). You can omit the `https://` scheme; the app normalizes it automatically.
2.  **Fast Link Saving**: While reading or searching inside the WebView, tap and hold on any link to trigger the Add Site menu prefilled with that link's details.
3.  **Rearranging Tabs**: Open the explore panel and use the three horizontal lines drag handles (`=`) to swap tab order.
4.  **Confirming Changes**: Long-pressing a tab item inside the Control Panel will ask if you want to switch it from Reading Mode to Query Mode (or vice versa).
