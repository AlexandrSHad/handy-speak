/* HandySpeak — MessageBlocks: words as tactile, editable tiles
   Four independently-toggled edit affordances (parent settings):
     • swipeRemove   — flick a tile up to throw it away
     • tapX          — tap a tile to reveal a ✕ (default on)
     • tapMove       — tap a tile to reveal ◀ ▶ move arrows
     • longPressDrag — press-and-hold to lift, drag to reorder
   tapX / tapMove share one tap-select state and a popover toolbar.
   Every path has an undo. Gestures are accelerators layered over the
   tap baseline so switch-scanning / low-motor users keep full power. */

const { useState: useStateWB, useRef: useRefWB, useEffect: useEffectWB } = React;

const SWIPE_TRIGGER = 60;   // px upward to commit a remove
const MOVE_SLOP     = 7;    // px before a press counts as a drag/swipe
const LONGPRESS_MS  = 300;  // hold before drag lifts

function MessageBlocks({ text, mode, mood, settings, onChange, initialSelected = null, placeholder }) {
  const { swipeRemove, tapX, tapMove, longPressDrag } = settings;

  const tokens = text.split(/\s+/).filter(Boolean);
  const endsSpace = text === '' || /\s$/.test(text);
  const activeIndex =
    mode === 'keyboard' && !endsSpace && tokens.length ? tokens.length - 1 : -1;

  const [selected, setSelected] = useStateWB(initialSelected);
  const [undo, setUndo]         = useStateWB(null);   // { word, index }
  const [drag, setDrag]         = useStateWB(null);   // { from, dx, over }
  const [swipe, setSwipe]       = useStateWB(null);   // { index, dy }

  const containerRef = useRefWB(null);
  const gesture      = useRefWB(null);   // live pointer bookkeeping
  const lpTimer      = useRefWB(null);

  // keep selection valid as tokens change
  useEffectWB(() => {
    if (selected != null && selected >= tokens.length) setSelected(null);
  }, [tokens.length]);

  // auto-dismiss undo
  useEffectWB(() => {
    if (!undo) return;
    const id = setTimeout(() => setUndo(null), 6000);
    return () => clearTimeout(id);
  }, [undo]);

  const buzz = (ms = 8) => { if (navigator.vibrate) navigator.vibrate(ms); };
  const commit = (arr) => onChange(arr.length ? arr.join(' ') + ' ' : '');

  const removeAt = (i) => {
    const arr = tokens.slice();
    const [w] = arr.splice(i, 1);
    setUndo({ word: w, index: i });
    setSelected(null);
    buzz(14);
    commit(arr);
  };
  const restore = () => {
    if (!undo) return;
    const arr = tokens.slice();
    arr.splice(Math.min(undo.index, arr.length), 0, undo.word);
    setUndo(null);
    commit(arr);
  };
  const moveBy = (i, dir) => {
    const j = i + dir;
    if (j < 0 || j >= tokens.length) return;
    const arr = tokens.slice();
    [arr[i], arr[j]] = [arr[j], arr[i]];
    setSelected(j);
    buzz();
    commit(arr);
  };
  const reorder = (from, insertion) => {
    const arr = tokens.slice();
    const [w] = arr.splice(from, 1);
    const to = insertion > from ? insertion - 1 : insertion;
    arr.splice(to, 0, w);
    buzz(14);
    commit(arr);
  };

  // which insertion slot (0..len) does clientX fall into during a drag?
  const overFromX = (clientX) => {
    const els = containerRef.current?.querySelectorAll('[data-wb]') || [];
    for (let k = 0; k < els.length; k++) {
      const r = els[k].getBoundingClientRect();
      if (clientX < r.left + r.width / 2) return k;
    }
    return tokens.length;
  };

  const clearLP = () => { if (lpTimer.current) { clearTimeout(lpTimer.current); lpTimer.current = null; } };

  const onDown = (i) => (e) => {
    if (e.button === 1 || e.button === 2) return;
    e.stopPropagation();
    e.currentTarget.setPointerCapture?.(e.pointerId);
    gesture.current = { i, x0: e.clientX, y0: e.clientY, moved: false, mode: null, t: Date.now() };
    if (longPressDrag) {
      clearLP();
      lpTimer.current = setTimeout(() => {
        const g = gesture.current;
        if (!g || g.moved) return;
        g.mode = 'drag';
        buzz(18);
        setSelected(null);
        setDrag({ from: i, dx: 0, over: i });
      }, LONGPRESS_MS);
    }
  };

  const onMove = (e) => {
    const g = gesture.current;
    if (!g) return;
    const dx = e.clientX - g.x0;
    const dy = e.clientY - g.y0;
    const dist = Math.hypot(dx, dy);

    if (g.mode === 'drag') {
      e.stopPropagation();
      setDrag({ from: g.i, dx, over: overFromX(e.clientX) });
      return;
    }
    if (g.mode === 'swipe') {
      e.stopPropagation();
      setSwipe({ index: g.i, dy: Math.min(0, dy) });
      return;
    }
    if (dist < MOVE_SLOP) return;
    g.moved = true;
    clearLP();
    // commit to a gesture on first decisive move
    if (swipeRemove && dy < 0 && Math.abs(dy) > Math.abs(dx)) {
      g.mode = 'swipe';
      e.stopPropagation();
      setSwipe({ index: g.i, dy });
    }
  };

  const onUp = (e) => {
    const g = gesture.current;
    gesture.current = null;
    clearLP();
    if (!g) return;

    if (g.mode === 'drag') {
      e.stopPropagation();
      const over = overFromX(e.clientX);
      setDrag(null);
      if (over !== g.i && over !== g.i + 1) reorder(g.i, over);
      return;
    }
    if (g.mode === 'swipe') {
      e.stopPropagation();
      const dy = e.clientY - g.y0;
      setSwipe(null);
      if (dy < -SWIPE_TRIGGER) removeAt(g.i);
      return;
    }
    // a tap
    if (!g.moved && (tapX || tapMove)) {
      setSelected((s) => (s === g.i ? null : g.i));
    }
  };

  const onCancel = () => { gesture.current = null; clearLP(); setDrag(null); setSwipe(null); };

  // ---- empty state ----
  if (!tokens.length) {
    return (
      <div className="msg-blocks empty" ref={containerRef}>
        <span className="wb-placeholder">{placeholder || 'Tap keys or symbols to compose…'}</span>
      </div>
    );
  }

  const showToolbar = (i) =>
    selected === i && drag == null && swipe == null && (tapX || tapMove);

  const children = [];
  tokens.forEach((w, i) => {
    if (drag && drag.over === i) children.push(<span className="wb-drop" key={`d${i}`} />);

    const isDrag   = drag?.from === i;
    const isSwipe  = swipe?.index === i;
    const style = {};
    if (isDrag)  style.transform = `translate(${drag.dx}px, -6px) scale(1.05)`;
    if (isSwipe) {
      style.transform = `translateY(${swipe.dy}px)`;
      style.opacity = Math.max(0.15, 1 - Math.abs(swipe.dy) / (SWIPE_TRIGGER * 1.6));
    }
    const willRemove = isSwipe && swipe.dy < -SWIPE_TRIGGER;

    children.push(
      <span
        key={i}
        data-wb={i}
        className={
          'wblock' +
          (i === activeIndex ? ' active' : '') +
          (selected === i ? ' selected' : '') +
          (isDrag ? ' dragging' : '') +
          (isSwipe ? ' swiping' : '') +
          (willRemove ? ' will-remove' : '')
        }
        style={{ ...style, '--mood-current': `var(--mood-${mood})` }}
        onPointerDown={onDown(i)}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerCancel={onCancel}
      >
        {willRemove && <span className="wb-toss" aria-hidden>↑</span>}
        {w}
        {i === activeIndex && <span className="wb-caret" />}

        {showToolbar(i) && (
          <span className="wb-toolbar" onPointerDown={(e) => e.stopPropagation()}>
            {tapMove && (
              <button
                className="wb-btn"
                disabled={i === 0}
                onClick={(e) => { e.stopPropagation(); moveBy(i, -1); }}
                aria-label="Move word left"
              >◀</button>
            )}
            {tapX && (
              <button
                className="wb-btn danger"
                onClick={(e) => { e.stopPropagation(); removeAt(i); }}
                aria-label={`Remove ${w}`}
              >✕</button>
            )}
            {tapMove && (
              <button
                className="wb-btn"
                disabled={i === tokens.length - 1}
                onClick={(e) => { e.stopPropagation(); moveBy(i, 1); }}
                aria-label="Move word right"
              >▶</button>
            )}
          </span>
        )}
      </span>
    );
  });

  if (drag && drag.over >= tokens.length) children.push(<span className="wb-drop" key="dend" />);
  if (activeIndex === -1) children.push(<span className="wb-caret tail" key="caret" />);

  return (
    <div
      className="msg-blocks"
      ref={containerRef}
      onPointerDown={(e) => { if (e.target === e.currentTarget) setSelected(null); }}
    >
      {children}
      {undo && (
        <button className="wb-undo" onClick={restore} onPointerDown={(e) => e.stopPropagation()}>
          ↩ Bring back “{undo.word}”
        </button>
      )}
    </div>
  );
}

window.MessageBlocks = MessageBlocks;
