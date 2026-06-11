# stringlocale_demo

Runnable Flutter demo for `stringlocale`.

This app shows how to:

- wrap your app with `StringLocaleScope`
- render localized messages with `Tr(...)`
- switch locale at runtime
- combine compile-time translated templates with runtime formatting
- inspect plural behavior for multiple counts on one screen
- use the demo itself as a live package guide
- see the actual message definitions that produce the rendered output

## What is in this demo

- `lib/texts.dart`: message definitions used by the demo
- `lib/compile.dart`: locale compile script for the demo locale set
- `lib/main.dart`: Flutter UI wired to `Renderer`, `StringLocaleScope`, and `Tr`
- `locales/`: generated locale JSON written by the compile script

The app loads compiled locale JSON from `locales/` at startup, so the screen reflects the same data produced by the compile step.

## Requirements

- Flutter SDK installed
- Dart SDK matching your Flutter toolchain
- `OPENROUTER_API_KEY` set if you want to run the compile step or exercise runtime `translatable` and `userAdapted` paths

## Install dependencies

```bash
flutter pub get
```

## Generate locale files

From this directory:

```bash
export OPENROUTER_API_KEY=sk-or-...
dart run lib/compile.dart
```

This writes locale files such as:

- `locales/ne-NP.json`
- `locales/ja-JP.json`
- `locales/nl-NL.json`
- `locales/zh-CN.json`
- `locales/hi-IN.json`
- `locales/ar-SA.json`
- `locales/fa-IR.json`
- `locales/bn-BD.json`
- `locales/th-TH.json`

## Run the app

```bash
flutter run -d macos
```

You can also target other supported Flutter platforms if you have them configured.

## What to look for in the UI

- switch between the supported locales with the buttons at the top
- follow Jane Doe making her website work across countries, from simple static copy to dynamic values, plurals, and dates
- each step shows one Dart definition followed immediately by the rendered result
- the plural step shows `countParam: 'pages'`, where one param chooses the plural branch and the other params are formatted normally
- the final section explains how this pattern is useful in a real localized screen
- the examples are driven by the same compiled message definitions used by the package, not by hard-coded display strings

## From code definition to rendered result

The demo makes this flow explicit:

1. Define a message in `lib/texts.dart` with `staticText(...)`, `dynamicText(...)`, or `pluralText(...)`.
2. Run `dart run lib/compile.dart` to generate locale JSON in `locales/`.
3. Launch the demo and switch locales to see how the same definition renders across languages.

The screen is intentionally ordered as a short story about Jane Doe taking her website global:

1. Start with static UI copy.
2. Make website text dynamic with values such as owner name, price, and status.
3. Let the `pages` param drive singular or plural output while `owner` and `amount` remain normal typed params.
4. Finish with a localized date.
5. See how the same pattern helps with real website localization.

Core examples from the demo source:

```dart
final welcome = staticText('welcome', 'Welcome to stringlocale');

final websitePlanPrice = dynamicText(
	'website_plan_price',
	'{owner}\'s website plan costs {amount} per month',
	{
		'owner': ParamKind.literal,
		'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),
	},
);

final pageCount = pluralText(
	'page_count',
	'You have {count} localized page',
	'You have {count} localized pages',
);

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

These definitions map directly to the live sections in the app:

- `welcome` appears in the static strings section
- `website_plan_price` appears in the dynamic text section with both the developer definition and the rendered result
- `localized_page_count` shows a dynamic plural where `pages` decides singular/plural while `owner` and `amount` are normal typed params
- `launch_date` closes the story with a formatted date

## Common issues

### The app runs but some values stay English

That is expected for:

- `literal` params such as names and brands
- `user` params, which are intentionally passed through unchanged

For `translatable` and `userAdapted` params elsewhere in the package, confirm `OPENROUTER_API_KEY` is set in the environment used by `flutter run`.

### The compile step fails

Check:

- `OPENROUTER_API_KEY` is set
- you are running the command from `stringlocale_demo/`
- your network allows access to OpenRouter

### I updated English source text but the locale file was skipped

The compiler skips entries whose source hash did not change. If you need to regenerate everything, edit `lib/compile.dart` to pass `force: true` to `compileLocales(...)` and rerun it.

## Related docs

See the repository root README for the full package guide, API overview, and explanation of message types, placeholders, plural rules, runtime behavior, and overrides.
