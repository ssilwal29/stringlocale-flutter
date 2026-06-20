// Demonstrates the core stringlocale workflow:
//   1. Declare strings once with typed params
//   2. Compile to target locales (offline, no API key needed)
//   3. Resolve at runtime — pure offline lookup, no network call
//
// Run with: dart run example/lib/main.dart
//
// For LLM-drafted translations, set OPENROUTER_API_KEY and remove the
// drafter: argument — the compiler picks it up automatically.

import 'package:stringlocale/compile.dart';
import 'package:stringlocale/stringlocale.dart';

// 1. Declare strings once -------------------------------------------------

final welcome = StringLocale(
  'Welcome back, {name}! You have {count} new messages.',
  id: 'welcome',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
  },
  gendered: true, // generates male/female/other variants per locale
);

final orderTotal = StringLocale(
  '{name} placed an order for {amount}',
  id: 'order_total',
  params: {
    'name': Param.literal(),
    'amount': Param.currency('USD'),
  },
);

final strings = [welcome, orderTotal];
int registerAll() => strings.length;

// 2. Compile & resolve ----------------------------------------------------

Future<void> main() async {
  registerAll();

  const outDir = '.dart_tool/stringlocale_example';
  const locales = ['en-US', 'es-ES', 'fr-FR', 'ar-SA', 'hi-IN'];

  // OfflineDrafter emits deterministic placeholders so this runs without a key.
  // In production use: dart run stringlocale compile --locales ... --out assets/i18n
  final result = await compileStrings(
    strings: strings,
    locales: locales,
    drafter: OfflineDrafter(),
    sourceLocale: 'en-US',
    existingDir: outDir,
  );
  result.writeSplit(outDir);

  load(outDir, locale: 'en-US');

  // 3. Resolve at runtime — no API call, no network ----------------------
  for (final locale in locales) {
    setLocale(locale);
    print('--- $locale ---');
    print(welcome.resolve(args: {'name': 'Sofia', 'count': 3, 'gender': 'female'}));
    print(orderTotal.resolve(args: {'name': 'Sofia', 'amount': 149.99}));
    print('');
  }
}
