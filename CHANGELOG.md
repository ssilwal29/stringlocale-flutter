# Changelog

## 0.3.0

Initial public release.

### Core Dart API (`package:stringlocale/stringlocale.dart`)

- `StringLocale` — declare a localizable string with a source text, a stable
  `id`, and typed `Param` descriptors. Instances auto-register and resolve
  via `StringLocale.resolve()`.
- `Param` factories covering every param kind:
  - `Param.literal()` — pass-through string
  - `Param.user()` — free-text pass-through (unformatted)
  - `Param.number()` — locale digit conversion
  - `Param.date()` — CLDR date formatting (`short` / `medium` / `long` / `full`)
  - `Param.currency()` — locale currency formatting with ISO 4217 code
  - `Param.relative()` — relative-time formatting ("3 days ago")
  - `Param.translatable()` — closed enum axis; values pre-translated at compile
    time and substituted at runtime (fully offline)
  - `Param.plural()` — CLDR plural axis (one / other / few / many / zero)
  - `Param.userAdapted()` — free prose reformatted per locale by an LLM adapter
    at runtime; falls back to the source value offline
- `Bundle` — runtime bundle loaded from compiled JSON; supports `resolve`
  (sync) and `resolveAsync` (async, for `userAdapted` params). Locale data can
  be merged incrementally via `Bundle.merge()`.
- `Bundle.fromDir()` / `Bundle.fromJsonString()` — load from a compiled
  directory (via an injected `FileReader`) or a raw JSON string.
- `load()` — convenience wrapper that reads a compiled directory with
  `dart:io` and sets it as the active bundle.
- Library-level helpers: `setLocale`, `getLocale`, `useBundle`,
  `currentBundle`, `getRegistry`, `clearRegistry`.
- `UserAdaptedMode.cached` (default) caches adapter results keyed by
  `(value, locale, context)`; `UserAdaptedMode.realtime` always calls the
  adapter.
- Axis model: multi-dimensional cross-product templates (e.g. gender × plural).
  Required axes are validated at resolve time.
- CLDR plural rules generated for all supported locales.

### Flutter API (`package:stringlocale/flutter.dart`)

- `StringLocaleScope` — `InheritedWidget` that holds the active locale and
  bundle; rebuilds descendants on locale change.
- `Tr` — sync widget that renders a `StringLocale` in the scope's current
  locale. Accepts an optional `builder` for custom styling.
- `AsyncTr` — async widget backed by a `FutureBuilder`; required for strings
  with `userAdapted` params. Re-resolves automatically on locale or args change.
- `tr()` / `trAsync()` — imperative helpers for use outside the widget tree
  (snackbars, dialogs, etc.).

### CLI (`stringlocale` executable)

- `stringlocale compile` — calls an LLM (OpenRouter by default) to produce
  compiled locale bundles from registered `StringLocale` declarations.
- `stringlocale check` — validates that all strings compile cleanly and that
  params match their declarations.
- `stringlocale prune` — removes stale string entries from existing bundle
  files that are no longer referenced in source.

### Default OpenRouter adapter

- On Dart VM and Flutter desktop/mobile, if `OPENROUTER_API_KEY` is set in
  the process environment or passed via `--dart-define`, a built-in async
  adapter is wired automatically for `userAdapted` params.
- Model defaults to `google/gemini-2.5-flash`; override with
  `OPENROUTER_MODEL`.
- macOS apps require `com.apple.security.network.client` in entitlements to
  allow outbound HTTP to OpenRouter.
