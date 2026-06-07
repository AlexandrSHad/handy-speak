/* HandySpeak — Design Canvas root */

function Root() {
  const { DesignCanvas, DCSection, DCArtboard, HandySpeakApp, DSColors, DSType, DSSpacing, DSMoodMatrix, DSPrinciples } = window;
  return (
    <DesignCanvas>
      <DCSection id="multilingual" title="Multilingual · EN ⇄ CZ" subtitle="Kid-switchable language in the top bar — one tap flips the whole board, the prediction bar, and the speaking voice. POC: English + Czech.">
        <DCArtboard id="ml-en" label="Symbols · English" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialLang="en" initialMessage="I want apple" initialMood="happy" initialCategory="food"/>
        </DCArtboard>

        <DCArtboard id="ml-cs" label="Symbols · Čeština" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialLang="cs" initialMessage="máma kniha" initialMood="happy" initialCategory="family"/>
        </DCArtboard>

        <DCArtboard id="ml-cs-keyboard" label="Keyboard + prediction · Čeština" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialLang="cs" initialMessage="pom" initialMood="calm"/>
        </DCArtboard>

        <DCArtboard id="ml-cs-settings" label="Settings · Jazyk + voice note" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialLang="cs" initialMessage="" initialMood="calm" showSettings={true}/>
        </DCArtboard>

        <DCArtboard id="ml-cs-snap" label="Snap & Say · Čeština" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialLang="cs" initialMessage="" initialMood="curious" showSnap={true} snapPhase="result" snapTarget="apple"/>
        </DCArtboard>
      </DCSection>

      <DCSection id="snap-say" title="Snap &amp; Say" subtitle="Camera-driven word capture · bridges the gap when the right icon isn't in the library">
        <DCArtboard id="snap-aim" label="Aim · viewfinder" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want a" initialMood="curious" showSnap={true} snapPhase="aim" snapTarget="sandwich"/>
        </DCArtboard>

        <DCArtboard id="snap-analyzing" label="Analyzing" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want a" initialMood="curious" showSnap={true} snapPhase="analyzing" snapTarget="dog"/>
        </DCArtboard>

        <DCArtboard id="snap-result" label="Result · sandwich detected" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want a" initialMood="curious" showSnap={true} snapPhase="result" snapTarget="sandwich"/>
        </DCArtboard>

        <DCArtboard id="snap-added" label="After adding · recent strip" width={1280} height={920}>
          <HandySpeakApp
            initialMode="symbols"
            initialMessage="I want a sandwich"
            initialMood="happy"
            initialCategory="food"
            initialRecent={[
              { word: "sandwich", emoji: "🥪" },
              { word: "apple",    emoji: "🍎" },
              { word: "dog",      emoji: "🐕" },
            ]}
          />
        </DCArtboard>
      </DCSection>

      <DCSection id="tablet-primary" title="Tablet · Primary" subtitle="iPad landscape · 1280×920 · Two composition modes sharing one message bar">
        <DCArtboard id="keyboard-light" label="Keyboard mode · Light" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialMessage="I want to play" initialMood="excited"/>
        </DCArtboard>

        <DCArtboard id="symbols-light" label="Symbol board · Light" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I feel" initialMood="happy" initialCategory="feelings"/>
        </DCArtboard>

        <DCArtboard id="keyboard-dark" label="Keyboard mode · Dark" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialDark={true} initialMessage="goodnight mom" initialMood="calm"/>
        </DCArtboard>

        <DCArtboard id="symbols-categories" label="Symbol board · Food" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I'm hungry I want" initialMood="curious" initialCategory="food"/>
        </DCArtboard>
      </DCSection>

      <DCSection id="states" title="States &amp; Accessibility" subtitle="The same product under different access modes and conditions">
        <DCArtboard id="scanning" label="Switch scanning active" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialScan={true} initialMessage="Yes I need" initialMood="calm"/>
        </DCArtboard>

        <DCArtboard id="settings-sheet" label="Parent · Settings sheet" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialMessage="I need help" showSettings={true} initialMood="calm"/>
        </DCArtboard>

        <DCArtboard id="empty" label="Empty state · First launch" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="" initialMood="calm" initialCategory="greetings"/>
        </DCArtboard>

        <DCArtboard id="mood-off" label="Mood voices off · steady voice" width={1280} height={920}>
          <HandySpeakApp initialMode="keyboard" initialMoodEnabled={false} initialMessage="I need help" initialMood="calm"/>
        </DCArtboard>
      </DCSection>

      <DCSection id="word-blocks" title="Editable Word Blocks" subtitle="Every word is a tile you can fix · tap to reveal ✕, swipe up to toss, hold to reorder · all four affordances toggle in Settings">
        <DCArtboard id="blocks-tapx" label="Tap a word · ✕ revealed" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want to play outside" initialMood="excited" initialCategory="feelings" initialTapX={true} initialSelectedWord={3}/>
        </DCArtboard>

        <DCArtboard id="blocks-move" label="Tap a word · move arrows" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want to play outside" initialMood="curious" initialCategory="feelings" initialTapX={true} initialTapMove={true} initialSelectedWord={2}/>
        </DCArtboard>

        <DCArtboard id="blocks-settings" label="Parent · choose affordances" width={1280} height={920}>
          <HandySpeakApp initialMode="symbols" initialMessage="I want to play outside" initialMood="calm" showSettings={true}/>
        </DCArtboard>
      </DCSection>

      <DCSection id="design-system" title="Design System" subtitle="Tokens, type, spacing — the rules every screen follows">
        <DCArtboard id="principles" label="Principles" width={960} height={760}>
          <DSPrinciples />
        </DCArtboard>

        <DCArtboard id="mood-matrix" label="Mood → Voice mapping" width={960} height={760}>
          <DSMoodMatrix />
        </DCArtboard>

        <DCArtboard id="colors-light" label="Colors · Light" width={960} height={920}>
          <DSColors dark={false}/>
        </DCArtboard>

        <DCArtboard id="colors-dark" label="Colors · Dark" width={960} height={920}>
          <DSColors dark={true}/>
        </DCArtboard>

        <DCArtboard id="type" label="Typography" width={960} height={760}>
          <DSType />
        </DCArtboard>

        <DCArtboard id="spacing" label="Tap targets · radii · elevation" width={960} height={760}>
          <DSSpacing />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Root />);
