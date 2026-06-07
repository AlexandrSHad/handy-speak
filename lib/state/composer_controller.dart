import 'package:flutter/foundation.dart';

enum InputMode { keyboard, symbols }

/// Holds the composed message and the active input mode (IMPLEMENTATION_PLAN
/// Task 3/4). The raw [text] string is the single source of truth; word tiles
/// and the in-progress caret are derived from it, mirroring the prototype's
/// `MessageBlocks` (§6.1.2).
class ComposerController extends ChangeNotifier {
  String _text = '';
  String get text => _text;

  InputMode _mode = InputMode.keyboard;
  InputMode get mode => _mode;

  /// Space-separated words. Trailing/duplicate whitespace is ignored.
  List<String> get tokens =>
      _text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  /// Number of words, used for the (Czech-plural-aware) word count.
  int get wordCount => tokens.length;

  bool get _endsWithSpace => _text.isEmpty || RegExp(r'\s$').hasMatch(_text);

  /// Index of the word still being typed (keyboard mode, no trailing space).
  /// It renders as the active word with a caret — not a removable tile
  /// (§6.1.2). `-1` when there is no in-progress word.
  int get activeIndex =>
      _mode == InputMode.keyboard && !_endsWithSpace && tokens.isNotEmpty
          ? tokens.length - 1
          : -1;

  void setMode(InputMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// A single keystroke from the on-screen keyboard.
  void addChar(String char) {
    _text += char;
    notifyListeners();
  }

  void backspace() {
    if (_text.isEmpty) return;
    _text = _text.substring(0, _text.length - 1);
    notifyListeners();
  }

  /// Append a complete word from a symbol tap (always an editable tile).
  void appendWord(String word) {
    _text = (_text.isNotEmpty && !_endsWithSpace ? '$_text ' : _text) + word;
    notifyListeners();
  }

  /// Load a full phrase, replacing the current message.
  void loadText(String value) {
    _text = value;
    notifyListeners();
  }

  /// Remove the word tile at [index] (tap-to-remove ✕, §6.1).
  void removeWordAt(int index) {
    final words = tokens;
    if (index < 0 || index >= words.length) return;
    words.removeAt(index);
    _text = words.isEmpty ? '' : '${words.join(' ')} ';
    notifyListeners();
  }

  void clear() {
    if (_text.isEmpty) return;
    _text = '';
    notifyListeners();
  }
}
