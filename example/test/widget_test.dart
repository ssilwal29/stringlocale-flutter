import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stringlocale_example/flutter_app.dart';
import 'package:stringlocale/stringlocale.dart';

String _testAdapter(String value, String locale, String? context) {
  final contextPart = context == null ? '' : ' ($context)';
  return '[$locale]$contextPart $value';
}

void main() {
  testWidgets('switches the sample locale', (tester) async {
    final bundle = await loadSampleBundle(
      adapter: (value, locale, context) => value,
      userAdaptedMode: UserAdaptedMode.realtime,
    );
    await tester.pumpWidget(StringLocaleFlutterSample(bundle: bundle));

    expect(find.text('Creator orders'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'ne-NP'));
    await tester.pumpAndSettle();

    expect(find.text('ne:Creator orders'), findsOneWidget);
  });

  testWidgets('userAdapted preview renders with adapter', (tester) async {
    final bundle = await loadSampleBundle(
      adapter: _testAdapter,
      userAdaptedMode: UserAdaptedMode.realtime,
    );
    final direct = await bundle.resolveAsync(
      'ne-NP',
      'flutter_sample.user_adapted_preview',
      {'note': 'Arrives in 7 days'},
    );
    expect(
      direct,
      contains(
        '[ne-NP] (Friendly short note shown to shoppers in product cards) Arrives in 7 days',
      ),
    );
    await tester.pumpWidget(
      StringLocaleFlutterSample(bundle: bundle),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'ne-NP'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byType(TextField),
      'Arrives in 7 days',
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '[ne-NP] (Friendly short note shown to shoppers in product cards) Arrives in 7 days',
      ),
      findsOneWidget,
    );
  });
}
