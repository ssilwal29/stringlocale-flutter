# Contributing

Thanks for helping improve `stringlocale`.

## Good first contributions

- Documentation fixes and clearer examples
- Locale formatting edge cases
- Tests for placeholder validation, plural rules, and render behavior
- Demo improvements that make package usage easier to understand

## Development setup

```bash
dart pub get
dart test
dart analyze lib
```

For the Flutter demo:

```bash
cd stringlocale_demo
flutter pub get
flutter analyze lib/main.dart lib/texts.dart
```

## Compile locale fixtures

Locale compilation uses OpenRouter. Set an API key before running compile scripts:

```bash
export OPENROUTER_API_KEY=sk-or-...
dart run example/compile.dart
```

## Pull requests

Please keep changes focused, add or update tests for behavior changes, and run the relevant analyzer/test commands before opening a PR.
