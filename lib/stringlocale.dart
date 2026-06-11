/// stringlocale — compile-time LLM localization for Dart.
///
/// This library is pure Dart with no Flutter dependency. For Flutter widget
/// integration ([StringLocaleScope], [Tr]), import
/// `package:stringlocale/stringlocale_flutter.dart` instead.
library;

export 'src/text.dart'
    show
        Message,
        Param,
        ParamKind,
        staticText,
        t,
        dynamicText,
        message,
        dynamic_,
        pluralText,
        plural,
        pluralSep,
        extractPlaceholders;
export 'src/registry.dart' show Registry;
export 'src/renderer.dart' show Renderer;
export 'src/compiler.dart' show compileLocales;
export 'src/formatters.dart'
    show
        formatNumber,
        formatDateValue,
        formatCurrencyValue,
        formatRelativeValue;
export 'src/plural_rule.dart' show PluralRuleEvaluator;
export 'src/llm.dart'
    show
        defaultModel,
        callOpenRouter,
        translateString,
        translatePlural,
        translateValue,
        adaptFreeText,
        PluralTranslation;
