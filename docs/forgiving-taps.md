# Forgiving taps (release-within-bounds keys)
https://github.com/AlexandrSHad/handy-speak/issues/4

## Symptom

On-screen keyboard keys sometimes played their ripple but inserted nothing.
Users with small fingertips (or shaky/rolling presses) — exactly this app's
audience — hit it constantly: the key visibly responds, no character appears.

## Root cause

The keys used `InkWell.onTap`, backed by Flutter's `TapGestureRecognizer`.
The recognizer **cancels the tap once the pointer drifts more than
`kTouchSlop` (~18 logical px)** between down and up — but the ink ripple has
already started on pointer-down. A fingertip that rolls during the press
gets visual feedback and no input.

The web POC never showed this because browser `click` is drift-tolerant: it
fires on release as long as the pointer is still over the element.

## Chosen semantics

Browser-click style, "release within bounds":

- A key **activates on pointer RELEASE while the pointer is inside the key's
  bounds**, regardless of how far it drifted during the press.
- Sliding **off** the key before lifting cancels — nothing is inserted.
- A key never activates from a press that started on a **different** key
  (pointer events stay routed to the down hit-test path).

## The `ForgivingTap` widget

`lib/widgets/forgiving_tap.dart`. It wraps the child in a raw `Listener`
(pointer events bypass the gesture arena, so the up event arrives even after
the tap recognizer gave up at `kTouchSlop`) plus an `InkWell` kept purely for
the ripple. `onPointerUp` does a bounds check against the widget's own render
box and invokes the callback only if the release landed inside.

A null `onTap` renders the surface fully inert: the inner `InkWell.onTap` is
also null, so no ripple, no hover, no activation — tests can (and do) assert
inertness via `InkWell.onTap == null` (see the disabled shift key in Big
letters mode, ADDENDUM-01 suite).

### Applying it

Replace the `InkWell` with `ForgivingTap`, keeping the surrounding `Material`
and passing the same `borderRadius`:

```dart
Material(
  color: colors.keyBg,
  borderRadius: BorderRadius.circular(AppTokens.rKey),
  child: ForgivingTap(
    borderRadius: BorderRadius.circular(AppTokens.rKey),
    onTap: () => onTap(value),   // or `enabled ? onTap : null` for inertness
    child: ...,
  ),
)
```

## Migrated surfaces

`lib/widgets/keyboard_view.dart` only:

- `_CharKey` (letter/punctuation keys)
- `_ModKey` (shift, backspace) — with `enabled ? onTap : null` passthrough
- the space bar in `_SpaceRow`

## Surfaces still on strict `InkWell.onTap` (candidates for later migration)

- Symbol tiles — `lib/widgets/symbol_board.dart`
- Phrase chips — `lib/widgets/phrase_strip.dart`
- Message-bar word tiles
- The Speak button
- Top-bar controls (language toggle, settings)

Larger targets suffer less from slop cancels, so the keyboard was fixed
first; migrate the rest if dropped taps are reported there.

## Known cosmetic limit

On a drifted press the **ripple still cancels early** at `kTouchSlop` (the
ink splash is tied to the tap recognizer), even though the key now correctly
activates on release. Input is never lost; only the visual can end early.

## Regression suite

- `integration_test/keytap_suite.dart` — encodes the semantics: clean tap,
  drift-press within bounds (letter and space), slide-off cancel, and
  two-finger rollover.
- Headless entry point: `flutter test test/keytap_test.dart`.
