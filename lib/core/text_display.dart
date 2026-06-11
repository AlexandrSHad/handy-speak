/// Render-time-only casing for "Big letters" mode. Never mutate stored
/// text, phrases, or TTS input — apply at the Text widget only.
/// Apply to any future child-facing surface (prediction bar, Snap & Say,
/// undo chip) when those exist.
extension DisplayCase on String {
  String displayUpper(bool bigLetters) => bigLetters ? toUpperCase() : this;
}
