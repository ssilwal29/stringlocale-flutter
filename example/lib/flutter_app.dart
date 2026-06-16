import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stringlocale/flutter.dart';

import 'flutter_strings.dart';

const sampleLocales = ['en-US', 'hi-IN', 'ne-NP', 'nl-NL', 'fr-FR', 'ru-RU'];
const _openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');
const _assetDir = 'assets/i18n';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bundle = await loadSampleBundle(
    userAdaptedMode: UserAdaptedMode.cached,
  );
  runApp(StringLocaleFlutterSample(bundle: bundle));
}

Future<Bundle> loadSampleBundle({
  Adapter? adapter,
  UserAdaptedMode userAdaptedMode = UserAdaptedMode.cached,
}) async {
  final manifest =
      jsonDecode(await rootBundle.loadString('$_assetDir/manifest.json'))
          as Map<String, dynamic>;
  final files = manifest['files'] as Map;

  Bundle? bundle;
  for (final locale in sampleLocales) {
    final entry = files[locale] as Map?;
    if (entry == null) continue;
    final data = jsonDecode(
      await rootBundle.loadString('$_assetDir/${entry['path']}'),
    ) as Map<String, dynamic>;
    if (bundle == null) {
      bundle = Bundle(
        data,
        adapter: adapter,
        userAdaptedMode: userAdaptedMode,
      );
    } else {
      bundle.merge(data);
    }
  }

  if (bundle == null) {
    throw StateError('No stringlocale sample bundles found in $_assetDir');
  }
  return bundle;
}

class StringLocaleFlutterSample extends StatefulWidget {
  const StringLocaleFlutterSample({super.key, required this.bundle});

  final Bundle bundle;

  @override
  State<StringLocaleFlutterSample> createState() =>
      _StringLocaleFlutterSampleState();
}

class _StringLocaleFlutterSampleState extends State<StringLocaleFlutterSample> {
  String _locale = 'en-US';
  late final TextEditingController _noteController;
  bool _adapting = false;
  String _adaptedPreview = '';
  Timer? _debounce;

  static const _debounceDelay = Duration(seconds: 3);
  static const _initialNote =
      'Preorder ships in 7 business days. Tracking updates nightly.';

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: _initialNote);
    _adaptedPreview = _initialNote;
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAdaptation());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _triggerAdaptation);
  }

  Future<void> _triggerAdaptation() async {
    if (!mounted) return;
    setState(() => _adapting = true);
    try {
      final text = await widget.bundle.resolveAsync(
        _locale,
        userAdaptedPreview.id,
        {'note': _noteController.text},
      );
      if (mounted) setState(() { _adaptedPreview = text; _adapting = false; });
    } catch (_) {
      if (mounted) setState(() => _adapting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StringLocaleScope(
        locale: _locale,
        bundle: widget.bundle,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Tr(appTitle),
              actions: [
                for (final locale in sampleLocales)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(locale),
                      selected: _locale == locale,
                      onSelected: _adapting ? null : (_) => _setLocale(context, locale),
                    ),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Tr(
                  audienceMessage,
                  args: const {
                    'name': 'Mira',
                    'tier': 'gold',
                    'audience': 'seller',
                  },
                  builder: (value) => Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tr(
                          orderSummary,
                          args: const {
                            'name': 'Mira',
                            'count': 12,
                            'status': 'approved',
                            'total': 2500,
                          },
                        ),
                        const SizedBox(height: 8),
                        Tr(
                          nextPayout,
                          args: const {
                            'date': '2026-07-15',
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'userAdapted demo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                _openRouterApiKey.isNotEmpty
                                    ? 'OpenRouter active'
                                    : 'No API key — offline',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: _openRouterApiKey.isNotEmpty
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              side: BorderSide(
                                color: _openRouterApiKey.isNotEmpty
                                    ? Colors.green.shade400
                                    : Colors.orange.shade400,
                              ),
                              avatar: Icon(
                                _openRouterApiKey.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                size: 16,
                                color: _openRouterApiKey.isNotEmpty
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 3,
                          onChanged: _onNoteChanged,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Type a user message',
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_adapting)
                          const Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Adapting…',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        else
                          Text(_adaptedPreview),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final message = tr(
                      context,
                      snackbarLabel,
                      args: {'locale': _locale},
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  child: const Text('Show translated snackbar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setLocale(BuildContext context, String locale) {
    setState(() => _locale = locale);
    StringLocaleScope.of(context).setLocale(locale);
    _debounce?.cancel();
    _triggerAdaptation();
  }
}
