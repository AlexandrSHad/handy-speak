import 'package:flutter/foundation.dart';

import '../core/math_speak.dart';

/// Which input board is active. Keyboard + Symbols share one buffer (the
/// "sentence"); Math has its own buffer (glyphs survive a language switch).
enum InputMode { keyboard, symbols, math }

/// Keys that finish a word (the space row's terminator keys). Shared by
/// [ComposerController.addChar] (to compute the word a keystroke just
/// completed) and the speech feedback coordinator (to know which chars never
/// echo).
const kWordTerminators = {' ', ',', '.', '!', '?'};

/// What the last mutation was, so a speech-feedback coordinator can react to
/// input without diffing the text. Set by every mutator — null when the
/// mutation is not fresh user input (backspace, clear, tile removal, mode
/// switch). Only meaningful until the next mutation; the UI must keep reading
/// [ComposerController.text]/[tokens], never this stream.
sealed class ComposerEvent {
  const ComposerEvent();
}

/// A single keystroke from the on-screen keyboard. [completedWord] is the
/// in-progress word this keystroke just terminated (a [kWordTerminators] key
/// pressed with a word on screen), or null for any other keystroke.
final class CharTyped extends ComposerEvent {
  const CharTyped(this.char, {this.completedWord});

  final String char;
  final String? completedWord;
}

/// A whole word inserted at once by a symbol/pictogram tap.
final class WordAppended extends ComposerEvent {
  const WordAppended(this.word);

  final String word;
}

/// The whole buffer replaced by a phrase selection.
final class TextLoaded extends ComposerEvent {
  const TextLoaded(this.text);

  final String text;
}

/// A digit (or `.`) appended to the math board's trailing number.
final class MathDigitTyped extends ComposerEvent {
  const MathDigitTyped(this.digit);

  final String digit;
}

/// A math operator/comparison key. [completedNumber] is the trailing number
/// this press terminated, or null when the previous tile wasn't a number (or
/// the press no-opped on an empty buffer → the event itself is null).
final class MathOpTyped extends ComposerEvent {
  const MathOpTyped(this.op, {this.completedNumber});

  final String op;
  final String? completedNumber;
}

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

  ComposerEvent? _lastEvent;

  /// The mutation behind the most recent [notifyListeners] — see
  /// [ComposerEvent]. Null for non-input mutations.
  ComposerEvent? get lastEvent => _lastEvent;

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
    _lastEvent = null;
    notifyListeners();
  }

  /// A single keystroke from the on-screen keyboard (writes the active
  /// sentence buffer; only ever called while a sentence board is shown).
  void addChar(String char) {
    // The word this keystroke finishes, computed BEFORE appending: tokens.last
    // is still the clean in-progress word, without the terminator glyph.
    final completed = kWordTerminators.contains(char) && activeIndex != -1
        ? tokens.last
        : null;
    _active = text + char;
    _lastEvent = CharTyped(char, completedWord: completed);
    notifyListeners();
  }

  void backspace() {
    if (text.isEmpty) return;
    _active = text.substring(0, text.length - 1);
    _lastEvent = null;
    notifyListeners();
  }

  /// Append a complete word from a symbol tap (always an editable tile).
  void appendWord(String word) {
    _active = (text.isNotEmpty && !_endsWithSpace ? '$text ' : text) + word;
    _lastEvent = WordAppended(word);
    notifyListeners();
  }

  /// Load a full phrase, replacing the current message.
  void loadText(String value) {
    _active = value;
    _lastEvent = TextLoaded(value);
    notifyListeners();
  }

  /// Remove the word tile at [index] (tap-to-remove ✕, §6.1).
  void removeWordAt(int index) {
    final words = tokens;
    if (index < 0 || index >= words.length) return;
    words.removeAt(index);
    _active = words.isEmpty ? '' : '${words.join(' ')} ';
    _lastEvent = null;
    notifyListeners();
  }

  /// Clear the active buffer (MessageBar Clear): in math wipes the problem,
  /// in keyboard/symbols wipes the sentence.
  void clear() {
    if (text.isEmpty) return;
    _active = '';
    _lastEvent = null;
    notifyListeners();
  }

  /// Wipe the sentence buffer only. Used by the language switch — free-typed
  /// prose is language-bound, but the math problem is glyphs and survives.
  void clearSentence() {
    if (_sentenceText.isEmpty) return;
    _sentenceText = '';
    _lastEvent = null;
    notifyListeners();
  }

  // --- Math mutators (always route to the math buffer, never the sentence) ---

  /// Append a digit or `.` so a trailing number stays one tile.
  void appendMathDigit(String d) {
    _mathText = mathAppendDigit(_mathText, d);
    _lastEvent = MathDigitTyped(d);
    notifyListeners();
  }

  /// Append an operator/comparison as its own space-delimited tile.
  void appendMathOp(String op) {
    // The number this press completes (if any), computed before the mutation:
    // feedback speaks the *finished* number, not the op glyph. An op leading
    // on an empty buffer no-oops (mathAppendOp) and emits no event.
    final trimmed = _mathText.replaceFirst(RegExp(r'\s+$'), '');
    final last = trimmed.isEmpty ? null : trimmed.split(RegExp(r'\s+')).last;
    _lastEvent = trimmed.isEmpty
        ? null
        : MathOpTyped(
            op,
            completedNumber: last != null && RegExp(r'^[0-9.]+$').hasMatch(last)
                ? last
                : null,
          );
    _mathText = mathAppendOp(_mathText, op);
    notifyListeners();
  }

  /// Delete one glyph from the math buffer (trim a digit, or drop a sign).
  void mathBackspace() {
    if (_mathText.isEmpty) return;
    _mathText = mathDeleteLast(_mathText);
    _lastEvent = null;
    notifyListeners();
  }
}
