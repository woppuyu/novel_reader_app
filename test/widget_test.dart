// Basic smoke test for the NovelHub app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader_app/state/novel_hub_state.dart';
import 'package:novel_reader_app/screens/novel_hub_screen.dart';

void main() {
  testWidgets('NovelHub shows loading indicator on startup',
      (WidgetTester tester) async {
    final state = NovelHubState(); // isLoading starts true

    await tester.pumpWidget(
      ChangeNotifierProvider<NovelHubState>.value(
        value: state,
        child: const MaterialApp(home: NovelHubScreen()),
      ),
    );

    // Before init() completes, the loading indicator should be visible.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
