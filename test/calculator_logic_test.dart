import 'package:flutter_test/flutter_test.dart';
import 'package:neocalc/calculator_logic.dart';

void main() {
  group('evaluateExpression', () {
    test('respects multiplication precedence', () {
      expect(evaluateExpression('450+500+1000'), 1950);
      expect(evaluateExpression('2+3*4'), 14);
    });

    test('handles decimals, unary signs, and parentheses', () {
      expect(evaluateExpression('-(1.5+2.5)*2'), -8);
    });

    test('rejects division by zero', () {
      expect(() => evaluateExpression('8/0'), throwsArgumentError);
    });
  });

  test('converts Celsius to Fahrenheit', () {
    expect(convertValue(29, 'Temperature', 'Celsius', 'Fahrenheit'), closeTo(84.2, .0001));
  });

  test('formats results without trailing zeros', () {
    expect(formatNumber(1950), '1950');
    expect(formatNumber(84.2), '84.2');
  });
}