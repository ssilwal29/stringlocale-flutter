import 'text.dart' as tx;
import 'text.dart' show Message;

/// Collects [Message] definitions for compile-time processing, with
/// duplicate-key detection.
class Registry {
  /// Create an empty message registry.
  Registry();

  final Map<String, Message> _texts = {};

  /// Register a batch of [texts], throwing if any key was already registered.
  void register(List<Message> texts) {
    for (final text in texts) {
      if (_texts.containsKey(text.key)) {
        throw ArgumentError('Duplicate key "${text.key}" — already registered');
      }
      _texts[text.key] = text;
    }
  }

  /// Define and register a static message.
  Message staticText(String key, String source) {
    final text = tx.staticText(key, source);
    register([text]);
    return text;
  }

  /// Define and register a dynamic message with typed parameters.
  Message dynamicText(
      String key, String source, Map<String, Object> paramDefs) {
    final text = tx.dynamicText(key, source, paramDefs);
    register([text]);
    return text;
  }

  /// Backward-compatible alias for [dynamicText].
  Message message(String key, String source, Map<String, Object> paramDefs) =>
      dynamicText(key, source, paramDefs);

  /// Backward-compatible alias for [dynamicText].
  Message dynamic_(String key, String source, Map<String, Object> paramDefs) =>
      dynamicText(key, source, paramDefs);

  /// Define and register a plural-aware message.
  Message pluralText(
    String key,
    String singular,
    String pluralForm, {
    String countParam = 'count',
    Map<String, Object> params = const {},
  }) {
    final text = tx.pluralText(
      key,
      singular,
      pluralForm,
      countParam: countParam,
      params: params,
    );
    register([text]);
    return text;
  }

  /// Backward-compatible alias for [pluralText].
  Message plural(
    String key,
    String singular,
    String pluralForm, {
    String countParam = 'count',
    Map<String, Object> params = const {},
  }) =>
      pluralText(
        key,
        singular,
        pluralForm,
        countParam: countParam,
        params: params,
      );

  /// Registered messages in insertion order.
  List<Message> get texts => _texts.values.toList();

  /// Number of registered messages.
  int get length => _texts.length;

  @override
  String toString() => 'Registry(${_texts.length} texts)';
}
