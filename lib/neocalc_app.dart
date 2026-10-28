import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculator_logic.dart';

const _background = Color(0xFF3A3F4B);
const _surface = Color(0xFF1B1F2B);
const _panel = Color(0xFF262B3A);
const _key = Color(0xFF2E3445);
const _keyTop = Color(0xFF3A4155);
const _border = Color(0xFF4A5268);
const _gold = Color(0xFFE8A33D);
const _goldSoft = Color(0xFF8A6A35);
const _text = Color(0xFFE6E8EE);
const _muted = Color(0xFF8E95A8);

enum _Page { calculator, converter, history }

class NeoCalcApp extends StatelessWidget {
  const NeoCalcApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NeoCalc',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _surface,
          colorScheme: const ColorScheme.dark(primary: _gold, surface: _surface, onSurface: _text),
          useMaterial3: true,
        ),
        home: const CalculatorHome(),
      );
}

class _HistoryEntry {
  const _HistoryEntry(this.expression, this.result, this.timestamp);

  final String expression;
  final String result;
  final int timestamp;

  Map<String, Object> toJson() => {
        'expression': expression,
        'result': result,
        'timestamp': timestamp,
      };

  factory _HistoryEntry.fromJson(Map<String, dynamic> json) => _HistoryEntry(
        json['expression'] as String,
        json['result'] as String,
        json['timestamp'] as int,
      );
}

class CalculatorHome extends StatefulWidget {
  const CalculatorHome({super.key});

  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> {
  static const _historyKey = 'neocalc.history.v1';
  final _historyController = ScrollController();
  final List<_HistoryEntry> _history = [];

  _Page _page = _Page.calculator;
  String _expression = '';
  String _result = '0';
  bool _isFinal = false;
  bool _hasError = false;
  String _category = 'Temperature';
  String _input = '29';
  String _from = 'Celsius';
  String _to = 'Fahrenheit';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_historyKey);
    if (raw == null || !mounted) return;
    try {
      final entries = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_HistoryEntry.fromJson)
          .take(100);
      setState(() => _history.addAll(entries));
    } on FormatException {
      await preferences.remove(_historyKey);
    } on TypeError {
      await preferences.remove(_historyKey);
    }
  }

  Future<void> _persistHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyKey,
      jsonEncode(_history.map((entry) => entry.toJson()).toList()),
    );
  }

  void _addHistory(String expression, String result) {
    _history.insert(
      0,
      _HistoryEntry(expression, result, DateTime.now().millisecondsSinceEpoch),
    );
    if (_history.length > 100) _history.removeLast();
    _persistHistory();
  }

  void _press(String key) {
    if (_page == _Page.converter) {
      _pressConverter(key);
      return;
    }
    if (_page != _Page.calculator) return;
    setState(() {
      _hasError = false;
      if (key == 'C') {
        _expression = '';
        _result = '0';
        _isFinal = false;
      } else if (key == '⌫') {
        if (_isFinal) {
          _expression = '';
          _result = '0';
        } else if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _preview();
        }
        _isFinal = false;
      } else if (key == '±') {
        _toggleSign();
        _preview();
        _isFinal = false;
      } else if (key == '=') {
        _calculate();
      } else if (key == '.') {
        if (_isFinal) {
          _expression = '';
          _result = '0';
          _isFinal = false;
        }
        final currentNumber = _expression.split(RegExp(r'[+\-*/]')).last;
        if (!currentNumber.contains('.')) {
          _expression += currentNumber.isEmpty ? '0.' : '.';
          _preview();
        }
      } else if ('÷×−+'.contains(key)) {
        if (_isFinal) {
          _expression = _result == 'Error' ? '' : _result;
          _isFinal = false;
        }
        final operator = switch (key) {'÷' => '/', '×' => '*', '−' => '-', _ => '+'};
        if (_expression.isEmpty && operator != '-') return;
        if (_expression.isNotEmpty && '+-*/'.contains(_expression[_expression.length - 1])) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _expression += operator;
        _preview();
      } else {
        if (_isFinal) {
          _expression = '';
          _result = '0';
          _isFinal = false;
        }
        _expression += key;
        _preview();
      }
    });
  }

  void _toggleSign() {
    final match = RegExp(r'(-?\d*\.?\d+)$').firstMatch(_expression);
    if (match == null) return;
    final number = match.group(0)!;
    final replacement = number.startsWith('-') ? number.substring(1) : '-$number';
    _expression = _expression.replaceRange(match.start, match.end, replacement);
  }

  void _preview() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    try {
      _result = formatNumber(evaluateExpression(_expression));
    } on FormatException {
      _result = '0';
    } on ArgumentError {
      _result = 'Error';
    }
  }

  void _calculate() {
    if (_expression.isEmpty) return;
    try {
      _result = formatNumber(evaluateExpression(_expression));
      _isFinal = true;
      _addHistory(_expression, _result);
    } on FormatException {
      _result = 'Error';
      _hasError = true;
      _isFinal = true;
    } on ArgumentError {
      _result = 'Error';
      _hasError = true;
      _isFinal = true;
    }
  }

  void _pressConverter(String key) {
    if ('÷×−+'.contains(key) || key == '=') {
      if (key == '=') {
        final value = convertValue(double.tryParse(_input) ?? 0, _category, _from, _to);
        setState(() => _addHistory('$_input $_from', '${formatNumber(value)} $_to'));
      }
      return;
    }
    setState(() {
      if (key == 'C') {
        _input = '0';
      } else if (key == '⌫') {
        _input = _input.length > 1 ? _input.substring(0, _input.length - 1) : '0';
      } else if (key == '±') {
        _input = formatNumber(-(double.tryParse(_input) ?? 0));
      } else if (key == '.') {
        if (!_input.contains('.')) _input += '.';
      } else {
        _input = _input == '0' ? key : '$_input$key';
      }
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      final units = unitsForCategory(category);
      _from = units.first;
      _to = units[1];
    });
  }

  void _loadEntry(_HistoryEntry entry) => setState(() {
        _page = _Page.calculator;
        _expression = entry.expression;
        _result = entry.result;
        _isFinal = true;
        _hasError = false;
      });

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Clear history?'),
        content: const Text('This removes all saved calculations and conversions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(_history.clear);
    _persistHistory();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _page == _Page.calculator,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _page != _Page.calculator) setState(() => _page = _Page.calculator);
        },
        child: Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.15,
                      colors: [Color(0xFF292C38), _surface],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: switch (_page) {
                      _Page.calculator => _calculatorPage(),
                      _Page.converter => _converterPage(),
                      _Page.history => _historyPage(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _calculatorPage() => Column(
        children: [
          _TopBar(onSelect: (page) => setState(() => _page = page)),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: _DisplayCard(
              expression: _expression,
              result: _result,
              error: _hasError,
              onHistory: () => setState(() => _page = _Page.history),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(flex: 6, child: _Keypad(onPressed: _press)),
        ],
      );

  Widget _converterPage() {
    final result = convertValue(double.tryParse(_input) ?? 0, _category, _from, _to);
    return Column(
      children: [
        _TopBar(
          title: 'Unit Converter',
          showBack: true,
          onBack: () => setState(() => _page = _Page.calculator),
          onSelect: (page) => setState(() => _page = page),
        ),
        const SizedBox(height: 10),
        _CategoryTabs(selected: _category, onSelected: _selectCategory),
        const SizedBox(height: 16),
        _UnitField(
          value: _input,
          units: unitsForCategory(_category),
          selected: _from,
          onChanged: (unit) => setState(() => _from = unit),
        ),
        const SizedBox(height: 10),
        _UnitField(
          value: formatNumber(result),
          units: unitsForCategory(_category),
          selected: _to,
          readOnly: true,
          onChanged: (unit) => setState(() => _to = unit),
        ),
        const SizedBox(height: 18),
        Expanded(flex: 6, child: _Keypad(onPressed: _press, converter: true)),
      ],
    );
  }

  Widget _historyPage() => Column(
        children: [
          _TopBar(
            title: 'History',
            showBack: true,
            onBack: () => setState(() => _page = _Page.calculator),
            onSelect: (page) => setState(() => _page = page),
          ),
          Expanded(
            child: _history.isEmpty
                ? const Center(child: Text('No calculations yet', style: TextStyle(color: _muted)))
                : ListView.separated(
                    controller: _historyController,
                    padding: const EdgeInsets.only(top: 14, bottom: 10),
                    itemCount: _history.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 24,
                      color: Color(0x334A5268),
                    ),
                    itemBuilder: (context, index) => _HistoryRow(
                      entry: _history[index],
                      onTap: () => _loadEntry(_history[index]),
                    ),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Scroll to newest',
                onPressed: () => _historyController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                ),
                icon: const Icon(Icons.arrow_upward_rounded, color: _muted),
              ),
              IconButton(
                tooltip: 'Clear history',
                onPressed: _history.isEmpty ? null : _clearHistory,
                icon: const Icon(Icons.delete_outline_rounded, color: _gold),
              ),
            ],
          ),
        ],
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSelect, this.title, this.showBack = false, this.onBack});

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final ValueChanged<_Page> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Align(
              alignment: Alignment.centerLeft,
              child: showBack
                  ? IconButton(
                      tooltip: 'Back to calculator',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : const SizedBox(width: 48),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<_Page>(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu_rounded, color: _muted),
                color: _panel,
                onSelected: onSelect,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _Page.calculator, child: Text('Calculator')),
                  PopupMenuItem(value: _Page.converter, child: Text('Unit Converter')),
                  PopupMenuItem(value: _Page.history, child: Text('History')),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DisplayCard extends StatelessWidget {
  const _DisplayCard({
    required this.expression,
    required this.result,
    required this.error,
    required this.onHistory,
  });

  final String expression;
  final String result;
  final bool error;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_goldSoft, _panel, _panel],
            stops: [0, .08, .45],
          ),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      expression.isEmpty ? ' ' : _pretty(expression),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        color: _text,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('=', style: TextStyle(fontSize: 14, color: _muted.withValues(alpha: .8))),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      result,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w300,
                        color: error ? const Color(0xFFFF7B75) : _gold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('history →', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      );
}

String _pretty(String expression) => expression
    .replaceAll('*', ' × ')
    .replaceAll('/', ' ÷ ')
    .replaceAll('-', ' − ')
    .replaceAll('+', ' + ')
    .trim();

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPressed, this.converter = false});

  final ValueChanged<String> onPressed;
  final bool converter;
  static const _rows = [
    ['C', '±', '⌫', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['0', '.', '='],
  ];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var row = 0; row < _rows.length; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < _rows[row].length; column++) ...[
                    if (column > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: row == 4 && column == 0 ? 2 : 1,
                      child: _CalcKey(
                        label: _rows[row][column],
                        disabled: converter &&
                            ('÷×−+'.contains(_rows[row][column]) || _rows[row][column] == '='),
                        onPressed: onPressed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
}

class _CalcKey extends StatefulWidget {
  const _CalcKey({required this.label, required this.onPressed, this.disabled = false});

  final String label;
  final ValueChanged<String> onPressed;
  final bool disabled;

  @override
  State<_CalcKey> createState() => _CalcKeyState();
}

class _CalcKeyState extends State<_CalcKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final equals = widget.label == '=';
    final operator = '÷×−+'.contains(widget.label);
    final action = const {'C', '±', '⌫'}.contains(widget.label);
    final foreground = widget.disabled
        ? _muted.withValues(alpha: .4)
        : equals
            ? _surface
            : operator
                ? _gold
                : action
                    ? _muted
                    : _text;
    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: switch (widget.label) {
        '÷' => 'divide',
        '×' => 'multiply',
        '−' => 'subtract',
        '+' => 'plus',
        '⌫' => 'backspace',
        '±' => 'change sign',
        '=' => 'equals',
        '.' => 'decimal point',
        'C' => 'clear',
        _ => widget.label,
      },
      child: GestureDetector(
        onTapDown: widget.disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.disabled
            ? null
            : (_) {
                setState(() => _pressed = false);
                widget.onPressed(widget.label);
              },
        child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: equals && !widget.disabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_gold, Color(0xFFC67C23)],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.disabled ? _panel : (_pressed ? const Color(0xFF49434A) : _keyTop),
                        widget.disabled ? _surface : _key,
                      ],
                    ),
              border: Border.all(color: _pressed ? _gold.withValues(alpha: .6) : _border),
              boxShadow: equals
                  ? const [BoxShadow(color: Color(0x558A6A35), blurRadius: 16, offset: Offset(0, 5))]
                  : const [BoxShadow(color: Color(0x1C000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.label.length > 1 ? 19 : 23,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;
  static const _categories = ['Temperature', 'Volume', 'Currency', 'Area'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: () => onSelected(category),
                  style: TextButton.styleFrom(
                    foregroundColor: selected == category ? _gold : _muted,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    minimumSize: const Size(52, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: selected == category ? const Color(0x1FE8A33D) : Colors.transparent,
                  ),
                  child: Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        ),
      );
}

class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.value,
    required this.units,
    required this.selected,
    required this.onChanged,
    this.readOnly = false,
  });

  final String value;
  final List<String> units;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border.withValues(alpha: .7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: readOnly ? _gold : _text,
                  fontSize: 24,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                dropdownColor: _panel,
                icon: const Icon(Icons.expand_more_rounded, color: _muted),
                style: const TextStyle(color: _text, fontSize: 13),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unit, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: readOnly ? null : (unit) => onChanged(unit!),
              ),
            ),
          ],
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.onTap});

  final _HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${entry.expression} equals ${entry.result}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _pretty(entry.expression),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, color: _text),
                ),
                const Text('=', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: _muted)),
                Text(
                  entry.result,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, color: _gold),
                ),
              ],
            ),
          ),
        ),
      );
}