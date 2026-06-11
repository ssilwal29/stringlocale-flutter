import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stringlocale/stringlocale_flutter.dart';

import 'texts.dart';

const _demoLocales = <_DemoLocale>[
  _DemoLocale('en', 'English', 'English'),
  _DemoLocale('ne-NP', 'Nepali', 'Nepali'),
  _DemoLocale('ja-JP', 'Japanese', 'Japanese'),
  _DemoLocale('nl-NL', 'Dutch', 'Dutch'),
  _DemoLocale('zh-CN', 'Mandarin', 'Mandarin Chinese'),
  _DemoLocale('hi-IN', 'Hindi', 'Hindi'),
  _DemoLocale('ar-SA', 'Arabic', 'Arabic'),
  _DemoLocale('fa-IR', 'Persian', 'Persian'),
  _DemoLocale('bn-BD', 'Bengali', 'Bengali'),
  _DemoLocale('th-TH', 'Thai', 'Thai'),
];

const _siteOwnerName = 'Jane Doe';
const _openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

const _statusByLocale = <String, String>{
  'en': 'approved',
  'ne-NP': 'स्वीकृत',
  'ja-JP': '承認済み',
  'nl-NL': 'goedgekeurd',
  'zh-CN': '已批准',
  'hi-IN': 'स्वीकृत',
  'ar-SA': 'تمت الموافقة',
  'fa-IR': 'تایید شده',
  'bn-BD': 'অনুমোদিত',
  'th-TH': 'อนุมัติแล้ว',
};

const _welcomeCode =
    "final welcome = staticText('welcome', 'Welcome to stringlocale');";

const _websitePlanPriceCode =
    "final websitePlanPrice = dynamicText(\n"
    "  'website_plan_price',\n"
    "  '{owner}\\'s website plan costs {amount} per month',\n"
    "  {\n"
    "    'owner': ParamKind.literal,\n"
    "    'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),\n"
    "  },\n"
    ");";

const _localizedPageCountCode =
    "final localizedPageCount = pluralText(\n"
    "  'localized_page_count',\n"
    "  '{owner}\\'s website has {pages} localized page ready for {amount}',\n"
    "  '{owner}\\'s website has {pages} localized pages ready for {amount}',\n"
    "  countParam: 'pages',\n"
    "  params: {\n"
    "    'owner': ParamKind.literal,\n"
    "    'amount': const Param('amount', kind: ParamKind.currency, currency: 'NPR'),\n"
    "  },\n"
    ");";

const _websiteStatusCode =
    "final websiteStatus = dynamicText(\n"
    "  'website_status',\n"
    "  'Website status: {status}',\n"
    "  {'status': ParamKind.literal},\n"
    ");";

const _websiteAudienceCode =
    "final websiteAudience = dynamicText(\n"
    "  'website_audience',\n"
    "  '{owner}\\'s website supports visitors in {region}',\n"
    "  {\n"
    "    'owner': ParamKind.literal,\n"
    "    'region': const Param(\n"
    "      'region',\n"
    "      kind: ParamKind.translatable,\n"
    "      context: 'website visitor region',\n"
    "    ),\n"
    "  },\n"
    ");";

const _launchDateCode =
    "final launchDate = dynamicText(\n"
    "  'launch_date',\n"
    "  'Launch by {date}',\n"
    "  {'date': ParamKind.date},\n"
    ");";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeData = await _loadLocaleData();

  final renderer = Renderer(
    localeData: localeData,
    apiKey: _openRouterApiKey.isEmpty ? null : _openRouterApiKey,
  );
  runApp(MyApp(renderer: renderer, localeData: localeData));
}

Future<Map<String, Map<String, dynamic>>> _loadLocaleData() async {
  final localeData = <String, Map<String, dynamic>>{};
  for (final locale in _demoLocales) {
    if (locale.code == 'en') continue;
    final raw = await rootBundle.loadString('locales/${locale.code}.json');
    localeData[locale.code] = jsonDecode(raw) as Map<String, dynamic>;
  }
  return localeData;
}

class _DemoLocale {
  const _DemoLocale(this.code, this.label, this.languageName);

  final String code;
  final String label;
  final String languageName;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.renderer, required this.localeData});

  final Renderer renderer;
  final Map<String, Map<String, dynamic>> localeData;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _locale = 'en';
  String _language = 'English';
  String _audience = 'South Asia';
  late final TextEditingController _audienceController;
  Timer? _audienceDebounce;

  static const _pluralExamples = <int>[1, 2, 5];

  @override
  void initState() {
    super.initState();
    _audienceController = TextEditingController(text: _audience);
  }

  @override
  void dispose() {
    _audienceDebounce?.cancel();
    _audienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.openSansTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.openSansTextTheme(
          baseTheme.primaryTextTheme,
        ),
      ),
      home: StringLocaleScope(
        localeCode: _locale,
        languageName: _language,
        renderer: widget.renderer,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('stringlocale demo'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroPanel(locale: _locale, language: _language),
                        const SizedBox(height: 24),
                        _DocSection(
                          title: 'Choose a Locale',
                          description:
                              'Pick a country or language and the same website copy below rerenders with that locale.',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _demoLocales
                                .map(
                                  (locale) => _localeButton(
                                    context,
                                    locale.code,
                                    locale.label,
                                    locale.languageName,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: '1. Start With Static UI Copy',
                          description:
                              'Static strings are the simplest case: define the key once, compile locales, and render it.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CodeExample(
                                title: 'Definition',
                                code: _welcomeCode,
                              ),
                              const SizedBox(height: 16),
                              _ExampleRow(
                                'welcome',
                                Tr(welcome),
                                compiledTemplate: _compiledTemplate(welcome),
                              ),
                              _ExampleRow(
                                'sign_in',
                                Tr(signIn),
                                compiledTemplate: _compiledTemplate(signIn),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: '2. Make Text Dynamic',
                          description:
                              'Dynamic text keeps the sentence translatable while typed params handle website values like names, prices, and status labels.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CodeExample(
                                title: 'Website price definition',
                                code: _websitePlanPriceCode,
                              ),
                              const SizedBox(height: 16),
                              _ExampleRow(
                                "args: {'owner': '$_siteOwnerName', 'amount': 2500}",
                                Tr(
                                  websitePlanPrice,
                                  args: {
                                    'owner': _siteOwnerName,
                                    'amount': 2500,
                                  },
                                ),
                                compiledTemplate: _compiledTemplate(
                                  websitePlanPrice,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _CodeExample(
                                title: 'Status definition',
                                code: _websiteStatusCode,
                              ),
                              const SizedBox(height: 16),
                              _ExampleRow(
                                "args: {'status': '${_statusByLocale[_locale] ?? _statusByLocale['en']!}'}",
                                Tr(
                                  websiteStatus,
                                  args: {'status': _statusForLocale(_locale)},
                                ),
                                compiledTemplate: _compiledTemplate(
                                  websiteStatus,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: '3. Let One Param Drive Plurals',
                          description:
                              'Here pages chooses singular or plural for Jane\'s website. Owner and amount are still regular dynamic params.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CodeExample(
                                title: 'Developer definition',
                                code: _localizedPageCountCode,
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: _pluralExamples
                                    .map(
                                      (count) => _ExampleRow(
                                        "args: {'pages': $count, 'owner': '$_siteOwnerName', 'amount': 2500}",
                                        Tr(
                                          localizedPageCount,
                                          args: {
                                            'owner': _siteOwnerName,
                                            'pages': count,
                                            'amount': 2500,
                                          },
                                        ),
                                        compiledTemplate: _compiledTemplate(
                                          localizedPageCount,
                                          pluralCount: count,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: '4. Translate User Entered Content',
                          description:
                              'Type a visitor region or audience segment. The sentence stays localized, and the entered value is translated at runtime for the selected locale.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CodeExample(
                                title: 'Runtime translation definition',
                                code: _websiteAudienceCode,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _audienceController,
                                decoration: const InputDecoration(
                                  labelText: 'Visitor region',
                                  hintText: 'South Asia',
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.done,
                                onChanged: _onAudienceChanged,
                              ),
                              const SizedBox(height: 16),
                              _ExampleRow(
                                "args: {'owner': '$_siteOwnerName', 'region': '$_audience'}",
                                _RealtimeAudiencePreview(
                                  owner: _siteOwnerName,
                                  audience: _audience,
                                  localeCode: _locale,
                                ),
                                compiledTemplate: _compiledTemplate(
                                  websiteAudience,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: '5. Finish With a Date',
                          description:
                              'The same dynamic pattern also covers dates and other formatted values.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CodeExample(
                                title: 'Date definition',
                                code: _launchDateCode,
                              ),
                              const SizedBox(height: 16),
                              _ExampleRow(
                                "args: {'date': '2025-02-15'}",
                                Tr(launchDate, args: {'date': '2025-02-15'}),
                                compiledTemplate: _compiledTemplate(launchDate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DocSection(
                          title: 'How This Is Useful',
                          description:
                              'Use this pattern when one screen has fixed copy, user values, counts, money, dates, and locale-specific formatting.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _BulletLine(
                                'Keep website copy in Dart and compile it into locale JSON before shipping.',
                              ),
                              const _BulletLine(
                                'Pass dynamic values without giving up translated sentence structure.',
                              ),
                              const _BulletLine(
                                'Use one count value to pick singular or plural while other params keep working normally.',
                              ),
                              const _BulletLine(
                                'Format currency, dates, and digits for the active country automatically.',
                              ),
                              _BulletLine(
                                'Leave names and brand values such as $_siteOwnerName untouched across countries.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _localeButton(
    BuildContext context,
    String code,
    String label,
    String languageName,
  ) {
    final selected = _locale == code;
    return ChoiceChip(
      avatar: selected ? const Icon(Icons.check, size: 16) : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _locale = code;
          _language = languageName;
        });
      },
    );
  }

  String _statusForLocale(String localeCode) {
    return _statusByLocale[localeCode] ?? _statusByLocale['en']!;
  }

  String _compiledTemplate(Message text, {int? pluralCount}) {
    if (_locale == 'en') return _sourceTemplate(text, pluralCount: pluralCount);
    final entry = widget.localeData[_locale]?[text.key];
    if (entry is! Map<String, dynamic>) {
      return _sourceTemplate(text, pluralCount: pluralCount);
    }
    if (text.isPlural) {
      final useSingular = (pluralCount ?? 1) == 1;
      return (entry[useSingular ? 'singular' : 'plural'] as String?) ??
          _sourceTemplate(text, pluralCount: pluralCount);
    }
    return (entry['text'] as String?) ?? _sourceTemplate(text);
  }

  String _sourceTemplate(Message text, {int? pluralCount}) {
    if (!text.isPlural) return text.source;
    final parts = text.source.split(pluralSep);
    return (pluralCount ?? 1) == 1 ? parts.first : parts.last;
  }

  void _onAudienceChanged(String value) {
    _audienceDebounce?.cancel();
    _audienceDebounce = Timer(const Duration(milliseconds: 650), () {
      final nextAudience = value.trim().isEmpty ? 'South Asia' : value.trim();
      if (!mounted || nextAudience == _audience) return;
      setState(() => _audience = nextAudience);
    });
  }
}

class _RealtimeAudiencePreview extends StatefulWidget {
  const _RealtimeAudiencePreview({
    required this.owner,
    required this.audience,
    required this.localeCode,
  });

  final String owner;
  final String audience;
  final String localeCode;

  @override
  State<_RealtimeAudiencePreview> createState() =>
      _RealtimeAudiencePreviewState();
}

class _RealtimeAudiencePreviewState extends State<_RealtimeAudiencePreview> {
  String? _value;
  Object? _error;
  var _loading = false;
  var _renderKey = '';

  String get _fallback =>
      "${widget.owner}'s website supports visitors in ${widget.audience}";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _render();
  }

  @override
  void didUpdateWidget(_RealtimeAudiencePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _render();
  }

  Future<void> _render() async {
    final key = '${widget.localeCode}::${widget.owner}::${widget.audience}';
    if (key == _renderKey) return;
    _renderKey = key;

    if (widget.localeCode == 'en') {
      setState(() {
        _value = _fallback;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await trAsync(
        context,
        websiteAudience,
        args: {'owner': widget.owner, 'region': widget.audience},
      );
      if (!mounted || key != _renderKey) return;
      setState(() {
        _value = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || key != _renderKey) return;
      setState(() {
        _value = _fallback;
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _error != null
        ? colorScheme.error
        : _loading
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final statusText = widget.localeCode == 'en'
        ? 'English selected: value is passed through'
        : _loading
        ? 'Translating runtime value...'
        : _error != null
        ? 'Runtime translation unavailable'
        : 'Runtime translated value';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_value ?? _fallback),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _runtimeErrorMessage(_error!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _runtimeErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('OPENROUTER_API_KEY')) {
      return 'Run a full restart with: flutter run -d macos --dart-define=OPENROUTER_API_KEY=your_key';
    }
    if (message.contains('SocketException') ||
        message.contains('Operation not permitted') ||
        message.contains('Connection failed')) {
      return 'Network request failed. On macOS, rebuild after enabling outbound network access, then run with --dart-define.';
    }
    if (message.contains('OpenRouter API error')) {
      return message;
    }
    return 'Runtime error: $message';
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.locale, required this.language});

  final String locale;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Current locale: $language ($locale)',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Jane Doe Goes Global',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'Jane Doe needs her website to feel local for visitors in different countries. The same Dart definitions render the page in every locale.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocSection extends StatelessWidget {
  const _DocSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow(this.label, this.child, {this.compiledTemplate});

  final String label;
  final Widget child;
  final String? compiledTemplate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final labelWidget = SelectableText(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          );
          final outputWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                child: child,
              ),
              if (compiledTemplate != null) ...[
                const SizedBox(height: 10),
                SelectableText(
                  'compiled template: $compiledTemplate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 8), outputWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 260, child: labelWidget),
              const SizedBox(width: 18),
              Expanded(child: outputWidget),
            ],
          );
        },
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: Theme.of(context).textTheme.bodyLarge),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _CodeExample extends StatelessWidget {
  const _CodeExample({required this.title, required this.code});

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: SelectableText(
            code,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
