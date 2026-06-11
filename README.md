# stringlocale (Dart / Flutter)

Compile-time LLM localization for Dart and Flutter. You define your English source strings once, attach type information to each placeholder, generate locale JSON at build time, and render localized UI with lookup + interpolation at runtime.

Companion to [`stringlocale`](https://github.com/stringlocale/stringlocale) for Python and [`stringlocale-react`](https://github.com/stringlocale/stringlocale-react) for TypeScript. All three use the same locale JSON shape, which makes it practical to share translations across backend, web, and Flutter clients.

## What problem this solves

Most localization systems are strong at static strings but weak at mixed templates like:

- `Website status: {status}` where `status` should be translated dynamically
- `{owner}'s website plan costs {amount} per month` where only some values should be localized
- `You have {count} localized page(s)` where plural rules vary by locale
- user-authored prose that should keep its words but adapt dates, numbers, and currency formatting

`stringlocale` makes those cases explicit by forcing every placeholder to declare what it is.

## Where to use it

Use `stringlocale` when your Dart or Flutter app has localized UI that combines:

- static app copy
- runtime values like names, statuses, counts, dates, and prices
- plural rules that differ by locale
- generated locale JSON you want to review, commit, and override
- optional LLM help for translating controlled runtime labels

It is not a replacement for product/content strategy, human review, or every
calendar system. It is a practical layer for typed UI strings where placeholders
need explicit localization behavior.

## Installation

Add the package:

```bash
dart pub add stringlocale
```

For Flutter apps:

```bash
flutter pub add stringlocale
```

Or add it manually:

```yaml
dependencies:
  stringlocale: ^0.2.0
```

If you use Flutter widgets like `StringLocaleScope` and `Tr`, import:

```dart
import 'package:stringlocale/stringlocale_flutter.dart';
```

If you only need the pure Dart API, import:

```dart
import 'package:stringlocale/stringlocale.dart';
```

## Mental model

```text
texts.dart
  -> compile step with OpenRouter
  -> locales/ne-NP.json, locales/ja-JP.json, ...
  -> runtime Renderer lookup + interpolation
  -> LLM only for translatable / userAdapted param values
```

At compile time:

- static strings are translated once per locale
- dynamic template shells are translated once per locale
- plural strings generate singular form, plural form, and a safe boolean rule
- output is JSON that you can commit to source control

At runtime:

- most rendering is just lookup + placeholder substitution
- only `translatable` and `userAdapted` params call the LLM
- runtime-translated values are cached in memory by locale and context

## Quick start

### 1. Define messages

Create a file such as `texts.dart`:

```dart
import 'package:stringlocale/stringlocale.dart';

final welcome = staticText('welcome', 'Welcome to stringlocale');

final websitePlanPrice = dynamicText(
  'website_plan_price',
  '{owner}\'s website plan costs {amount} per month',
  {
    'owner': ParamKind.literal,
    'amount': const Param(
      'amount',
      kind: ParamKind.currency,
      currency: 'NPR',
    ),
  },
);

final websiteStatus = dynamicText(
  'website_status',
  'Website status: {status}',
  {
    'status': const Param(
      'status',
      kind: ParamKind.translatable,
      context: 'website publishing status',
    ),
  },
);

final pageCount = pluralText(
  'page_count',
  'You have {count} localized page',
  'You have {count} localized pages',
);

final texts = [
  welcome,
  websitePlanPrice,
  websiteStatus,
  pageCount,
];
```

### 2. Create a compile script

```dart
import 'package:stringlocale/stringlocale.dart';
import 'texts.dart';

Future<void> main() async {
  await compileLocales(
    texts: texts,
    locales: [
      'ne-NP:Nepali',
      'ja-JP:Japanese',
      'ar-SA:Arabic',
    ],
    localeDir: 'locales',
  );
}
```

### 3. Set your OpenRouter key

```bash
export OPENROUTER_API_KEY=sk-or-...
```

You need this key for:

- compile-time locale generation
- runtime `translatable` params
- runtime `userAdapted` params

You do not need it for pure lookup, number formatting, date formatting, currency formatting, or plural selection.

### 4. Generate locale JSON

```bash
dart run compile.dart
```

The package also exposes a small help command after install:

```bash
dart run stringlocale:compile --help
```

That command explains the compile setup, but it does not auto-discover your
messages. Dart cannot dynamically import your app's `texts.dart` by file path,
so the real compile command is the tiny project-local script above.

After `flutter pub add stringlocale`, you still create your own `compile.dart`
that imports your message list and calls `compileLocales(...)`. This keeps the
compile step explicit, testable, and compatible with normal Dart imports.

Typical output:

```json
{
  "welcome": {
    "text": "stringlocale मा स्वागत छ",
    "src_hash": "a3f1b2c4d5e6f7a8"
  },
  "page_count": {
    "singular": "तपाईंसँग {count} अभियान छ",
    "plural": "तपाईंसँग {count} अभियानहरू छन्",
    "rule": "count < 2",
    "rule_explanation": "Use singular when count is less than 2.",
    "src_hash": "b4c5d6e7f8a9b0c1"
  }
}
```

### 5. Render in your app

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stringlocale/stringlocale_flutter.dart';

import 'texts.dart';

void main() {
  final renderer = Renderer(
    localeData: {
      'ne-NP': jsonDecode(neNpJson) as Map<String, dynamic>,
      'ja-JP': jsonDecode(jaJpJson) as Map<String, dynamic>,
    },
  );

  runApp(
    StringLocaleScope(
      localeCode: 'ne-NP',
      languageName: 'Nepali',
      renderer: renderer,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Tr(welcome)),
        body: Column(
          children: [
            Tr(pageCount, args: {'count': 5}),
            Tr(websiteStatus, args: {'status': 'approved'}),
            Tr(websitePlanPrice, args: {'owner': 'Jane Doe', 'amount': 2500}),
          ],
        ),
      ),
    );
  }
}
```

## Message types and parameter kinds

### Static messages

Use `staticText()` or its alias `t()` when a string has no placeholders.

```dart
final welcome = staticText('welcome', 'Welcome to stringlocale');
final shortAlias = t('sign_in', 'Sign in');
```

### Dynamic messages

Use `dynamicText()` when the message contains placeholders and each placeholder has a declared type.

```dart
final launchDate = dynamicText(
  'launch_date',
  'Launch by {date}',
  {
    'date': const Param('date', kind: ParamKind.date, fmt: 'medium'),
  },
);
```

`message()` and `dynamic_()` are still available as backward-compatible aliases. `dynamic_()` exists because `dynamic` is a Dart keyword, but new code should prefer `dynamicText()`.

### Plural messages

Use `pluralText()` when a string changes by count. The compile step translates both forms and generates a locale-specific rule.

```dart
final pageCount = pluralText(
  'page_count',
  'You have {count} localized page',
  'You have {count} localized pages',
);
```

The count placeholder defaults to `count`, but you can change it:

```dart
final cartItems = pluralText(
  'cart_items',
  '{n} item in cart',
  '{n} items in cart',
  countParam: 'n',
);
```

Plural messages can also have additional typed placeholders. The `countParam`
is the one value used to choose singular vs plural; every other placeholder is
formatted normally.

```dart
final localizedPageCount = pluralText(
  'localized_page_count',
  '{owner}\'s website has {pages} localized page ready for {amount}',
  '{owner}\'s website has {pages} localized pages ready for {amount}',
  countParam: 'pages',
  params: {
    'owner': ParamKind.literal,
    'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),
  },
);
```

Render it with all placeholders, including the plural decider:

```dart
Tr(
  localizedPageCount,
  args: {'owner': 'Jane Doe', 'pages': 2, 'amount': 2500},
)
```

### Parameter kinds

| Kind | Use when | Runtime behavior |
|------|----------|------------------|
| `literal` | Brands, URLs, usernames, IDs | Passed through unchanged |
| `number` | Plain numeric values | Locale-aware digit conversion |
| `numberPlural` | Count value for plural messages | Drives singular/plural selection and formatting |
| `date` | Dates you want formatted | Uses `intl` date formatting |
| `currency` | Money amounts | Uses locale-aware currency formatting |
| `relative` | Relative times like "3 days ago" | Uses locale-aware relative formatting |
| `translatable` | Enum-like values such as status/category | LLM translation at runtime, cached |
| `user` | User-authored text that must stay untouched | Passed through unchanged |
| `userAdapted` | Free text whose words stay the same but numbers/dates should adapt | LLM adaptation at runtime, cached |

### When to choose `translatable` vs `user`

Use `translatable` for a limited vocabulary you control, such as:

- `approved`
- `fashion`
- `instagram`

Use `user` for content you must not rewrite, such as:

- comments
- support notes entered by users
- imported copy from another system

Use `userAdapted` for content where prose should remain untouched but locale formatting should change, such as:

- `Offer ends Feb 15, 2026 and costs NPR 2,500`

## Placeholder rules

`stringlocale` validates your templates up front.

- every `{placeholder}` in the source must be declared in params
- every declared param must exist in the source
- compile-time translations must preserve placeholders
- plural rules are validated before being written to JSON

This catches common localization failures early instead of silently rendering broken templates.

## Compiling locales in practice

`compileLocales()` accepts:

- `texts`: your list of `Message`s
- `locales`: locale entries as either `code` or `code:Language`
- `localeDir`: output directory, default `locales`
- `model`: OpenRouter model name
- `apiKey`: optional explicit API key override
- `force`: retranslate even if source hashes are unchanged
- `client`: custom HTTP client, useful in tests

Example:

```dart
await compileLocales(
  texts: texts,
  locales: ['ne-NP:Nepali', 'ja-JP:Japanese'],
  localeDir: 'locales',
  force: false,
);
```

### Recompile behavior

The compiler stores a stable `src_hash` for each source string.

- unchanged source: skipped on the next compile
- changed source: retranslated
- override exists: compile warns if the source changed so you can review stale manual translations

### What gets translated at compile time

- static messages
- translated template shells for dynamic messages
- both sides of plural messages
- plural rules

### What does not get translated at compile time

- `translatable` param values such as `approved`
- `userAdapted` runtime free text
- actual runtime data passed by the caller

## Using the renderer

The `Renderer` is the runtime engine. It can be used with or without Flutter.

```dart
final renderer = Renderer(
  localeDir: 'locales',
  useDigitConversion: true,
  localeData: {
    'ne-NP': neNpMap,
  },
);
```

Useful methods:

- `render(...)` renders a `Message`
- `setLocale(...)` registers compiled locale data in memory
- `loadLocale(...)` loads `locales/<code>.json` and merges overrides
- `setOverrides(...)` injects manual overrides in memory
- `clearValueCache()` resets cached runtime value translations
- `clearLocaleCache()` clears cached locale JSON

### Pure Dart usage

```dart
final renderer = Renderer(localeData: {'ne-NP': neNpMap});

final text = await renderer.render(
  welcome,
  'ne-NP',
  languageName: 'Nepali',
);
```

### Flutter widget usage

Wrap your widget tree in `StringLocaleScope`:

```dart
StringLocaleScope(
  localeCode: 'ja-JP',
  languageName: 'Japanese',
  renderer: renderer,
  child: MyHomePage(),
)
```

Render text with `Tr`:

```dart
Tr(welcome)
Tr(pageCount, args: {'count': 5})
Tr(websiteStatus, args: {'status': 'approved'})
```

Use a custom builder if you do not want the default `Text` widget:

```dart
Tr(
  welcome,
  builder: (value) => Text(
    value,
    style: Theme.of(context).textTheme.titleLarge,
  ),
)
```

### Switching locale in Flutter

```dart
StringLocaleScope.of(context).setLocale('ja-JP', 'Japanese');
```

You can also rebuild the parent `StringLocaleScope` with a new `localeCode` and `languageName`.

### Imperative rendering

Use `trAsync()` outside build methods, for example inside callbacks:

```dart
final label = await trAsync(
  context,
  websitePlanPrice,
  args: {'owner': 'Jane Doe', 'amount': 2500},
);
```

## Loading locale JSON

There are two common ways to provide compiled data.

### Option 1: parse JSON yourself and pass `localeData`

Good for demos, tests, or when you already have the JSON in memory.

```dart
final renderer = Renderer(
  localeData: {
    'ne-NP': jsonDecode(neNpJson) as Map<String, dynamic>,
  },
);
```

### Option 2: use `loadLocale()`

Good for Dart VM and non-web Flutter when locale files live on disk.

```dart
final renderer = Renderer(localeDir: 'locales');
await renderer.loadLocale('ne-NP');
```

`loadLocale()` automatically merges `locales/overrides/<code>.json` on top if present.

## Plural rules and safety

Dart has no `eval`, so `stringlocale` uses a tiny built-in expression evaluator for plural rules. Rules are limited to safe syntax:

- one count variable such as `count`
- integer literals
- `+ - * / %`
- `== != < > <= >=`
- `&& || !`
- parentheses
- boolean literals `true` and `false`

Examples:

```text
count < 2
count == 1
count % 10 == 1 && count % 100 != 11
true
```

If a rule is invalid at runtime, the renderer falls back to `count < 2`.

## Digit conversion and formatting

`number`, `numberPlural`, `date`, `currency`, and `relative` can convert digits for locales that use non-Latin numerals.

| Locale | `12` becomes |
|--------|--------------|
| `ne`, `hi` | `१२` |
| `ar` | `١٢` |
| `fa` | `۱۲` |
| `bn` | `১২` |
| `th` | `๑๒` |

Disable this if you want raw Western digits everywhere:

```dart
final renderer = Renderer(useDigitConversion: false);
```

Date formatting uses `intl` and stays Gregorian. If your app needs Bikram Sambat or another non-Gregorian calendar, format the date yourself and pass it as `literal` or `user`.

## Registry helper

If you prefer collecting messages in one place with duplicate-key protection, use `Registry`:

```dart
final registry = Registry();

final welcome = registry.staticText('welcome', 'Welcome');
final status = registry.dynamicText('status', 'Status: {status}', {
  'status': ParamKind.translatable,
});

final texts = registry.texts;
```

`Registry` throws immediately if the same key is registered twice.

## Manual overrides

Overrides are human-reviewed corrections layered on top of generated locale JSON.
You do not need them to get started. They become useful when an LLM translation
is mostly right but needs a product, legal, brand, or native-speaker adjustment.

Keep generated files in `locales/<code>.json`, then put human edits for that
same locale in:

```text
locales/overrides/<locale>.json
```

For example, Nepali corrections go in `locales/overrides/ne-NP.json`, while
Japanese corrections go in `locales/overrides/ja-JP.json`.

Example:

```json
{
  "welcome": {
    "text": "मानव-सम्पादित अनुवाद",
    "src_hash": "a3f1b2c4d5e6f7a8"
  }
}
```

Behavior:

- overrides always win at runtime
- the compiler does not overwrite override files
- if the English source changes, compile warns that the override may be stale
- deleting an override falls back to the generated translation

You can also inject overrides directly:

```dart
renderer.setOverrides('ne-NP', overrideMap);
```

Most small apps can ignore overrides at first. For production apps, they give
you a clean review workflow: generate translations quickly, review them in
`dashboard.html`, export only the corrections, and keep those corrections stable
across future compiles.

## Runtime fallback behavior

If a locale entry does not exist:

- static and dynamic messages fall back to the English source template
- plural messages fall back to the English plural form when localized data is missing

If a runtime translation call fails inside `Tr`, the widget shows its fallback text, which defaults to the English source.

## Caching behavior

Runtime value translation is cached in memory:

- `translatable` values cache by value + locale + context
- `userAdapted` values cache by content hash + locale + context

This keeps repeated enum values like `approved` from hitting the LLM on every render.

## Demo app

This repository includes:

- `example/` for a package-style example
- `stringlocale_demo/` for a runnable Flutter app
- `dashboard.html` for reviewing and exporting overrides

To compile locales for the demo:

```bash
cd stringlocale_demo
dart run lib/compile.dart
```

To run the Flutter demo:

```bash
cd stringlocale_demo
flutter run -d macos
```

The current demo app in `stringlocale_demo/lib/main.dart` is intentionally self-contained and embeds a small amount of compiled locale JSON inline for Nepali and Japanese so it can render without wiring an asset loader first.

## Translation dashboard

Open `dashboard.html` in a browser. It is a standalone static page with no backend. You can:

- load compiled locale JSON
- inspect keys across locales
- edit translations inline
- export one override file per edited locale, compatible with `locales/overrides/<code>.json`

## Troubleshooting

### My UI stays in English

Check these first:

- the active `localeCode` is not `en`
- `StringLocaleScope` is wrapping the subtree that renders `Tr`
- the locale JSON was loaded into `Renderer`
- the message key exists in the compiled JSON

### `OPENROUTER_API_KEY is not set`

Set the environment variable before compile or runtime calls that need LLM access:

```bash
export OPENROUTER_API_KEY=sk-or-...
```

### Compile keeps skipping my key

That means the source string hash has not changed. If you need a full regeneration, run with `force: true` in your compile script.

### My placeholder disappeared in a translation

The compiler validates placeholders and throws if a translated string drops one unexpectedly. Keep placeholders exactly as `{name}` in your English source.

### `languageName` is required

That only applies when rendering a non-English message with `translatable` or `userAdapted` params. Pass `languageName` to `render(...)`, or use `StringLocaleScope` in Flutter so the widget layer supplies it.

### I need custom calendars or domain-specific formatting

Preformat those values yourself and pass them as `literal` or `user`. `stringlocale` is intentionally strict about what it formats automatically.

## API overview

Main exports from `package:stringlocale/stringlocale.dart`:

- `Message`, `Param`, `ParamKind`
- `staticText()`, `t()`, `dynamicText()`, `message()`, `dynamic_()`, `pluralText()`, `plural()`
- `Registry`
- `Renderer`
- `compileLocales()`
- `formatNumber()`, `formatDateValue()`, `formatCurrencyValue()`, `formatRelativeValue()`
- `PluralRuleEvaluator`

Additional Flutter exports from `package:stringlocale/stringlocale_flutter.dart`:

- `StringLocaleScope`
- `Tr`
- `trAsync()`

## License

MIT
