# stringlocale Flutter example

This is a small Flutter app that demonstrates `StringLocaleScope`, `Tr`, locale
switching, translated params, inline axes, `userAdapted` with a text box, and
imperative `tr(context, ...)`.

Run it on macOS:

```bash
cd example
flutter run -d macos
```

Run the console sample (includes Param.userAdapted with a local adapter):

```bash
dart run example/main.dart
```

Run the OpenRouter-backed runtime adapter sample for Param.userAdapted:

```bash
export OPENROUTER_API_KEY=...your key...
dart run example/user_adapted_openrouter.dart
```

The async runtime now uses OpenRouter by default when `OPENROUTER_API_KEY` is set.
The OpenRouter sample shows what users must provide for `userAdapted`:

- A `Param.userAdapted(...)` declaration (context optional, recommended).
- An `adapter` passed to `load(...)` or `Bundle(...)` only if you want to override the default.
- `userAdaptedMode: UserAdaptedMode.realtime` when you want the adapter to run on every resolve.
- `AsyncTr`/`trAsync` (or `Bundle.resolveAsync`) to allow HTTP-based runtime adaptation.
- Runtime args with the raw user text value.

The app loads compiled bundles from `assets/i18n`. Regenerate them from the
package root with:

```bash
dart run stringlocale compile \
	--input example/lib/flutter_strings.dart \
	--register registerFlutterSampleStrings \
	--locales en-US,hi-IN,ne-NP,nl-NL,fr-FR,ru-RU \
	--source-locale en-US \
	--out example/assets/i18n \
	--drafter offline
```

