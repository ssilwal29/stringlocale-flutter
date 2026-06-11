/// A tiny, safe expression evaluator for LLM-generated plural rules.
///
/// Dart has no `eval`, so rules like `count % 10 == 1 && count % 100 != 11`
/// are parsed and evaluated by this minimal recursive-descent evaluator.
/// Only the single count variable, integer literals, and a fixed set of
/// operators are permitted — anything else throws.
///
/// Supported operators (JS/Python-ish, both accepted):
///   ||  &&  !          (or / and / not)
///   ==  !=  <  >  <=  >=
///   +  -  *  /  %
///   parentheses
library;

/// Evaluates the restricted plural-rule expressions generated at compile time.
class PluralRuleEvaluator {
  /// Create an evaluator that permits [countParam] as the only count variable.
  PluralRuleEvaluator(this.countParam);

  /// Variable name used in plural expressions, such as `count` or `pages`.
  final String countParam;

  /// Evaluate [rule] with the given [count]. Returns true when the SINGULAR
  /// form should be used. Falls back to `count < 2` on any error.
  bool eval(String rule, num count) {
    try {
      final tokens = _tokenize(rule);
      final parser = _Parser(tokens, countParam, count);
      final result = parser.parseExpression();
      if (!parser.atEnd) {
        throw FormatException('Unexpected trailing tokens in rule: $rule');
      }
      return _truthy(result);
    } catch (_) {
      return count < 2;
    }
  }

  /// Validate a rule at compile time. Throws [FormatException] if the rule
  /// uses disallowed identifiers or fails to parse / evaluate.
  void validate(String rule) {
    final tokens = _tokenize(rule);
    for (final tok in tokens) {
      if (tok.type == _TokType.ident &&
          tok.text != countParam &&
          tok.text != 'true' &&
          tok.text != 'false') {
        throw FormatException(
          'Plural rule references disallowed identifier "${tok.text}": $rule',
        );
      }
    }
    // Test it evaluates for a sample value.
    final parser = _Parser(tokens, countParam, 1);
    parser.parseExpression();
    if (!parser.atEnd) {
      throw FormatException('Invalid plural rule (trailing tokens): $rule');
    }
  }

  static bool _truthy(Object v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  List<_Token> _tokenize(String src) {
    final tokens = <_Token>[];
    var i = 0;
    while (i < src.length) {
      final c = src[i];
      if (c == ' ' || c == '\t' || c == '\n') {
        i++;
        continue;
      }
      // Multi-char operators
      if (i + 1 < src.length) {
        final two = src.substring(i, i + 2);
        if (two == '==' ||
            two == '!=' ||
            two == '<=' ||
            two == '>=' ||
            two == '&&' ||
            two == '||') {
          tokens.add(_Token(_TokType.op, two));
          i += 2;
          continue;
        }
      }
      if ('+-*/%<>!()'.contains(c)) {
        tokens.add(_Token(_TokType.op, c));
        i++;
        continue;
      }
      if (_isDigit(c)) {
        var j = i;
        while (j < src.length && _isDigit(src[j])) {
          j++;
        }
        tokens.add(_Token(_TokType.num, src.substring(i, j)));
        i = j;
        continue;
      }
      if (_isIdentStart(c)) {
        var j = i;
        while (j < src.length && _isIdentPart(src[j])) {
          j++;
        }
        tokens.add(_Token(_TokType.ident, src.substring(i, j)));
        i = j;
        continue;
      }
      throw FormatException('Unexpected character "$c" in rule: $src');
    }
    return tokens;
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
  static bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        c == '_';
  }

  static bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}

enum _TokType { num, ident, op }

class _Token {
  _Token(this.type, this.text);
  final _TokType type;
  final String text;
}

/// Recursive-descent parser with standard precedence:
/// or → and → equality → comparison → additive → multiplicative → unary → primary
class _Parser {
  _Parser(this.tokens, this.countParam, this.count);

  final List<_Token> tokens;
  final String countParam;
  final num count;
  int _pos = 0;

  bool get atEnd => _pos >= tokens.length;
  _Token? get _peek => atEnd ? null : tokens[_pos];

  _Token _next() => tokens[_pos++];

  bool _matchOp(String op) {
    final p = _peek;
    if (p != null && p.type == _TokType.op && p.text == op) {
      _pos++;
      return true;
    }
    return false;
  }

  Object parseExpression() => _parseOr();

  Object _parseOr() {
    var left = _parseAnd();
    while (_matchOp('||')) {
      final right = _parseAnd();
      left = PluralRuleEvaluator._truthy(left) ||
          PluralRuleEvaluator._truthy(right);
    }
    return left;
  }

  Object _parseAnd() {
    var left = _parseEquality();
    while (_matchOp('&&')) {
      final right = _parseEquality();
      left = PluralRuleEvaluator._truthy(left) &&
          PluralRuleEvaluator._truthy(right);
    }
    return left;
  }

  Object _parseEquality() {
    var left = _parseComparison();
    while (true) {
      if (_matchOp('==')) {
        final right = _parseComparison();
        left = _asNum(left) == _asNum(right);
      } else if (_matchOp('!=')) {
        final right = _parseComparison();
        left = _asNum(left) != _asNum(right);
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseComparison() {
    var left = _parseAdditive();
    while (true) {
      if (_matchOp('<=')) {
        left = _asNum(left) <= _asNum(_parseAdditive());
      } else if (_matchOp('>=')) {
        left = _asNum(left) >= _asNum(_parseAdditive());
      } else if (_matchOp('<')) {
        left = _asNum(left) < _asNum(_parseAdditive());
      } else if (_matchOp('>')) {
        left = _asNum(left) > _asNum(_parseAdditive());
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseAdditive() {
    var left = _parseMultiplicative();
    while (true) {
      if (_matchOp('+')) {
        left = _asNum(left) + _asNum(_parseMultiplicative());
      } else if (_matchOp('-')) {
        left = _asNum(left) - _asNum(_parseMultiplicative());
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseMultiplicative() {
    var left = _parseUnary();
    while (true) {
      if (_matchOp('*')) {
        left = _asNum(left) * _asNum(_parseUnary());
      } else if (_matchOp('/')) {
        left = _asNum(left) / _asNum(_parseUnary());
      } else if (_matchOp('%')) {
        left = _asNum(left) % _asNum(_parseUnary());
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseUnary() {
    if (_matchOp('!')) {
      return !PluralRuleEvaluator._truthy(_parseUnary());
    }
    if (_matchOp('-')) {
      return -_asNum(_parseUnary());
    }
    return _parsePrimary();
  }

  Object _parsePrimary() {
    if (_matchOp('(')) {
      final e = parseExpression();
      if (!_matchOp(')')) {
        throw const FormatException('Expected closing parenthesis');
      }
      return e;
    }
    final tok = _next();
    switch (tok.type) {
      case _TokType.num:
        return num.parse(tok.text);
      case _TokType.ident:
        if (tok.text == countParam) return count;
        // Allow JS/Python-ish keyword fallbacks
        if (tok.text == 'true') return true;
        if (tok.text == 'false') return false;
        throw FormatException('Disallowed identifier "${tok.text}"');
      case _TokType.op:
        throw FormatException('Unexpected operator "${tok.text}"');
    }
  }

  num _asNum(Object v) {
    if (v is num) return v;
    if (v is bool) return v ? 1 : 0;
    throw const FormatException('Expected a number');
  }
}
