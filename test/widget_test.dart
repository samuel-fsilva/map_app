import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:map_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('zoom controls change the map zoom', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MapApp());
    await tester.pumpAndSettle();

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final initialZoom = controller.camera.zoom;

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, initialZoom + 1);

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, initialZoom);
  });

  testWidgets('creates, edits, and deletes markers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MapApp());
    await tester.pumpAndSettle();

    expect(find.text('My OSM Map'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Markers (0)'), findsOneWidget);

    await tester.tap(find.byTooltip('Add marker'));
    await tester.pumpAndSettle();
    expect(find.text('Add marker'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Home');
    await tester.enterText(find.byType(TextFormField).at(1), '-23.55');
    await tester.enterText(find.byType(TextFormField).at(2), '-46.63');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    expect(find.text('Markers (1)'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit marker'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Work');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byTooltip('Delete marker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Markers (0)'), findsOneWidget);
    expect(find.text('No markers yet.'), findsOneWidget);
  });
}
