/* HandySpeak — Design System artboards (tokens / type / spacing) */

function TokenSwatches({ items }) {
  return (
    <div className="swatch-grid">
      {items.map(it => (
        <div className="sw" key={it.name}>
          <div className="chip" style={{ '--c': it.value }}/>
          <div className="meta">
            <div className="name">{it.name}</div>
            <div className="val">{it.token}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

function DSColors({ dark }) {
  const surfaces = [
    { name: 'Background',  token: '--bg',           value: 'var(--bg)' },
    { name: 'Surface',     token: '--surface',      value: 'var(--surface)' },
    { name: 'Surface 2',   token: '--surface-2',    value: 'var(--surface-2)' },
    { name: 'Surface 3',   token: '--surface-3',    value: 'var(--surface-3)' },
    { name: 'Divider',     token: '--divider',      value: 'var(--divider)' },
    { name: 'Ink',         token: '--ink',          value: 'var(--ink)' },
    { name: 'Ink 2',       token: '--ink-2',        value: 'var(--ink-2)' },
    { name: 'Ink 3',       token: '--ink-3',        value: 'var(--ink-3)' },
  ];
  const actions = [
    { name: 'Primary (Speak)',  token: '--primary',     value: 'var(--primary)' },
    { name: 'Primary press',    token: '--primary-press', value: 'var(--primary-press)' },
    { name: 'Primary soft',     token: '--primary-soft', value: 'var(--primary-soft)' },
    { name: 'Accent',           token: '--accent',      value: 'var(--accent)' },
    { name: 'Accent soft',      token: '--accent-soft', value: 'var(--accent-soft)' },
  ];
  const moods = [
    { name: 'Happy',   token: '--mood-happy',   value: 'var(--mood-happy)' },
    { name: 'Excited', token: '--mood-excited', value: 'var(--mood-excited)' },
    { name: 'Calm',    token: '--mood-calm',    value: 'var(--mood-calm)' },
    { name: 'Curious', token: '--mood-curious', value: 'var(--mood-curious)' },
    { name: 'Sad',     token: '--mood-sad',     value: 'var(--mood-sad)' },
    { name: 'Angry',   token: '--mood-angry',   value: 'var(--mood-angry)' },
  ];
  return (
    <div className={`ds ${dark ? 'ds-dark' : 'ds-light'}`}>
      <h1>Color Tokens · {dark ? 'Dark' : 'Light'}</h1>
      <div className="sub">Warm-neutral surfaces + vivid action green + six harmonized mood hues (chroma 0.10–0.18).</div>

      <h2>Surfaces &amp; Ink</h2>
      <TokenSwatches items={surfaces}/>

      <h2>Actions</h2>
      <TokenSwatches items={actions}/>

      <h2>Mood palette</h2>
      <TokenSwatches items={moods}/>
    </div>
  );
}

function DSType() {
  return (
    <div className="ds ds-light">
      <h1>Typography</h1>
      <div className="sub">Fredoka (display, friendly rounded letterforms) pairs with Nunito (humanist sans, exceptional readability for early readers).</div>

      <h2>Display · Fredoka</h2>
      <div className="type-stack">
        <div className="type-row">
          <div className="tag">Fredoka 600 · 40px</div>
          <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:600, fontSize:40, letterSpacing:'-0.01em'}}>HandySpeak</div>
        </div>
        <div className="type-row">
          <div className="tag">Fredoka 500 · 28px</div>
          <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:500, fontSize:28}}>I want to play outside</div>
        </div>
        <div className="type-row">
          <div className="tag">Fredoka 500 · 26px (keys)</div>
          <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:500, fontSize:26}}>q w e r t y</div>
        </div>
      </div>

      <h2>Body · Nunito</h2>
      <div className="type-stack">
        <div className="type-row">
          <div className="tag">Nunito 700 · 34px (message)</div>
          <div style={{fontFamily:"'Nunito',sans-serif", fontWeight:700, fontSize:34, letterSpacing:'-0.01em'}}>I'm hungry</div>
        </div>
        <div className="type-row">
          <div className="tag">Nunito 700 · 17px (chip)</div>
          <div style={{fontFamily:"'Nunito',sans-serif", fontWeight:700, fontSize:17}}>Bathroom please</div>
        </div>
        <div className="type-row">
          <div className="tag">Nunito 800 · 13px / 0.08em (label)</div>
          <div style={{fontFamily:"'Nunito',sans-serif", fontWeight:800, fontSize:13, letterSpacing:'0.08em', textTransform:'uppercase', color:'var(--ink-3)'}}>My Phrases</div>
        </div>
        <div className="type-row">
          <div className="tag">Nunito 600 · 13px (meta)</div>
          <div style={{fontFamily:"'Nunito',sans-serif", fontWeight:600, fontSize:13, color:'var(--ink-3)'}}>Calm voice · 4 words</div>
        </div>
      </div>
    </div>
  );
}

function DSSpacing() {
  return (
    <div className="ds ds-light">
      <h1>Tap targets, radii &amp; rhythm</h1>
      <div className="sub">Min tap target is 72×72 (spec asks 60×60). Generous radii keep edges friendly. 4 / 8 / 12 / 16 / 24 / 32 / 48 spacing scale.</div>

      <h2>Tap targets (min 72)</h2>
      <div className="target-row">
        <div className="target" style={{width:72,  height:72}}>72</div>
        <div className="target" style={{width:88,  height:88}}>88 · key</div>
        <div className="target" style={{width:130, height:130}}>130 · symbol card</div>
        <div className="target" style={{width:220, height:88}}>220×88 · Speak</div>
      </div>

      <h2>Radii</h2>
      <div className="target-row">
        <div className="target" style={{width:120, height:80, borderRadius:14}}>14 · chip inner</div>
        <div className="target" style={{width:120, height:80, borderRadius:18}}>18 · key</div>
        <div className="target" style={{width:120, height:80, borderRadius:22}}>22 · card</div>
        <div className="target" style={{width:120, height:80, borderRadius:24}}>24 · message</div>
        <div className="target" style={{width:120, height:80, borderRadius:999}}>999 · pill</div>
      </div>

      <h2>Spacing scale</h2>
      <div className="target-row">
        {[4,8,12,16,20,24,32,40,48].map(s => (
          <div key={s} className="target" style={{width:s+30, height:60, borderStyle:'solid', background:'var(--accent-soft)', borderColor:'var(--accent)'}}>{s}</div>
        ))}
      </div>

      <h2>Elevation</h2>
      <div className="target-row">
        <div style={{width:160, height:90, borderRadius:18, background:'var(--surface)', boxShadow:'var(--shadow-sm)', display:'grid', placeItems:'center', fontFamily:'ui-monospace', fontSize:12, color:'var(--ink-2)'}}>shadow-sm · keys</div>
        <div style={{width:160, height:90, borderRadius:18, background:'var(--surface)', boxShadow:'var(--shadow-md)', display:'grid', placeItems:'center', fontFamily:'ui-monospace', fontSize:12, color:'var(--ink-2)'}}>shadow-md · cards</div>
        <div style={{width:160, height:90, borderRadius:18, background:'var(--primary)', color:'white', boxShadow:'var(--shadow-lg)', display:'grid', placeItems:'center', fontFamily:'ui-monospace', fontSize:12}}>shadow-lg · Speak</div>
      </div>
    </div>
  );
}

function DSMoodMatrix() {
  return (
    <div className="ds ds-light">
      <h1>Mood → Voice mapping</h1>
      <div className="sub">Selecting a mood doesn't just decorate — it adjusts the Web Speech synthesis pitch &amp; rate so the spoken sentence carries the feeling.</div>

      <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:16, marginTop:16}}>
        {window.MOODS.map(m => (
          <div key={m.id} style={{
            background:'var(--surface)',
            border:'1.5px solid var(--divider)',
            borderRadius:22,
            padding:'18px 18px 16px',
            boxShadow:'var(--shadow-sm)',
          }}>
            <div style={{display:'flex', alignItems:'center', gap:12, marginBottom:14}}>
              <div style={{
                width:54, height:54, borderRadius:'50%',
                background:`var(--mood-${m.id})`,
                display:'grid', placeItems:'center',
                fontSize:30,
              }}>{m.emoji}</div>
              <div>
                <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:600, fontSize:22, color:'var(--ink)'}}>{m.label}</div>
                <div style={{fontFamily:'ui-monospace,monospace', fontSize:11, color:'var(--ink-3)'}}>--mood-{m.id}</div>
              </div>
            </div>
            <div style={{display:'flex', gap:10}}>
              <div style={{flex:1, padding:'10px 12px', background:'var(--surface-2)', borderRadius:12}}>
                <div style={{fontSize:11, fontWeight:800, letterSpacing:'.08em', textTransform:'uppercase', color:'var(--ink-3)'}}>Rate</div>
                <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:600, fontSize:22}}>{m.rate.toFixed(2)}×</div>
              </div>
              <div style={{flex:1, padding:'10px 12px', background:'var(--surface-2)', borderRadius:12}}>
                <div style={{fontSize:11, fontWeight:800, letterSpacing:'.08em', textTransform:'uppercase', color:'var(--ink-3)'}}>Pitch</div>
                <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:600, fontSize:22}}>{m.pitch.toFixed(2)}×</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function DSPrinciples() {
  const principles = [
    { title: 'Every press succeeds', body: 'Big, soft, tactile keys with strong borders + an under-shadow that compresses on tap. A child should never wonder if they hit something.' },
    { title: 'Mood is part of composing', body: 'The mood strip sits above the message bar — chosen before "Speak", not after. The selected mood colors the voice chip so it stays visible while typing.' },
    { title: 'Two ways in, one message out', body: 'Switching between Keyboard and Symbols preserves whatever is in the message bar. The same Speak button, mood, and phrase strip work in both modes.' },
    { title: 'Frequency beats discovery', body: 'My Phrases auto-promotes the child\'s most-used utterances. Parents can pin specifics (e.g. "I need my inhaler") that should always be reachable in one tap.' },
    { title: 'Color carries meaning', body: 'Action green = "I am about to be heard." Mood hues stay consistent across the strip, voice chip, message border, and speak halo. Categories on the symbol board each own a hue.' },
    { title: 'No chrome, all content', body: 'No headers, page titles, or in-app branding past the launch bar. The screen is the message bar, the mood, the phrases, the keys. That\'s it.' },
  ];
  return (
    <div className="ds ds-light">
      <h1>Design Principles</h1>
      <div className="sub">The decisions every screen and component is answering to.</div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:16, marginTop:16}}>
        {principles.map((p, i) => (
          <div key={i} style={{
            background:'var(--surface)',
            border:'1.5px solid var(--divider-soft)',
            borderRadius:22,
            padding:'18px 22px 20px',
            boxShadow:'var(--shadow-sm)',
          }}>
            <div style={{
              fontFamily: "'Nunito',sans-serif", fontWeight:900, fontSize:12,
              letterSpacing:'.08em', textTransform:'uppercase', color:'var(--ink-3)',
              marginBottom: 8,
            }}>{String(i+1).padStart(2,'0')}</div>
            <div style={{fontFamily:"'Fredoka',sans-serif", fontWeight:600, fontSize:22, color:'var(--ink)', marginBottom:8}}>{p.title}</div>
            <div style={{fontFamily:"'Nunito',sans-serif", fontWeight:600, fontSize:15, lineHeight:1.45, color:'var(--ink-2)'}}>{p.body}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

window.DSColors = DSColors;
window.DSType = DSType;
window.DSSpacing = DSSpacing;
window.DSMoodMatrix = DSMoodMatrix;
window.DSPrinciples = DSPrinciples;
