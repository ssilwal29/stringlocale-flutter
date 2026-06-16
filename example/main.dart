/// Complete sample app. Run with:
///
///   dart run example/main.dart
///
/// It compiles an offline bundle, loads it, switches locales, and resolves
/// strings that use plurals, enum translation, inline enum axes, custom axes,
/// number/date/currency/relative formatting, free user text, and userAdapted.
import 'package:stringlocale/compile.dart';
import 'package:stringlocale/stringlocale.dart';

import 'sample_strings.dart';

const _outDir = '.dart_tool/stringlocale_sample';

Future<void> main() async {
  sampleRegisterAll();

  final result = await compileStrings(
    strings: sampleStrings,
    locales: const ['en-US', 'hi-IN', 'ne-NP', 'nl-NL', 'fr-FR', 'ru-RU'],
    drafter: OfflineDrafter(),
    sourceLocale: 'en-US',
    existingDir: _outDir,
  );
  result.writeSplit(_outDir);

  load(
    _outDir,
    locale: 'ne-NP',
    fallbacks: const {
      'nl-BE': ['nl-NL', 'fr-FR'],
    },
    adapter: _sampleAdapter,
  );

  print('Compiled ${result.cellCount()} cells into $_outDir.');
  for (final locale in ['en-US', 'hi-IN', 'ne-NP', 'nl-NL', 'fr-FR', 'ru-RU']) {
    _renderDashboard(locale);
  }

  final report = check(sampleStrings, _outDir);
  print('\nDrift check: ${report.summary()}');
}

void _renderDashboard(String locale) {
  setLocale(locale);

  print('\n--- $locale ---');
  print(dashboardTitle.resolve());
  print(campaignSummary.resolve(args: {
    'creator': 'Mira',
    'count': 12,
    'status': 'approved',
    'budget': 2500,
    'dueDate': '2026-07-15',
  }));
  print(audienceCta.resolve(args: {
    'name': 'Mira',
    'tier': 'gold',
    'status': 'pending',
    'audience': 'seller',
  }));
  print(creatorGreeting.resolve(args: {
    'name': 'Mira',
    'count': 4,
    'gender': 'female',
  }));
  print(metricLine.resolve(args: {
    'views': 120034,
    'updated': DateTime.now().subtract(const Duration(hours: 3)),
  }));
  print(internalNote.resolve(args: {
    'note': 'Keep product names and promo codes exactly as typed.',
  }));
  print(profileBio.resolve(args: {
    'bio': '1200 followers, vintage camera collector, ships on Fridays',
  }));
  print(deliveryNote.resolve(args: {
    'note': 'Preorder ships in 7 business days. Tracking links update nightly.',
  }));
  print(moderationReason.resolve(args: {
    'reason':
        'Contains all required legal details but reads too formal for marketplace shoppers.',
  }));
}

String _sampleAdapter(String value, String locale, String? context) {
  final hint = context == null ? '' : ' ($context)';
  return 'adapted for $locale$hint: $value';
}
