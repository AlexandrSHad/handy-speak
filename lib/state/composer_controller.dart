import 'package:flutter/foundation.dart';

import '../core/math_speak.dart';

/// Which input board is active. Keyboard + Symbols share one buffer (the
/// "sentence"); Math has its own buffer (glyphs survive a language switch).
enum InputMode { keyboard, symbols, math }

/// Holds the composed message and the active input mode (IMPLEMENTATION_PLAN
/// Task 3/4). ADDENDUM-02 splits the single buffer into two workspaces:
///   - **sentence** — Keyboard + Symbols (free-typed prose, language-bound),
///   - **math**     — the Math board (glyphs; survives an EN⇄CS switch).
///
/// The active buffer's raw [text] string is the source of truth for word
/// tiles and the in-progress caret, mirroring the prototype's `MessageBlocks`
/// (§6.1.2). Switching modes is non-destructive: each buffer keeps its state.
class ComposerController extends ChangeNotifier {
  String _sentenceText = '';
  String _mathText = '';

  /// The active buffer's raw text (routed by [mode]). This is what the
  /// message bar, word tiles and Speak read.
  String get text => _mode == InputMode.math ? _mathText : _sentenceText;

  /// Private routed setter so the sentence-shaped mutators (`addChar`,
  /// `appendWord`, …) write the active buffer without each call site
  /// branching on mode. The math mutators bypass this and write `math`
  /// directly, so a stray call can never corrupt the sentence.
  set _active(String v) {
    if (_mode == InputMode.math) {
      _mathText = v;
    } else {
      _sentenceText = v;
    }
  }

  InputMode _mode = InputMode.keyboard;
  InputMode get mode => _mode;

  /// Space-separated words. Trailing/duplicate whitespace is ignored.
  List<String> get tokens =>
      text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  /// Number of words, used for the (Czech-plural-aware) word count.
  int get wordCount => tokens.length;

  bool get _endsWithSpace => text.isEmpty || RegExp(r'\s$').hasMatch(text);

  /// Index of the word still being typed (keyboard OR math mode, no trailing
  /// space). It renders as the active word with a caret — not a removable
  /// tile (§6.1.2). `-1` when there is no in-progress word.
  int get activeIndex =>
      (_mode == InputMode.keyboard || _mode == InputMode.math) &&
              !_endsWithSpace &&
              tokens.isNotEmpty
          ? tokens.length - 1
          : -1;

  void setMode(InputMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// A single keystroke from the on-screen keyboard (writes the active
  /// sentence buffer; only ever called while a sentence board is shown).
  void addChar(String char) {
    _active = text + char;
    notifyListeners();
  }

  void backspace() {
    if (text.isEmpty) return;
    _active = text.substring(0, text.length - 1);
    notifyListeners();
  }

  /// Append a complete word from a symbol tap (always an editable tile).
  void appendWord(String word) {
    _active = (text.isNotEmpty && !_endsWithSpace ? '$text ' : text) + word;
    notifyListeners();
  }

  /// Load a full phrase, replacing the current message.
  void loadText(String value) {
    _active = value;
    notifyListeners();
  }

  /// Remove the word tile at [index] (tap-to-remove ✕, §6.1).
  void removeWordAt(int index) {
    final words = tokens;
    if (index < 0 || index >= words.length) return;
    words.removeAt(index);
    _active = words.isEmpty ? '' : '${words.join(' ')} ';
    notifyListeners();
  }

  /// Clear the active buffer (MessageBar Clear): in math wipes the problem,
  /// in keyboard/symbols wipes the sentence.
  void clear() {
    if (text.isEmpty) return;
    _active = '';
    notifyListeners();
  }

  /// Wipe the sentence buffer only. Used by the language switch — free-typed
  /// prose is language-bound, but the math problem is glyphs and survives.
  void clearSentence() {
    if (_sentenceText.isEmpty) return;
    _sentenceText = '';
    notifyListeners();
  }

  // --- Math mutators (always route to the math buffer, never the sentence) ---

  /// Append a digit or `.` so a trailing number stays one tile.
  void appendMathDigit(String d) {
    _mathText = mathAppendDigit(_mathText, d);
    notifyListeners();
  }

  /// Append an operator/comparison as its own space-delimited tile.
  void appendMathOp(String op) {
    _mathText = mathAppendOp(_mathText, op);
    notifyListeners();
  }

  /// Delete one glyph from the math buffer (trim a digit, or drop a sign).
  void mathBackspace() {
    if (_mathText.isEmpty) return;
    _mathText = mathDeleteLast(_mathText);
    notifyListeners();
  }
}
