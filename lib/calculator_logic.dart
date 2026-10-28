double evaluateExpression(String expression) {
  final parser = _ExpressionParser(_tokenize(expression));
  final value = parser.parseExpression();
  if (!parser.isAtEnd) throw const FormatException('Unexpected token');
  if (!value.isFinite) throw ArgumentError('Result is not finite');
  return value;
}

String formatNumber(double value) {
  if (!value.isFinite) return 'Error';
  if (value == 0) return '0';
  final formatted = double.parse(value.toStringAsPrecision(10)).toString();
  return formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
}

List<String> unitsForCategory(String category) => switch (category) {
      'Temperature' => const ['Celsius', 'Fahrenheit', 'Kelvin'],
      'Volume' => const ['Liter', 'Milliliter', 'Gallon (US)', 'Cup (US)'],
      'Currency' => const ['USD', 'EUR', 'GBP', 'JPY', 'PHP'],
      'Area' => const ['m²', 'km²', 'ft²', 'acre', 'hectare'],
      _ => const ['Celsius', 'Fahrenheit', 'Kelvin'],
    };

double convertValue(double value, String category, String from, String to) {
  if (from == to) return value;
  if (category == 'Temperature') {
    final celsius = switch (from) {
      'Fahrenheit' => (value - 32) * 5 / 9,
      'Kelvin' => value - 273.15,
      _ => value,
    };
    return switch (to) {
      'Fahrenheit' => celsius * 9 / 5 + 32,
      'Kelvin' => celsius + 273.15,
      _ => celsius,
    };
  }
  if (category == 'Currency') {
    // Fixed offline rates: units of currency per 1 USD.
    const usdRates = {'USD': 1.0, 'EUR': .92, 'GBP': .79, 'JPY': 150.0, 'PHP': 56.0};
    return value / usdRates[from]! * usdRates[to]!;
  }

  final factors = switch (category) {
    'Volume' => const {
        'Liter': 1.0,
        'Milliliter': .001,
        'Gallon (US)': 3.785411784,
        'Cup (US)': .2365882365,
      },
    'Area' => const {
        'm²': 1.0,
        'km²': 1000000.0,
        'ft²': .09290304,
        'acre': 4046.8564224,
        'hectare': 10000.0,
      },
    _ => const <String, double>{},
  };
  return value * factors[from]! / factors[to]!;
}

List<String> _tokenize(String expression) {
  final tokens = <String>[];
  final pattern = RegExp(r'\d+(?:\.\d*)?|\.\d+|[+\-*/()]');
  var cursor = 0;
  for (final match in pattern.allMatches(expression)) {
    if (expression.substring(cursor, match.start).trim().isNotEmpty) {
      throw const FormatException('Invalid character');
    }
    tokens.add(match.group(0)!);
    cursor = match.end;
  }
  if (expression.substring(cursor).trim().isNotEmpty || tokens.isEmpty) {
    throw const FormatException('Invalid expression');
  }
  return tokens;
}

class _ExpressionParser {
  _ExpressionParser(this.tokens);

  final List<String> tokens;
  var _position = 0;

  bool get isAtEnd => _position == tokens.length;
  String? get _current => isAtEnd ? null : tokens[_position];

  double parseExpression() {
    var value = _parseTerm();
    while (_current == '+' || _current == '-') {
      final operator = tokens[_position++];
      final right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (_current == '*' || _current == '/') {
      final operator = tokens[_position++];
      final right = _parseUnary();
      if (operator == '/' && right == 0) throw ArgumentError('Division by zero');
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  double _parseUnary() {
    if (_current == '+') {
      _position++;
      return _parseUnary();
    }
    if (_current == '-') {
      _position++;
      return -_parseUnary();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    final token = _current;
    if (token == null) throw const FormatException('Expected a number');
    if (token == '(') {
      _position++;
      final value = parseExpression();
      if (_current != ')') throw const FormatException('Missing closing parenthesis');
      _position++;
      return value;
    }
    if (token == ')') throw const FormatException('Unexpected closing parenthesis');
    _position++;
    final number = double.tryParse(token);
    if (number == null) throw const FormatException('Expected a number');
    return number;
  }
}