import 'package:flutter/widgets.dart';
import 'package:flutter_localisation/flutter_localisation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service_test.mocks.dart';

void main() {
  testWidgets('a live update rebuilds dependents without a relaunch', (
    final WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final MockApiRepository repository = MockApiRepository();
    when(repository.fetchUpdates(any)).thenAnswer(
      (final _) async => <String, dynamic>{
        'has_updates': true,
        'last_modified': '2026-11-11T12:00:00.000000',
        'translations': <String, dynamic>{
          'en': <String, dynamic>{'greeting': 'Hello from a live update'},
        },
      },
    );
    final TranslationService service = TranslationService(
      config: const TranslationConfig(
        secretKey: 'sk_live_test',
        projectId: 1,
        flavorName: 'Default',
        supportedLocales: <String>['en'],
      ),
      repository: repository,
    );
    await tester.runAsync(
      () => service.initialize(fetchUpdatesOnStart: false),
    );

    int builds = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TranslationProvider(
          service: service,
          generatedLocalizations: null,
          child: Builder(
            builder: (final BuildContext context) {
              builds++;
              final TranslationService s = TranslationProvider.of(
                context,
              ).service;
              return Text(s.getOverride('en', 'greeting') ?? 'bundled');
            },
          ),
        ),
      ),
    );
    expect(find.text('bundled'), findsOneWidget);

    await tester.runAsync(service.refresh);
    await tester.pump();

    expect(find.text('Hello from a live update'), findsOneWidget);
    expect(builds, 2);

    await tester.runAsync(service.clearCache);
    await tester.pump();
    expect(find.text('bundled'), findsOneWidget);

    service.dispose();
  });
}
