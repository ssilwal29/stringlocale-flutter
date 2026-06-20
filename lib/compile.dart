/// stringlocale build-time API (compiler, check, prune, LLM drafters).
/// Import this only in build scripts — not in app/runtime code.
library;

export 'src/compile/compiler.dart'
    show compileAll, compileStrings, CompileResult, parseLocaleArg, slHash;
export 'src/compile/check.dart' show check, prune, Report, PruneResult;
export 'src/compile/llm.dart'
    show
        Drafter,
        OfflineDrafter,
        LlmDrafter,
        OpenRouterDrafter,
        defaultModel,
        defaultBaseUrl;
