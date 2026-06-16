# stringlocale

[![pub package](https://img.shields.io/pub/v/stringlocale.svg)](https://pub.dev/packages/stringlocale)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Your UI strings have parameters: a count, a name, a price, a date. Translating them is not just swapping words:

- Spanish needs gender agreement: `Bienvenido` vs `Bienvenida`.
- Arabic has six plural forms and its own digits: `٥`, not `5`.
- Nepali writes numbers in Devanagari: `१२००`, and pluralizes differently again.

Normally you hand-maintain every one of those variants, per language, in JSON files that drift from your Dart code. **stringlocale** flips it around: you declare each string once and tag every parameter with what it is: a number, a plural count, a currency, a date, a gendered subject, a literal name, or a translated enum. A build-time compiler then generates every axis variant, such as gender x plural x custom variants, for every target locale into static JSON bundles. At runtime your Dart or Flutter app just looks them up. No translation API call happens while the app is running.

This package is the **Dart/Flutter runtime plus a CLI**: `compile`, `check`, and `prune`. The compiler writes plain JSON locale bundles, and the runtime reads them back in Dart or Flutter.

## Quick Start

**1. Install**

```yaml
dependencies:
  stringlocale: ^0.3.0
```

Import the runtime:

```dart
import 'package:stringlocale/stringlocale.dart';
```

For Flutter widgets:

```dart
import 'package:stringlocale/flutter.dart';
```

For build scripts, compiler APIs, and checks:

```dart
import 'package:stringlocale/compile.dart';
```

**2. Declare your strings** once, with a `Param` per `{placeholder}`:

```dart
// lib/strings.dart
import 'package:stringlocale/stringlocale.dart';

final greeting = StringLocale(
  'Welcome back, {name}',
  id: 'greeting',
  params: {'name': Param.literal()},
  gendered: true,
);

final inbox = StringLocale(
  'You have {count} messages',
  id: 'inbox',
  params: {'count': Param.plural()},
);

final fee = StringLocale(
  '{creator} charges {amount} per post',
  id: 'fee',
  params: {
    'creator': Param.literal(),
    'amount': Param.currency('USD'),
  },
);

final allStrings = [greeting, inbox, fee];

int registerAll() => allStrings.length;
```

Dart top-level `final` values are lazy. Keep your declarations in a list and call a registration function before compiling or resolving so every `StringLocale` is constructed.

**3. Set your translator key** if you want LLM-drafted translations through OpenRouter:

```bash
export OPENROUTER_API_KEY=sk-or-...
```

No key yet? Use `--drafter offline` to emit deterministic placeholder-style bundles and wire up the pipeline first.

**4. Compile to your target locales**:

```bash
dart run stringlocale compile \
  --locales en-US,es-ES,ne-NP,ar-SA \
  --source-locale en-US \
  --out public/i18n
```

This writes `public/i18n/manifest.json` plus one `bundle.<locale>.json` per locale, with every gender/plural/custom-axis variant filled in. Re-running only redrafts cells whose source text, locale, enum value, or OpenRouter model changed.

Choose a specific OpenRouter model:

```bash
dart run stringlocale compile \
  --locales en-US,es-ES,ne-NP \
  --source-locale en-US \
  --drafter openrouter \
  --model google/gemini-2.5-flash \
  --out public/i18n
```

**5. Use the same string in any locale**:

```dart
import 'package:stringlocale/stringlocale.dart';
import 'strings.dart';

void main() {
  registerAll();

  final bundle = Bundle.fromDir('public/i18n', ioFileReader);
  useBundle(bundle, locale: 'ne-NP');

  print(greeting.resolve(args: {'name': 'Anisha', 'gender': 'female'}));
  print(inbox.resolve(args: {'count': 5}));
}
```

In Flutter, wrap the app in `StringLocaleScope` and use `Tr` or `tr(context, ...)`. See [Resolving](#resolving).

**6. Keep bundles in sync as code changes**:

```bash
dart run stringlocale check --out public/i18n
dart run stringlocale prune --out public/i18n --dry-run
dart run stringlocale prune --out public/i18n
```

Use `check` as a CI gate: it exits non-zero when declarations and bundles drift.

## Declaring Strings

Each string is one typed object: a stable `id`, the source text, and a `Param` per `{placeholder}` describing how that value renders. Placeholders are validated against params at construction time.

```dart
// lib/strings.dart
import 'package:stringlocale/stringlocale.dart';

final followers = StringLocale(
  '{n} followers',
  id: 'followers',
  params: {'n': Param.number()},
);

final inbox = StringLocale(
  'You have {count} messages',
  id: 'inbox',
  params: {'count': Param.plural()},
);

final fee = StringLocale(
  '{creator} charges {amount} per post',
  id: 'fee',
  params: {
    'creator': Param.literal(),
    'amount': Param.currency('NPR'),
  },
);

final greeting = StringLocale(
  '{name}, your account is ready',
  id: 'greeting',
  params: {'name': Param.literal()},
  gendered: true,
);

final allStrings = [followers, inbox, fee, greeting];

int registerAll() => allStrings.length;
```

You do not write translation keys, per-locale JSON, plural tables, or formatting glue. The params carry enough structure for the compiler to draft the right cells and for the runtime to format values safely.

## CLI Reference: Compile, Check, Prune

### `compile`

Imports your Dart strings file, calls your registration function, drafts a translation for each cell across the target locales, and writes the bundles.

```bash
dart run stringlocale compile \
  --input lib/strings.dart \
  --register registerAll \
  --source-locale en-US \
  --locales ne-NP,nl-NL,ar-SA \
  --out public/i18n
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--input <path>` | `lib/strings.dart` | Dart file that declares strings |
| `--register <name>` | `registerAll` | Function called after import to construct lazy declarations |
| `--no-register` | off | Import the input file but skip a register function |
| `--locales <codes>` | required | Comma-separated locale list, preferably full tags like `ne-NP` |
| `--out <dir>` | `dist` | Output directory for split bundles |
| `--combined <path>` | off | Emit one combined bundle file instead of split per-locale files |
| `--source-locale <code>` | `en` | Locale of the source strings |
| `--drafter <mode>` | `auto` | `auto`, `offline`, or `openrouter` |
| `--model <id>` | `google/gemini-2.5-flash` | OpenRouter model id |
| `--force` | off | Re-draft every cell even when incremental hashes match |
| `--quiet` | off | Hide progress messages except final output |

**Translator.** With `OPENROUTER_API_KEY` set, `--drafter auto` uses OpenRouter. Without a key, it uses `OfflineDrafter`, which emits deterministic placeholders such as `ne:You have {count} messages`. You can force either behavior with `--drafter openrouter` or `--drafter offline`.

**Model tracking.** Generated bundles record the drafter and model that produced them:

```json
{
  "translation": {
    "drafter": "openrouter",
    "model": "google/gemini-2.5-flash"
  }
}
```

The model is also part of each cell's incremental hash, so the same model reuses unchanged translations, while choosing a different model drafts those cells again.

**Output.** Split output writes a manifest plus one file per locale:

```text
public/i18n/
  manifest.json
  bundle.ne-NP.json
  bundle.nl-NL.json
  bundle.ar-SA.json
```

Combined output writes one file:

```bash
dart run stringlocale compile \
  --locales en-US,ne-NP,nl-NL \
  --source-locale en-US \
  --combined public/i18n/bundle.json
```

During compilation the CLI prints the string count, target locales, drafter mode, model when supplied, and each locale as it starts.

### `check`

Imports the current strings, reads the compiled bundle, and reports drift. It exits non-zero on problems, so it fits CI.

```bash
dart run stringlocale check \
  --input lib/strings.dart \
  --register registerAll \
  --out public/i18n
```

It reports:

- **missing**: id declared in code but absent from the bundle
- **orphaned**: id in the bundle but no longer declared in code
- **stale**: recorded source text differs from current source text
- **placeholder drift**: translated templates dropped or invented placeholders
- **untranslated warnings**: non-source cells identical to the source text

### `prune`

Removes orphaned entries, meaning ids in the bundle that no longer exist in code, without redrafting anything.

```bash
dart run stringlocale prune --out public/i18n --dry-run
dart run stringlocale prune --out public/i18n
```

Use `--dry-run` first to preview removals.

## Resolving

Load bundles once at startup, then resolve strings anywhere. No LLM or network call happens at resolve time. It is a pure lookup with numbers, dates, currency, relative values, enum labels, plural categories, and digit conversion handled offline.

### Flutter

Declare your compiled bundles as assets in your app's `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/i18n/
```

Load the generated split bundles from assets:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:stringlocale/flutter.dart';

Future<Bundle> loadBundleFromAssets(String assetDir) async {
  final manifest = jsonDecode(
    await rootBundle.loadString('$assetDir/manifest.json'),
  ) as Map<String, dynamic>;
  final files = manifest['files'] as Map;

  Bundle? bundle;
  for (final entry in files.values.cast<Map>()) {
    final data = jsonDecode(
      await rootBundle.loadString('$assetDir/${entry['path']}'),
    ) as Map<String, dynamic>;
    if (bundle == null) {
      bundle = Bundle(data);
    } else {
      bundle.merge(data);
    }
  }

  if (bundle == null) throw StateError('No stringlocale bundles found');
  return bundle;
}
```

Wrap your app and render strings with `Tr`:

```dart
import 'package:flutter/material.dart';
import 'package:stringlocale/flutter.dart';

import 'strings.dart';

class App extends StatelessWidget {
  const App({super.key, required this.bundle});

  final Bundle bundle;

  @override
  Widget build(BuildContext context) {
    return StringLocaleScope(
      locale: 'ne-NP',
      bundle: bundle,
      child: Builder(
        builder: (context) => Column(
          children: [
            Tr(greeting, args: {'name': 'Anisha', 'gender': 'female'}),
            Tr(inbox, args: {'count': 5}),
            FilledButton(
              onPressed: () {
                final label = tr(context, fee, args: {
                  'creator': 'Anisha',
                  'amount': 2500,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(label)),
                );
              },
              child: const Text('Show'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Switch locale with the scope controller:

```dart
StringLocaleScope.of(context).setLocale('fr-FR');
```

The package includes a runnable Flutter sample with locale chips, `Tr`, imperative `tr(context, ...)`, compiled asset bundles, and a macOS runner:

```bash
cd example
flutter run -d macos
```

### Plain Dart

```dart
import 'package:stringlocale/stringlocale.dart';

import 'strings.dart';

void main() {
  registerAll();

  final bundle = Bundle.fromDir('public/i18n', ioFileReader);
  useBundle(bundle, locale: 'ne-NP');

  final text = fee.resolve(args: {
    'creator': 'Jane Doe',
    'amount': 2500,
  });

  print(text);
}
```

You can also pass `locale:` per call:

```dart
final text = inbox.resolve(
  locale: 'ja-JP',
  args: {'count': 5},
);
```

Before a bundle is loaded, `.resolve()` falls back to the source string and local value formatting.

## Parameter Types

| Helper | Use for | Runtime behavior |
| --- | --- | --- |
| `Param.literal()` | Brand names, usernames, URLs, proper nouns | Passed through verbatim |
| `Param.number()` | Numeric values | Locale digits and separators |
| `Param.plural()` | Counts that affect wording | Locale plural category plus number formatting |
| `Param.translatable([...])` | Fixed enum-like values | Translated at compile time and substituted at runtime |
| `Param.translatable([...], inline: true)` | Enum values that affect grammar | Folded into template variants |
| `Param.date(fmt)` | Dates | `package:intl` date formatting |
| `Param.currency('NPR')` | Money | `package:intl` currency formatting |
| `Param.relative()` | Relative time, such as `3 days ago` | Offline relative formatting |
| `Param.user()` | Free user text | Passed through untouched |
| `Param.userAdapted(context: ...)` | Free prose needing custom adaptation | Calls your bundle adapter only when supplied |

## userAdapted: What To Provide

`userAdapted` is a runtime adaptation hook for user-provided prose. It is opt-in and only applies to params you explicitly mark.

You need to provide three things:

1. Mark params that need adaptation:

```dart
final profileBio = StringLocale(
  'Creator bio: {bio}',
  id: 'profile_bio',
  params: {
    'bio': Param.userAdapted(
      context: 'Short creator profile shown to shoppers',
    ),
  },
);
```

2. Load the bundle. If `OPENROUTER_API_KEY` is set, `userAdapted` uses OpenRouter by default on async runtime APIs (`resolveAsync`, `AsyncTr`, `trAsync`). You can still pass your own adapter to override it:

```dart
import 'package:stringlocale/stringlocale.dart';

final bundle = load(
  'public/i18n',
  locale: 'ne-NP',
  userAdaptedMode: UserAdaptedMode.realtime,
  adapter: (value, locale, context) {
    // Implement your own service call here.
    return '$locale: $value';
  },
);
```

3. Resolve normally with user text in args:

```dart
final out = profileBio.resolve(args: {
  'bio': '1200 followers, vintage camera collector, ships on Fridays',
});
```

How it works:

- If no adapter is provided, `userAdapted` is passthrough.
- If `OPENROUTER_API_KEY` is set and no adapter is provided, async `userAdapted` uses OpenRouter automatically.
- If current locale shares the source language, adaptation is skipped.
- Adapter inputs are `(value, locale, context)`.
- `UserAdaptedMode.cached` keeps adapted results by `(value, locale, context)` to avoid repeated calls.
- `UserAdaptedMode.realtime` asks the adapter every time the string resolves.

Runnable examples:

- Offline adapter demo: `dart run example/main.dart`
- OpenRouter runtime adapter demo: `dart run example/user_adapted_openrouter.dart`

## Axes And Cell Economics

Use `gendered: true` for a built-in `gender` axis:

```dart
final message = StringLocale(
  '{name} has {count} saved campaigns',
  id: 'saved_campaigns',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
  },
  gendered: true,
);
```

Use custom axes for any other variant:

```dart
final cta = StringLocale(
  '{name}, your workspace is ready',
  id: 'workspace_ready',
  params: {'name': Param.literal()},
  axes: {
    'audience': ['buyer', 'seller'],
  },
  required: ['audience'],
);
```

Enum translations are additive by default. For example, `gender(2) + status(3) + category(5)` means 10 drafted cells, not 30. Use `inline: true` only when grammar needs the enum value inside the template variant.

## Runtime Behavior

The runtime is offline by default. It does not call an LLM, translation API, or remote service while your app runs; it only resolves already-compiled JSON.

Runtime behavior includes:

- split bundle loading from `manifest.json`
- combined bundle loading
- locale fallback chains such as `ne-NP -> ne -> source`
- custom fallback chains such as `pt-BR -> pt -> es`
- plural category selection
- enum substitution
- inline cross-product template selection
- native digit conversion for supported locales
- date, currency, number, and relative formatting
- optional `userAdapted` adapter calls

LLM-drafted translations are written to plain JSON, so you can review, diff, and version them like any other build artifact before shipping.

## Examples

Console sample:

```bash
dart run example/main.dart
```

Flutter macOS sample:

```bash
cd example
flutter run -d macos
```

Regenerate the Flutter sample assets:

```bash
dart run stringlocale compile \
  --input example/lib/flutter_strings.dart \
  --register registerFlutterSampleStrings \
  --locales en-US,hi-IN,ne-NP,nl-NL,fr-FR,ru-RU \
  --source-locale en-US \
  --out example/assets/i18n \
  --drafter offline
```

CLI help:

```bash
dart run stringlocale --help
```

## Develop

```bash
dart format .
flutter analyze
flutter test
dart pub publish --dry-run
```


For the example app:

```bash
cd example
flutter analyze
flutter test
flutter build macos --debug
```

## Notes

- Dates use `package:intl` and Gregorian calendars. For custom calendars, pre-format and pass as `Param.literal()`.
- The model class is `StringLocale`; Flutter's `Text` widget is unaffected. The Flutter widget provided by this package is `Tr`.
- `userAdapted` is the only kind that can touch custom runtime adaptation logic, and only if you pass an adapter to `Bundle`.
- Plural categories are generated from CLDR data during package maintenance, then resolved from committed Dart data at runtime.

## License

MIT