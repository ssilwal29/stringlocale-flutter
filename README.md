# stringlocale

[![pub package](https://img.shields.io/pub/v/stringlocale.svg)](https://pub.dev/packages/stringlocale)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Take a single app string: **"Welcome back, {name}! You have {count} new messages."**

Shipping it correctly across five languages means dealing with all of this:

| Language | What your translators must maintain |
|---|---|
| **Spanish** | Gender agreement: *Bienvenido* (male) vs *Bienvenida* (female); *mensaje* vs *mensajes* |
| **French** | Gender inflection in the greeting; *message* vs *messages* |
| **Hindi** | Subject gender changes verb endings throughout the sentence |
| **Arabic** | Six plural categories for *count* (zero, one, two, few, many, other) plus Eastern Arabic digits |
| **Japanese** | No plurals, but formality register shapes every word choice |

For one string across five languages with gender × plural, that is roughly 50 hand-maintained translation keys — all of which break silently when you rename `{count}` to `{unread}`.

**stringlocale** replaces all of that. Declare the string once in Dart, tag each `{placeholder}` with what it is, and run the compiler:

```dart
final welcome = StringLocale(
  'Welcome back, {name}! You have {count} new messages.',
  id: 'welcome',
  params: {
    'name': Param.literal(),
    'count': Param.plural(),
  },
  gendered: true,
);
```

```bash
dart run stringlocale compile \
  --locales es-ES,fr-FR,hi-IN,ja-JP,ar-SA \
  --source-locale en-US \
  --out assets/i18n
```

The compiler uses an LLM to generate every gender × plural variant per locale into static JSON. At runtime, resolving is a pure offline lookup — no API call, no network:

```dart
welcome.resolve(args: {'name': 'Sofia', 'count': 3, 'gender': 'female'})
// Spanish → "¡Bienvenida, Sofia! Tienes 3 mensajes nuevos."
// Arabic  → "مرحباً بعودتك، Sofia! لديك ٣ رسائل جديدة."
// Hindi   → "वापसी पर स्वागत है, Sofia! आपके 3 नए संदेश हैं।"
```

This package is the **Dart/Flutter runtime plus a CLI**: `compile`, `check`, and `prune`.

## Quick Start

**1. Add the dependency**

```yaml
dependencies:
  stringlocale: ^0.3.0
```

**2. Import**

```dart
import 'package:stringlocale/stringlocale.dart'; // runtime and declarations
import 'package:stringlocale/flutter.dart';       // Flutter widgets (optional)
import 'package:stringlocale/compile.dart';        // compiler API and build scripts
```

**3. Declare a string**

```dart
// lib/strings.dart
import 'package:stringlocale/stringlocale.dart';

final inbox = StringLocale(
  'You have {count} messages',
  id: 'inbox',
  params: {'count': Param.plural()},
);

// Force lazy top-level finals to initialize; return value is the string count.
int registerAll() => [inbox].length;
```

**4. Compile to your target locales**

Set your LLM API key, or use `--drafter offline` to skip the LLM and emit placeholder bundles. stringlocale works with any OpenAI-compatible `/chat/completions` endpoint (OpenRouter, OpenAI, Groq, Together, a local Ollama/LM Studio server, etc.):

```bash
# Default endpoint is OpenRouter; point STRINGLOCALE_BASE_URL elsewhere for any
# other OpenAI-compatible provider.
export STRINGLOCALE_API_KEY=sk-...
# export STRINGLOCALE_BASE_URL=https://api.openai.com/v1/chat/completions
# export STRINGLOCALE_MODEL=gpt-4o-mini

dart run stringlocale compile \
  --locales en-US,es-ES,fr-FR,ar-SA \
  --source-locale en-US \
  --out assets/i18n
```

This writes `assets/i18n/manifest.json` plus one `bundle.<locale>.json` per locale. Re-running only redrafts cells whose source text or locale changed.

**5. Resolve at runtime**

```dart
import 'package:stringlocale/stringlocale.dart';
import 'strings.dart';

void main() {
  registerAll();
  final bundle = Bundle.fromDir('assets/i18n', ioFileReader);
  useBundle(bundle, locale: 'es-ES');

  print(inbox.resolve(args: {'count': 5}));
  // → "Tienes 5 mensajes."
}
```

In Flutter, wrap the app in `StringLocaleScope` and use `Tr` or `tr(context, ...)`. See [Resolving](#resolving).

**6. Keep bundles in sync as code changes**

```bash
dart run stringlocale check --out assets/i18n          # CI gate — exits non-zero on drift
dart run stringlocale prune --out assets/i18n --dry-run
dart run stringlocale prune --out assets/i18n
```

## Declaring Strings

Each `StringLocale` has a stable `id`, the source text, and a `Param` per `{placeholder}`. Placeholders are validated against params at construction time — mismatches throw at startup, not silently at runtime.

Dart top-level `final` values are lazy, so nothing is constructed until first access. Keep all declarations in a list and call a registration function before compiling or resolving to force construction:

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

You do not write translation keys, per-locale JSON, plural tables, or formatting glue. The params carry enough structure for the compiler to draft the right cells and for the runtime to format values correctly.

## CLI Reference: Compile, Check, Prune

### `compile`

Imports your Dart strings file, calls your registration function, drafts a translation for each cell across the target locales, and writes the bundles.

```bash
dart run stringlocale compile \
  --input lib/strings.dart \
  --register registerAll \
  --source-locale en-US \
  --locales ne-NP,nl-NL,ar-SA \
  --out assets/i18n
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
| `--drafter <mode>` | `auto` | `auto`, `offline`, `llm`, or `openrouter` |
| `--model <id>` | `google/gemini-2.5-flash` | LLM model id |
| `--base-url <url>` | OpenRouter | OpenAI-compatible `/chat/completions` endpoint |
| `--force` | off | Re-draft every cell even when incremental hashes match |
| `--quiet` | off | Hide progress messages except final output |

**Translator.** With `STRINGLOCALE_API_KEY` (or `OPENROUTER_API_KEY`) set, `--drafter auto` uses the configured LLM via `LlmDrafter`. Without a key, it uses `OfflineDrafter`, which emits deterministic placeholders such as `ne:You have {count} messages`. You can force either behavior with `--drafter llm` (or `--drafter openrouter`) or `--drafter offline`. Point at any OpenAI-compatible API with `--base-url` or `STRINGLOCALE_BASE_URL`.

**Model tracking.** Generated bundles record the drafter and model that produced them:

```json
{
  "translation": {
    "drafter": "llm",
    "model": "google/gemini-2.5-flash"
  }
}
```

The model is also part of each cell's incremental hash, so the same model reuses unchanged translations, while choosing a different model drafts those cells again.

**Output.** Split output writes a manifest plus one file per locale:

```text
assets/i18n/
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
  --combined assets/i18n/bundle.json
```

During compilation the CLI prints the string count, target locales, drafter mode, model when supplied, and each locale as it starts.

### `check`

Imports the current strings, reads the compiled bundle, and reports drift. It exits non-zero on problems, so it fits CI.

```bash
dart run stringlocale check \
  --input lib/strings.dart \
  --register registerAll \
  --out assets/i18n
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
dart run stringlocale prune --out assets/i18n --dry-run
dart run stringlocale prune --out assets/i18n
```

Use `--dry-run` first to preview removals.

## Resolving

Load bundles once at startup, then resolve strings anywhere. No LLM or network call happens at resolve time. It is a pure lookup with numbers, dates, currency, relative values, enum labels, plural categories, and digit conversion handled offline.

### Flutter

The Flutter widget this package provides is `Tr` — it is unrelated to Flutter's own `Text` widget and the `StringLocale` model class does not conflict with any Flutter type.

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

  final bundle = Bundle.fromDir('assets/i18n', ioFileReader);
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

`Param.date` and `Param.currency` use `package:intl` with the Gregorian calendar. For non-Gregorian calendars, pre-format the value and pass it as `Param.literal()`.

## Runtime Adaptation

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

2. Load the bundle. If `STRINGLOCALE_API_KEY` (or `OPENROUTER_API_KEY`) is set, `userAdapted` uses the configured LLM by default on async runtime APIs (`resolveAsync`, `AsyncTr`, `trAsync`). Point at any OpenAI-compatible endpoint with `STRINGLOCALE_BASE_URL`. You can still pass your own adapter to override it:

```dart
import 'package:stringlocale/stringlocale.dart';

final bundle = load(
  'assets/i18n',
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

Notes:

- If the current locale shares the source language, adaptation is skipped automatically.
- Adapter signature is `(String value, String locale, String? context)`.
- `UserAdaptedMode.cached` memoizes results by `(value, locale, context)` to avoid repeated calls.
- `UserAdaptedMode.realtime` calls the adapter on every resolve.

Runnable examples:

- Offline adapter demo: `dart run example/main.dart`
- LLM runtime adapter demo: `dart run example/user_adapted_openrouter.dart`

## Axes and Variants

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

The runtime is offline by default. It does not call an LLM, translation API, or remote service while your app runs; it only resolves already-compiled JSON. A few behaviors worth knowing:

- **Locale fallback** — `ne-NP` falls back to `ne`, then to the source locale. Custom chains are supported: `'nl-BE': ['nl-NL', 'fr-FR']`.
- **Native digits** — Arabic, Devanagari, and other numeral systems are applied automatically where the locale expects them.
- **`userAdapted` is opt-in** — without an adapter or an LLM API key, it is passthrough. It never fires unless you explicitly mark a param with `Param.userAdapted(...)`.

LLM-drafted translations are plain JSON, so you can review, diff, and version them like any other build artifact before shipping.

## Running the Sample Apps

Minimal console sample (no API key needed, runs in seconds):

```bash
dart run example/lib/main.dart
```

Full console sample with all param types:

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

### Package

```bash
dart format .
flutter analyze
flutter test
dart pub publish --dry-run
```

### Example app

```bash
cd example
flutter analyze
flutter test
flutter build macos --debug
```

## License

MIT