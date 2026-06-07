/* HandySpeak — main interactive tablet app */

const { useState, useEffect, useRef, useMemo, useCallback } = React;

/* ---------------- DATA ---------------- */

const MOODS = [
  { id: 'happy',   label: 'Happy',   emoji: '😊', rate: 1.10, pitch: 1.35 },
  { id: 'excited', label: 'Excited', emoji: '🤩', rate: 1.25, pitch: 1.45 },
  { id: 'calm',    label: 'Calm',    emoji: '😌', rate: 0.95, pitch: 1.00 },
  { id: 'curious', label: 'Curious', emoji: '🤔', rate: 1.00, pitch: 1.20 },
  { id: 'sad',     label: 'Sad',     emoji: '🥺', rate: 0.85, pitch: 0.85 },
  { id: 'angry',   label: 'Angry',   emoji: '😠', rate: 1.10, pitch: 0.70 },
];

const STARTER_PHRASES = [
  { text: "I need help",       pinned: true,  uses: 42 },
  { text: "Bathroom please",   pinned: true,  uses: 31 },
  { text: "I'm hungry",        pinned: true,  uses: 28 },
  { text: "I don't understand",pinned: true,  uses: 19 },
  { text: "Thank you",         pinned: false, uses: 24 },
  { text: "Yes please",        pinned: false, uses: 22 },
  { text: "Can I play?",       pinned: false, uses: 14 },
  { text: "All done",          pinned: false, uses: 12 },
];

const CATEGORIES = [
  { id: 'feelings',   label: 'Feelings',   icon: '💛', color: 'var(--mood-happy)' },
  { id: 'food',       label: 'Food',       icon: '🍎', color: 'oklch(72% 0.16 35)' },
  { id: 'school',     label: 'School',     icon: '✏️', color: 'oklch(72% 0.13 230)' },
  { id: 'family',     label: 'Family',     icon: '👪', color: 'oklch(72% 0.15 305)' },
  { id: 'activities', label: 'Activities', icon: '⚽', color: 'oklch(70% 0.16 145)' },
  { id: 'places',     label: 'Places',     icon: '🏠', color: 'oklch(72% 0.13 260)' },
  { id: 'numbers',    label: 'Numbers',    icon: '🔢', color: 'oklch(70% 0.10 180)' },
  { id: 'greetings',  label: 'Hello',      icon: '👋', color: 'oklch(78% 0.14 90)'  },
];

const PICTOGRAMS = {
  feelings: [
    { word: 'happy',     emoji: '😊' }, { word: 'sad',       emoji: '😢' },
    { word: 'tired',     emoji: '😴' }, { word: 'scared',     emoji: '😨' },
    { word: 'excited',   emoji: '🤩' }, { word: 'angry',      emoji: '😠' },
    { word: 'love',      emoji: '❤️' }, { word: 'calm',       emoji: '😌' },
    { word: 'silly',     emoji: '🤪' }, { word: 'shy',        emoji: '🙈' },
  ],
  food: [
    { word: 'apple',     emoji: '🍎' }, { word: 'water',      emoji: '💧' },
    { word: 'milk',      emoji: '🥛' }, { word: 'pizza',      emoji: '🍕' },
    { word: 'banana',    emoji: '🍌' }, { word: 'cookie',     emoji: '🍪' },
    { word: 'sandwich',  emoji: '🥪' }, { word: 'pasta',      emoji: '🍝' },
    { word: 'cereal',    emoji: '🥣' }, { word: 'juice',      emoji: '🧃' },
  ],
  school: [
    { word: 'book',      emoji: '📚' }, { word: 'pencil',     emoji: '✏️' },
    { word: 'teacher',   emoji: '👩‍🏫' }, { word: 'art',     emoji: '🎨' },
    { word: 'math',      emoji: '➗' }, { word: 'recess',     emoji: '🛝' },
    { word: 'music',     emoji: '🎵' }, { word: 'computer',   emoji: '💻' },
    { word: 'science',   emoji: '🔬' }, { word: 'reading',    emoji: '📖' },
  ],
  family: [
    { word: 'mom',       emoji: '👩' }, { word: 'dad',        emoji: '👨' },
    { word: 'sister',    emoji: '👧' }, { word: 'brother',    emoji: '👦' },
    { word: 'grandma',   emoji: '👵' }, { word: 'grandpa',    emoji: '👴' },
    { word: 'baby',      emoji: '👶' }, { word: 'dog',        emoji: '🐶' },
    { word: 'cat',       emoji: '🐱' }, { word: 'friend',     emoji: '🧒' },
  ],
  activities: [
    { word: 'play',      emoji: '🎮' }, { word: 'draw',       emoji: '🖍️' },
    { word: 'run',       emoji: '🏃' }, { word: 'jump',       emoji: '🤸' },
    { word: 'sleep',     emoji: '😴' }, { word: 'sing',       emoji: '🎤' },
    { word: 'dance',     emoji: '💃' }, { word: 'swim',       emoji: '🏊' },
    { word: 'read',      emoji: '📖' }, { word: 'build',      emoji: '🧱' },
  ],
  places: [
    { word: 'home',      emoji: '🏠' }, { word: 'school',     emoji: '🏫' },
    { word: 'park',      emoji: '🌳' }, { word: 'store',      emoji: '🛒' },
    { word: 'bathroom',  emoji: '🚻' }, { word: 'kitchen',    emoji: '🍳' },
    { word: 'outside',   emoji: '☀️' }, { word: 'car',        emoji: '🚗' },
    { word: 'beach',     emoji: '🏖️' }, { word: 'doctor',    emoji: '🏥' },
  ],
  numbers: [
    { word: 'one',       emoji: '1️⃣' }, { word: 'two',       emoji: '2️⃣' },
    { word: 'three',     emoji: '3️⃣' }, { word: 'four',      emoji: '4️⃣' },
    { word: 'five',      emoji: '5️⃣' }, { word: 'more',      emoji: '➕' },
    { word: 'less',      emoji: '➖' }, { word: 'all',        emoji: '💯' },
    { word: 'none',      emoji: '0️⃣' }, { word: 'some',      emoji: '🤏' },
  ],
  greetings: [
    { word: 'hello',     emoji: '👋' }, { word: 'goodbye',    emoji: '🖐️' },
    { word: 'please',    emoji: '🙏' }, { word: 'thank you',  emoji: '💝' },
    { word: 'sorry',     emoji: '😔' }, { word: 'yes',        emoji: '✅' },
    { word: 'no',        emoji: '❌' }, { word: 'okay',       emoji: '👌' },
    { word: 'good morning', emoji: '🌅' }, { word: 'good night', emoji: '🌙' },
  ],
};

const SNAP_TARGETS = [
  { id: 'sandwich', word: 'sandwich', emoji: '🥪', conf: 0.94, alt: ['bread', 'wrap', 'lunch']      },
  { id: 'dog',      word: 'dog',      emoji: '🐕', conf: 0.97, alt: ['puppy', 'pet']                },
  { id: 'ball',     word: 'ball',     emoji: '⚽',        conf: 0.91, alt: ['football', 'soccer']         },
  { id: 'book',     word: 'book',     emoji: '📕', conf: 0.93, alt: ['novel', 'story']              },
  { id: 'apple',    word: 'apple',    emoji: '🍎', conf: 0.96, alt: ['fruit', 'snack']              },
  { id: 'cup',      word: 'cup',      emoji: '🥤', conf: 0.89, alt: ['drink', 'glass', 'water']     },
];

// Per-language keyboard layouts. English = QWERTY with a plain digit row.
// Czech = QWERTZ (y/z swapped) with a dedicated diacritics row in place of
// the old math keys. Digits live behind ?123 for both (skipped for POC).
const LAYOUTS = {
  en: [
    { keys: ['1','2','3','4','5','6','7','8','9','0'], type: 'num' },
    { keys: ['q','w','e','r','t','y','u','i','o','p'] },
    { keys: ['a','s','d','f','g','h','j','k','l'] },
    { keys: ['z','x','c','v','b','n','m'] },
  ],
  cs: [
    { keys: ['á','č','ď','é','ě','í','ň','ó','ř','š','ť','ú','ů','ý','ž'], type: 'accent' },
    { keys: ['q','w','e','r','t','z','u','i','o','p'] },
    { keys: ['a','s','d','f','g','h','j','k','l'] },
    { keys: ['y','x','c','v','b','n','m'] },
  ],
};

// Tiny prediction engine — last-word lookup table
const PREDICT = {
  '':       ['I',     'the',    'a'],
  'i':      ['I',     'is',     'in'],
  'i\'m':   ["I'm",   "I'm not", "I'm a"],
  'i wa':   ['want',  'was',    'watch'],
  'i wan':  ['want',  'wanted'],
  'i want': ['want',  'want to','want a'],
  'pla':    ['play',  'plan',   'plant'],
  'play':   ['play',  'playing','played'],
  'hun':    ['hungry','hundred','hunt'],
  'hung':   ['hungry','hung'],
  'th':     ['the',   'this',   'that'],
  'the':    ['the',   'there',  'they'],
  'thi':    ['this',  'think',  'thing'],
  'go':     ['go',    'good',   'going'],
  'goo':    ['good',  'goose'],
  'help':   ['help',  'helped', 'helping'],
  'ba':     ['back',  'ball',   'bathroom'],
  'bat':    ['bathroom','bat',  'batter'],
  'no':     ['no',    'not',    'now'],
  'ye':     ['yes',   'yellow', 'year'],
  'ou':     ['out',   'our',    'outside'],
  'out':    ['outside','out',   'outer'],
};

function predict(text, lang = 'en') {
  const TABLE = lang === 'cs' ? (window.PREDICT_CS || {}) : PREDICT;
  const tokens = text.toLowerCase().trim().split(/\s+/);
  const last = tokens[tokens.length - 1] || '';
  const dict = TABLE[last] || TABLE[last.slice(0,4)] || TABLE[last.slice(0,3)] || TABLE[last.slice(0,2)] || null;
  if (!last) return TABLE[''] || ['I', 'The', 'Can'];
  if (dict) return dict.slice(0, 3);
  // generic fallback — Czech has no -ing/-ed, so don't fabricate suffixes
  if (lang === 'cs') return [last];
  return [last, last + 'ing', last + 'ed'];
}

/* ---------------- TTS ---------------- */
// The speech engine follows the active language: we set the utterance's
// BCP-47 lang AND actively pick a matching installed voice (browsers won't
// reliably auto-match). Mood rate/pitch ride on top, unchanged across langs.
function useSpeak() {
  const [speaking, setSpeaking] = useState(false);
  const speak = useCallback((text, mood, lang = 'en') => {
    if (!text.trim()) return;
    if (typeof window === 'undefined' || !window.speechSynthesis) return;
    const L = (window.LANGS || []).find(l => l.id === lang) || { bcp47: 'en-US', voicePrefix: 'en' };
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = L.bcp47;
    const voices = window.speechSynthesis.getVoices() || [];
    const match = voices.find(v => (v.lang || '').replace('_', '-').toLowerCase().startsWith(L.voicePrefix));
    if (match) u.voice = match;
    u.rate  = mood?.rate  ?? 1;
    u.pitch = mood?.pitch ?? 1;
    u.onstart = () => setSpeaking(true);
    u.onend   = () => setSpeaking(false);
    u.onerror = () => setSpeaking(false);
    window.speechSynthesis.speak(u);
  }, []);
  return [speak, speaking];
}

// Is a voice for this language actually installed on the device?
function useVoiceAvailable(prefix) {
  const [ok, setOk] = useState(true);
  useEffect(() => {
    if (typeof window === 'undefined' || !window.speechSynthesis) { setOk(false); return; }
    const check = () => {
      const voices = window.speechSynthesis.getVoices() || [];
      setOk(voices.some(v => (v.lang || '').replace('_', '-').toLowerCase().startsWith(prefix)));
    };
    check(); // voices may not be ready yet…
    window.speechSynthesis.addEventListener('voiceschanged', check); // …so re-check when they load
    return () => window.speechSynthesis.removeEventListener('voiceschanged', check);
  }, [prefix]);
  return ok;
}

/* ---------------- ICONS ---------------- */
const Icon = {
  keyboard: () => (<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="6" width="20" height="13" rx="2.5"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M6 14h.01M10 14h.01M14 14h.01M18 14h.01M7 18h10"/></svg>),
  grid: () => (<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>),
  gear: () => (<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 0 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1A1.7 1.7 0 0 0 9 19.4a1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 0 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 0 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>),
  speaker: () => (<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 5 6 9H2v6h4l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M19 5a9 9 0 0 1 0 14"/></svg>),
  shift: () => (<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M12 4 4 12h4v7h8v-7h4z"/></svg>),
  back: () => (<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 5H9l-7 7 7 7h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z"/><path d="m17 9-6 6M11 9l6 6"/></svg>),
  globe: () => (<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>),
  camera: () => (<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 8a2 2 0 0 1 2-2h2.5l1.5-2h6l1.5 2H19a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="4"/></svg>),
  check: () => (<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>),
  retry: () => (<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/><path d="M3 21v-5h5"/></svg>),
  sparkles: () => (<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M12 2l1.5 4.5L18 8l-4.5 1.5L12 14l-1.5-4.5L6 8l4.5-1.5z"/><path d="M19 14l.8 2.2L22 17l-2.2.8L19 20l-.8-2.2L16 17l2.2-.8z"/></svg>),
  close: () => (<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>),
  pin: () => (<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2v6l4 4-2 2h-4l-2-2 4-4V2zM12 14v8"/></svg>),
};

/* ---------------- COMPONENTS ---------------- */

function TopBar({ mode, setMode, onOpenSettings, onOpenSnap, dark, lang, setLang }) {
  const { LANGS, t } = window;
  const ref = useRef(null);
  const [pillStyle, setPillStyle] = useState({});
  useEffect(() => {
    const btn = ref.current?.querySelector(`button[data-mode="${mode}"]`);
    if (btn) {
      setPillStyle({ left: btn.offsetLeft, width: btn.offsetWidth });
    }
  }, [mode, lang]);

  return (
    <div className="topbar">
      <div className="brand">
        <div className="brand-mark" aria-hidden>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 11a4 4 0 0 1 4-4h2v8H7a4 4 0 0 1-4-4z"/>
            <path d="M14 4c3 1 4 4 4 7s-1 6-4 7"/>
          </svg>
        </div>
        HandySpeak
      </div>

      <div className="mode-toggle" ref={ref}>
        <div className="pill" style={pillStyle}/>
        <button data-mode="keyboard" className={mode === 'keyboard' ? 'active' : ''} onClick={() => setMode('keyboard')}>
          <Icon.keyboard /> {t(lang, 'keyboard')}
        </button>
        <button data-mode="symbols" className={mode === 'symbols' ? 'active' : ''} onClick={() => setMode('symbols')}>
          <Icon.grid /> {t(lang, 'symbols')}
        </button>
      </div>

      <div className="right">
        <div className="lang-toggle" role="group" aria-label="Language">
          <Icon.globe />
          {LANGS.map(l => (
            <button
              key={l.id}
              className={lang === l.id ? 'on' : ''}
              onClick={() => setLang(l.id)}
              title={l.name}
              aria-pressed={lang === l.id}
            >
              {l.short}
            </button>
          ))}
        </div>
        <button className="snap-pill" onClick={onOpenSnap} title={t(lang, 'snap')}>
          <span className="lens"><Icon.camera /></span>
          {t(lang, 'snap')}
          <span className="new-dot" aria-hidden/>
        </button>
        <button className="icon-btn" title={t(lang, 'settings')} onClick={onOpenSettings}><Icon.gear /></button>
      </div>
    </div>
  );
}

function MoodStrip({ value, onChange, lang }) {
  const { t, trMood } = window;
  return (
    <div className="mood-strip">
      <span className="mood-label">{t(lang, 'voiceLabel')}</span>
      {MOODS.map(m => (
        <button
          key={m.id}
          className={`mood-btn ${value === m.id ? 'active' : ''}`}
          style={{ '--c': `var(--mood-${m.id})` }}
          onClick={() => onChange(m.id)}
        >
          <span className="face">{m.emoji}</span>
          {trMood(lang, m.id, m.label)}
        </button>
      ))}
    </div>
  );
}

function MessageBar({ text, mode, mood, onClear, onSpeak, speaking, blockSettings, onChangeText, initialSelectedWord, lang, moodEnabled = true }) {
  const Blocks = window.MessageBlocks;
  const { t, trMood, wordCount } = window;
  const wc = text.trim().split(/\s+/).filter(Boolean).length;
  return (
    <div className="compose">
      <div className="message-card" style={{ '--mood-current': `var(--mood-${mood})` }}>
        <Blocks
          text={text}
          mode={mode}
          mood={mood}
          settings={blockSettings}
          onChange={onChangeText}
          initialSelected={initialSelectedWord}
          placeholder={t(lang, 'placeholder')}
        />
        <div className="message-meta">
          <div className="left">
            {moodEnabled && (
              <span className="voice-chip">
                <span className="dot"/>
                {trMood(lang, mood, MOODS.find(m => m.id === mood)?.label || 'Calm')} {t(lang, 'voiceSuffix')}
              </span>
            )}
            <span>{wordCount(lang, wc)}</span>
          </div>
          {text && (
            <button className="clear-btn" onClick={onClear}>{t(lang, 'clear')}</button>
          )}
        </div>
      </div>
      <button
        className={`speak-btn ${speaking ? 'speaking' : ''}`}
        onClick={onSpeak}
        disabled={!text.trim()}
      >
        <span className="speaker-icon"><Icon.speaker /></span>
        {speaking ? t(lang, 'speaking') : t(lang, 'speak')}
      </button>
    </div>
  );
}

function PhraseStrip({ phrases, onPick, lang }) {
  const { t, trPhrase } = window;
  const sorted = useMemo(() => {
    return [...phrases].sort((a, b) => (b.pinned - a.pinned) || (b.uses - a.uses));
  }, [phrases]);
  return (
    <div className="phrases">
      <div className="phrases-label">
        <span>📌</span> {t(lang, 'myPhrases')}
      </div>
      {sorted.slice(0, 8).map((p, i) => {
        const label = trPhrase(lang, p.text);
        return (
          <button
            key={i}
            className={`phrase-chip ${p.pinned ? 'pinned' : ''}`}
            onClick={() => onPick(label)}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}

function Keyboard({ onKey, shift, setShift, predictions, onPredict, lang }) {
  const { t } = window;
  const rows = LAYOUTS[lang] || LAYOUTS.en;
  const lastLetterRow = rows.length - 1;
  return (
    <>
      <div className="predictions">
        {predictions.map((p, i) => (
          <button className="prediction" key={i} onClick={() => onPredict(p)}>
            {p}
          </button>
        ))}
      </div>
      <div className="kb">
        {rows.map((row, ri) => (
          <div className="kb-row" key={ri}>
            {ri === lastLetterRow && (
              <button className={`key mod ${shift ? 'pressed' : ''}`} onClick={() => setShift(!shift)}>
                <Icon.shift />
              </button>
            )}
            {row.keys.map(k => {
              const isNum = row.type === 'num';
              const hasCase = k.toLowerCase() !== k.toUpperCase();
              const label = shift && hasCase ? k.toUpperCase() : k;
              return (
                <button
                  key={k}
                  className={`key ${isNum ? 'num' : ''}`}
                  onClick={() => onKey(label)}
                >
                  {label}
                </button>
              );
            })}
            {ri === lastLetterRow && (
              <button className="key mod" onClick={() => onKey('BACK')}>
                <Icon.back />
              </button>
            )}
          </div>
        ))}
        <div className="kb-row">
          <button className="key mod">?123</button>
          <button className="key" onClick={() => onKey(',')}>,</button>
          <button className="key space" onClick={() => onKey(' ')}>{t(lang, 'space')}</button>
          <button className="key" onClick={() => onKey('.')}>.</button>
          <button className="key mod" onClick={() => onKey('!')}>!</button>
          <button className="key mod" onClick={() => onKey('?')}>?</button>
        </div>
      </div>
    </>
  );
}

function SymbolBoard({ category, setCategory, onPick, recent, onOpenSnap, lang }) {
  const { t, trCat, trWord } = window;
  const cat = CATEGORIES.find(c => c.id === category) || CATEGORIES[0];
  const pics = PICTOGRAMS[category] || [];
  return (
    <div className="symbol-board">
      <div className="categories">
        {CATEGORIES.map(c => (
          <button
            key={c.id}
            className={`cat ${category === c.id ? 'active' : ''}`}
            style={{ '--c': c.color }}
            onClick={() => setCategory(c.id)}
          >
            <span className="swatch">{c.icon}</span>
            {trCat(lang, c.id, c.label)}
          </button>
        ))}
      </div>
      <div style={{flex:1, display:'flex', flexDirection:'column', minWidth:0}}>
        {recent.length > 0 && (
          <div className="recent-strip">
            <div className="recent-label">
              <Icon.sparkles /> {t(lang, 'justSnapped')}
            </div>
            {recent.map((r, i) => (
              <button key={i} className="recent-item" onClick={() => onPick(r.word)}>
                <span className="pic">{r.emoji}</span>
                {r.word}
              </button>
            ))}
          </div>
        )}
        <div className="pictograms">
          <button
            className="pictogram snap-tile"
            onClick={onOpenSnap}
          >
            <div className="pic"><Icon.camera /></div>
            <div className="label">{t(lang, 'snap')}</div>
          </button>
          {pics.map((p, i) => (
            <button
              key={i}
              className="pictogram"
              style={{ '--c': cat.color }}
              onClick={() => onPick(trWord(lang, p.word))}
            >
              <div className="pic">{p.emoji}</div>
              <div className="label">{trWord(lang, p.word)}</div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ---------------- SNAP & SAY ---------------- */

function SnapSay({ onAdd, onClose, initialPhase = 'aim', initialTargetId = 'sandwich', lang = 'en' }) {
  const { t, trWord } = window;
  const [target, setTarget] = React.useState(
    SNAP_TARGETS.find(t => t.id === initialTargetId) || SNAP_TARGETS[0]
  );
  const [phase, setPhase] = React.useState(initialPhase); // 'aim' | 'analyzing' | 'result'
  const [speak] = useSpeak();
  const word = trWord(lang, target.word);

  const shutter = () => {
    if (phase !== 'aim') return;
    if (navigator.vibrate) navigator.vibrate(20);
    setPhase('analyzing');
    setTimeout(() => setPhase('result'), 1300);
  };
  const reset = () => setPhase('aim');

  return (
    <div className="snap-overlay">
      <div className="snap-head">
        <h3>
          <Icon.camera /> {t(lang, 'snap')} <span className="badge">BETA</span>
        </h3>
        <button className="snap-close" onClick={onClose} title="Close"><Icon.close /></button>
      </div>

      <div className="snap-viewfinder">
        <div className="corner tl"/><div className="corner tr"/>
        <div className="corner bl"/><div className="corner br"/>

        {phase === 'aim' && (
          <>
            <div className="aim-reticle"/>
            <div className="scene">{target.emoji}</div>
            <div className="aim-hint">
              <Icon.camera /> {t(lang, 'snapPoint')}
            </div>
          </>
        )}
        {phase === 'analyzing' && (
          <>
            <div className="scene blur locked">{target.emoji}</div>
            <div className="analyzing-chip">
              <span className="dots"><span/><span/><span/></span>
              {t(lang, 'snapLooking')}
            </div>
          </>
        )}
        {phase === 'result' && (
          <div className="result-card">
            <div className="thumb">
              {target.emoji}
              <span className="check"><Icon.check /></span>
            </div>
            <div className="found">{t(lang, 'snapISeeA')}</div>
            <div className="word">{word}</div>
            <div className="conf">
              <div className="conf-track">
                <div className="conf-fill" style={{ width: (target.conf * 100) + '%' }}/>
              </div>
              <div>{Math.round(target.conf * 100)}% {t(lang, 'snapSure')}</div>
            </div>
            <div className="alts">
              {t(lang, 'snapNotQuite')}
              {target.alt.map(a => (
                <button key={a} className="alt-chip" onClick={() => onAdd(trWord(lang, a), target.emoji)}>{trWord(lang, a)}</button>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="snap-controls">
        {phase === 'aim' && (
          <>
            <div className="demo-pills">
              <span>{t(lang, 'snapDemo')}</span>
              {SNAP_TARGETS.map(tg => (
                <button
                  key={tg.id}
                  className={`demo-pill ${target.id === tg.id ? 'on' : ''}`}
                  onClick={() => setTarget(tg)}
                >
                  <span style={{fontSize:18, lineHeight:1}}>{tg.emoji}</span> {trWord(lang, tg.word)}
                </button>
              ))}
            </div>
            <div className="shutter-wrap">
              <button className="shutter" onClick={shutter} aria-label="Capture"/>
            </div>
          </>
        )}
        {phase === 'analyzing' && (
          <div className="shutter-wrap">
            <button className="shutter busy" disabled/>
          </div>
        )}
        {phase === 'result' && (
          <div className="result-actions">
            <button className="action retry" onClick={reset}>
              <Icon.retry /> {t(lang, 'snapTryAgain')}
            </button>
            <button className="action speak-now" onClick={() => speak(word, MOODS.find(m => m.id === 'curious'), lang)}>
              <Icon.speaker /> {t(lang, 'snapHear')}
            </button>
            <button className="action add" onClick={() => onAdd(word, target.emoji)}>
              <Icon.check /> {t(lang, 'snapAdd')} “{word}”
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function SettingsSheet({ phrases, setPhrases, dark, setDark, scan, setScan, haptic, setHaptic, blkSwipe, setBlkSwipe, blkTapX, setBlkTapX, blkTapMove, setBlkTapMove, blkDrag, setBlkDrag, onClose, lang, setLang, voiceOk, moodOn, setMoodOn }) {
  const { t, trPhrase, LANGS } = window;
  const [draft, setDraft] = useState('');
  const togglePin = (i) => setPhrases(phrases.map((p, idx) => idx === i ? {...p, pinned: !p.pinned} : p));
  const remove    = (i) => setPhrases(phrases.filter((_, idx) => idx !== i));
  const add = () => {
    if (!draft.trim()) return;
    setPhrases([...phrases, { text: draft.trim(), pinned: true, uses: 0 }]);
    setDraft('');
  };
  return (
    <div className="sheet" onClick={onClose}>
      <div className="sheet-card" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-head">
          <h2>{t(lang, 'settings')}</h2>
          <button className="icon-btn" onClick={onClose}><Icon.close /></button>
        </div>
        <div className="sheet-body">
          <div className="sheet-section">
            <h3>{t(lang, 'setLanguage')}</h3>
            <p className="section-note">{t(lang, 'setLanguageDesc')}</p>
            <div className="lang-rows">
              {LANGS.map(l => (
                <button
                  key={l.id}
                  className={`lang-row ${lang === l.id ? 'on' : ''}`}
                  onClick={() => setLang(l.id)}
                >
                  <span className="flag">{l.short}</span>
                  <span className="lname">{l.name}</span>
                  {lang === l.id && <span className="tick"><Icon.check /></span>}
                </button>
              ))}
            </div>
            {lang === 'cs' && !voiceOk && (
              <div className="voice-warn"><Icon.speaker /> {t(lang, 'voiceMissing')}</div>
            )}
          </div>

          <div className="sheet-section">
            <h3>{t(lang, 'setVoice')}</h3>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setMoodName')}</div>
                <div className="desc">{t(lang, 'setMoodDesc')}</div>
              </div>
              <button className={`switch ${moodOn ? 'on' : ''}`} onClick={() => setMoodOn(!moodOn)}/>
            </div>
          </div>

          <div className="sheet-section">
            <h3>{t(lang, 'setPinned')}</h3>
            <div className="pinned-list">
              {phrases.map((p, i) => (
                <div className="pinned-row" key={i}>
                  <span className="text">{p.pinned ? '📌 ' : ''}{trPhrase(lang, p.text)}</span>
                  <span className="freq">{p.uses}× {t(lang, 'setUsed')}</span>
                  <button onClick={() => togglePin(i)}>{p.pinned ? t(lang, 'setUnpin') : t(lang, 'setPin')}</button>
                  <button onClick={() => remove(i)}><Icon.close /></button>
                </div>
              ))}
            </div>
            <div className="add-row">
              <input
                placeholder={t(lang, 'setAddPhrase')}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && add()}
              />
              <button onClick={add}>{t(lang, 'setAdd')}</button>
            </div>
          </div>

          <div className="sheet-section">
            <h3>{t(lang, 'setEditing')}</h3>
            <p className="section-note">{t(lang, 'setEditingNote')}</p>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setTapXName')}</div>
                <div className="desc">{t(lang, 'setTapXDesc')}</div>
              </div>
              <button className={`switch ${blkTapX ? 'on' : ''}`} onClick={() => setBlkTapX(!blkTapX)}/>
            </div>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setTapMoveName')}</div>
                <div className="desc">{t(lang, 'setTapMoveDesc')}</div>
              </div>
              <button className={`switch ${blkTapMove ? 'on' : ''}`} onClick={() => setBlkTapMove(!blkTapMove)}/>
            </div>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setSwipeName')}</div>
                <div className="desc">{t(lang, 'setSwipeDesc')}</div>
              </div>
              <button className={`switch ${blkSwipe ? 'on' : ''}`} onClick={() => setBlkSwipe(!blkSwipe)}/>
            </div>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setDragName')}</div>
                <div className="desc">{t(lang, 'setDragDesc')}</div>
              </div>
              <button className={`switch ${blkDrag ? 'on' : ''}`} onClick={() => setBlkDrag(!blkDrag)}/>
            </div>
          </div>

          <div className="sheet-section">
            <h3>{t(lang, 'setAccess')}</h3>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setScanName')}</div>
                <div className="desc">{t(lang, 'setScanDesc')}</div>
              </div>
              <button className={`switch ${scan ? 'on' : ''}`} onClick={() => setScan(!scan)}/>
            </div>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setHapticName')}</div>
                <div className="desc">{t(lang, 'setHapticDesc')}</div>
              </div>
              <button className={`switch ${haptic ? 'on' : ''}`} onClick={() => setHaptic(!haptic)}/>
            </div>
            <div className="toggle-row">
              <div className="info">
                <div className="name">{t(lang, 'setDarkName')}</div>
                <div className="desc">{t(lang, 'setDarkDesc')}</div>
              </div>
              <button className={`switch ${dark ? 'on' : ''}`} onClick={() => setDark(!dark)}/>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------------- MAIN APP ---------------- */

function HandySpeakApp({
  initialMode = 'keyboard',
  initialDark = false,
  initialScan = false,
  initialMessage = '',
  initialMood = 'calm',
  initialCategory = 'feelings',
  showSettings = false,
  showSnap = false,
  snapPhase = 'aim',
  snapTarget = 'sandwich',
  initialRecent = [],
  staticDemo = false,
  initialSwipeRemove = false,
  initialTapX = true,
  initialTapMove = false,
  initialLongPressDrag = false,
  initialSelectedWord = null,
  initialLang = 'en',
  initialMoodEnabled = true,
}) {
  const [mode, setMode]         = useState(initialMode);
  const [text, setText]         = useState(initialMessage);
  const [lang, setLang]         = useState(initialLang);
  const [mood, setMood]         = useState(initialMood);
  const [shift, setShift]       = useState(false);
  const [phrases, setPhrases]   = useState(STARTER_PHRASES);
  const [category, setCategory] = useState(initialCategory);
  const [dark, setDark]         = useState(initialDark);
  const [scan, setScan]         = useState(initialScan);
  const [haptic, setHaptic]     = useState(true);
  const [moodEnabled, setMoodEnabled] = useState(initialMoodEnabled);
  const [blkSwipe, setBlkSwipe]     = useState(initialSwipeRemove);
  const [blkTapX, setBlkTapX]       = useState(initialTapX);
  const [blkTapMove, setBlkTapMove] = useState(initialTapMove);
  const [blkDrag, setBlkDrag]       = useState(initialLongPressDrag);
  const [settingsOpen, setSettingsOpen] = useState(showSettings);
  const [snapOpen, setSnapOpen] = useState(showSnap);
  const [recent, setRecent]     = useState(initialRecent);
  const [speak, speaking] = useSpeak();
  const [scanIndex, setScanIndex] = useState(0);
  const voiceOk = useVoiceAvailable((window.LANGS.find(l => l.id === lang) || {}).voicePrefix || 'en');

  const predictions = useMemo(() => predict(text, lang), [text, lang]);
  // When mood voices are off, speak with one steady, neutral voice.
  const moodObj = moodEnabled ? MOODS.find(m => m.id === mood) : { rate: 1, pitch: 1 };

  // Kid-switchable language. POC: clear the composed message on switch
  // (free-typed text can't be auto-translated), then the whole board +
  // speaking voice flip together.
  const changeLang = useCallback((next) => {
    if (next === lang) return;
    if (haptic && navigator.vibrate) navigator.vibrate(8);
    if (window.speechSynthesis) window.speechSynthesis.cancel();
    setText('');
    setLang(next);
  }, [lang, haptic]);

  const buzz = useCallback(() => {
    if (haptic && navigator.vibrate) navigator.vibrate(8);
  }, [haptic]);

  const handleKey = (k) => {
    buzz();
    if (k === 'BACK') { setText(t => t.slice(0, -1)); return; }
    setText(t => t + k);
    if (shift) setShift(false);
  };
  const handlePick = (word) => {
    buzz();
    setText(t => (t && !t.endsWith(' ') ? t + ' ' : t) + word);
  };
  const handlePredict = (word) => {
    buzz();
    const toks = text.split(' ');
    toks[toks.length - 1] = word;
    setText(toks.join(' ') + ' ');
  };
  const handlePhrase = (phrase) => {
    buzz();
    setText(phrase);
  };
  const handleSpeak = () => {
    buzz();
    speak(text, moodObj, lang);
  };

  const handleSnapAdd = (word, emoji) => {
    buzz();
    setText(t => (t && !t.endsWith(' ') ? t + ' ' : t) + word);
    setRecent(r => [{ word, emoji: emoji || '✨' }, ...r.filter(x => x.word !== word)].slice(0, 6));
    setMode('symbols');
    setSnapOpen(false);
  };

  // Switch scanning: visual demo — cycle the focus through a few keys
  useEffect(() => {
    if (!scan) return;
    const id = setInterval(() => setScanIndex(i => (i + 1) % 10), 900);
    return () => clearInterval(id);
  }, [scan]);

  // Mark scan-focus on a rotating element
  useEffect(() => {
    if (!scan) return;
    const els = document.querySelectorAll('.tablet[data-id="' + (window.__tabletId || 'main') + '"] .key, .tablet[data-id="' + (window.__tabletId || 'main') + '"] .phrase-chip');
    // simple: highlight one key
  }, [scanIndex, scan]);

  return (
    <div className={`tablet ${dark ? 'dark' : ''}`}>
      <div className="screen">
        <TopBar mode={mode} setMode={setMode} onOpenSettings={() => setSettingsOpen(true)} onOpenSnap={() => setSnapOpen(true)} dark={dark} lang={lang} setLang={changeLang}/>
        {moodEnabled && <MoodStrip value={mood} onChange={(m) => { buzz(); setMood(m); }} lang={lang} />}
        <MessageBar
          text={text}
          mode={mode}
          mood={mood}
          onClear={() => setText('')}
          onSpeak={handleSpeak}
          speaking={speaking}
          blockSettings={{ swipeRemove: blkSwipe, tapX: blkTapX, tapMove: blkTapMove, longPressDrag: blkDrag }}
          onChangeText={setText}
          initialSelectedWord={initialSelectedWord}
          lang={lang}
          moodEnabled={moodEnabled}
        />
        <PhraseStrip phrases={phrases} onPick={handlePhrase} lang={lang} />

        {mode === 'keyboard'
          ? <Keyboard onKey={handleKey} shift={shift} setShift={setShift} predictions={predictions} onPredict={handlePredict} lang={lang} />
          : <SymbolBoard category={category} setCategory={setCategory} onPick={handlePick} recent={recent} onOpenSnap={() => setSnapOpen(true)} lang={lang} />
        }

        {scan && (
          <div className="scan-banner">
            <span className="dot"/> Switch scanning active · advancing every 0.9s
          </div>
        )}

        {settingsOpen && (
          <SettingsSheet
            phrases={phrases} setPhrases={setPhrases}
            dark={dark} setDark={setDark}
            scan={scan} setScan={setScan}
            haptic={haptic} setHaptic={setHaptic}
            blkSwipe={blkSwipe} setBlkSwipe={setBlkSwipe}
            blkTapX={blkTapX} setBlkTapX={setBlkTapX}
            blkTapMove={blkTapMove} setBlkTapMove={setBlkTapMove}
            blkDrag={blkDrag} setBlkDrag={setBlkDrag}
            onClose={() => setSettingsOpen(false)}
            lang={lang} setLang={changeLang} voiceOk={voiceOk}
            moodOn={moodEnabled} setMoodOn={setMoodEnabled}
          />
        )}

        {snapOpen && (
          <SnapSay
            onAdd={handleSnapAdd}
            onClose={() => setSnapOpen(false)}
            initialPhase={snapPhase}
            initialTargetId={snapTarget}
            lang={lang}
          />
        )}
      </div>
    </div>
  );
}

window.HandySpeakApp = HandySpeakApp;
window.MOODS = MOODS;
window.CATEGORIES = CATEGORIES;
window.SNAP_TARGETS = SNAP_TARGETS;
window.SnapSay = SnapSay;
