import 'package:flutter/material.dart';

/// Tap surface for child-facing keys with release-within-bounds semantics:
/// activates on pointer release while the pointer is still inside this
/// widget's bounds, no matter how far it drifted during the press.
///
/// Flutter's stock [InkWell.onTap] cancels once the pointer moves past
/// [kTouchSlop] (~18 px) — but the ripple has already played, so a child
/// whose fingertip rolls during the press gets feedback and no input
/// (browser `click` is drift-tolerant, which is why the web POC never
/// showed this). Sliding off the key before lifting still cancels.
///
/// A null [onTap] renders the surface inert: no ripple, no activation
/// (the inner [InkWell.onTap] is null so tests can assert inertness).
///
/// See docs/forgiving-taps.md for background and migration notes.
class ForgivingTap extends StatelessWidget {
  const ForgivingTap({
    super.key,
    required this.onTap,
    this.borderRadius,
    required this.child,
  });

  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Raw pointer events bypass the gesture arena, so the up event
      // arrives here even after InkWell's recognizer gave up at kTouchSlop.
      // Pointer routing sticks to the down hit-test path, so a press that
      // started on another key can never release "into" this one.
      onPointerUp: onTap == null
          ? null
          : (event) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.attached) return;
              final local = box.globalToLocal(event.position);
              if ((Offset.zero & box.size).contains(local)) {
                onTap!();
              }
            },
      child: InkWell(
        borderRadius: borderRadius,
        // Ripple/visual feedback only — activation happens in onPointerUp.
        onTap: onTap == null ? null : () {},
        child: child,
      ),
    );
  }
}
