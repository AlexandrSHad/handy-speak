/* HandySpeak — i18n layer
   POC scope: English (default) + Czech, kid-switchable.
   Design notes:
     • The emoji on a tile is language-independent; only the *word*
       under it changes. So translation is a parallel label/speech map
       layered over the same symbol grid — the board never rebuilds.
     • Every kid-facing surface resolves its label & spoken word through
       here, so one toggle flips both the UI and what the speech engine
       says.
*/

const LANGS = [
  { id: 'en', short: 'EN', name: 'English', bcp47: 'en-US', voicePrefix: 'en' },
  { id: 'cs', short: 'CZ', name: 'Čeština', bcp47: 'cs-CZ', voicePrefix: 'cs' },
];

/* ---- UI chrome strings ---- */
const UI = {
  en: {
    keyboard: 'Keyboard',
    symbols: 'Symbols',
    snap: 'Snap & Say',
    settings: 'Settings',
    voiceLabel: 'Voice',
    myPhrases: 'My Phrases',
    speak: 'Speak',
    speaking: 'Speaking…',
    clear: 'Clear',
    voiceSuffix: 'voice',
    placeholder: 'Tap keys or symbols to compose…',
    justSnapped: 'Just snapped',
    space: 'space',
    // snap & say
    snapPoint: 'Point at something — we’ll find the word',
    snapLooking: 'Looking…',
    snapISeeA: 'I see a',
    snapSure: 'sure',
    snapNotQuite: 'Not quite?',
    snapTryAgain: 'Try again',
    snapHear: 'Hear it',
    snapAdd: 'Add',
    snapDemo: 'Demo aim',
    // settings
    setPinned: 'Parent · Pinned Phrases',
    setUsed: 'used',
    setPin: 'Pin',
    setUnpin: 'Unpin',
    setAddPhrase: 'Add a phrase the child can quickly speak…',
    setAdd: 'Add',
    setEditing: 'Editing the message',
    setEditingNote: 'How a child can fix the sentence by changing word tiles. Tapping a tile is always available; the others are gestures layered on top.',
    setTapXName: 'Tap a word to remove it',
    setTapXDesc: 'Tap a tile to reveal a ✕. The safe, switch-friendly default.',
    setTapMoveName: 'Tap a word to move it',
    setTapMoveDesc: 'Reveal ◀ ▶ arrows to shift a word left or right.',
    setSwipeName: 'Swipe up to remove',
    setSwipeDesc: 'Flick a tile upward to throw the word away. Always undoable.',
    setDragName: 'Press & hold to reorder',
    setDragDesc: 'Hold a tile to lift it, then drag to a new spot. Higher motor demand.',
    setAccess: 'Accessibility',
    setScanName: 'Switch Scanning',
    setScanDesc: 'Auto-advance highlight; press any key or external switch to select.',
    setHapticName: 'Haptic feedback',
    setHapticDesc: 'Vibrate on key/card press (where supported).',
    setDarkName: 'Dark mode',
    setDarkDesc: 'Lower-contrast surfaces for low-light use.',
    setLanguage: 'Language',
    setLanguageDesc: 'Switch the whole board and the speaking voice. Kids can also tap EN / CZ in the top bar.',
    setVoice: 'Speaking voice',
    setMoodName: 'Mood voices',
    setMoodDesc: 'Let the child pick a mood that changes the voice’s pitch and speed. Off uses one steady voice.',
    voiceMissing: 'No Czech voice on this tablet yet — add one in your device’s speech settings for the best pronunciation.',
  },
  cs: {
    keyboard: 'Klávesnice',
    symbols: 'Symboly',
    snap: 'Vyfoť a řekni',
    settings: 'Nastavení',
    voiceLabel: 'Hlas',
    myPhrases: 'Moje fráze',
    speak: 'Mluvit',
    speaking: 'Mluvím…',
    clear: 'Smazat',
    voiceSuffix: 'hlas',
    placeholder: 'Ťukej na klávesy nebo symboly…',
    justSnapped: 'Právě vyfoceno',
    space: 'mezera',
    // snap & say
    snapPoint: 'Namiř na něco — najdeme slovo',
    snapLooking: 'Hledám…',
    snapISeeA: 'Vidím',
    snapSure: 'jistota',
    snapNotQuite: 'Není to ono?',
    snapTryAgain: 'Zkusit znovu',
    snapHear: 'Přehrát',
    snapAdd: 'Přidat',
    snapDemo: 'Ukázka',
    // settings
    setPinned: 'Rodič · Připnuté fráze',
    setUsed: 'použito',
    setPin: 'Připnout',
    setUnpin: 'Odepnout',
    setAddPhrase: 'Přidej frázi, kterou dítě rychle řekne…',
    setAdd: 'Přidat',
    setEditing: 'Úpravy zprávy',
    setEditingNote: 'Jak může dítě opravit větu změnou dlaždic se slovy. Ťuknutí na dlaždici jde vždy; ostatní jsou gesta navíc.',
    setTapXName: 'Ťuknutím slovo odebrat',
    setTapXDesc: 'Ťukni na dlaždici a objeví se ✕. Bezpečné, vhodné i pro spínače.',
    setTapMoveName: 'Ťuknutím slovo přesunout',
    setTapMoveDesc: 'Zobrazí šipky ◀ ▶ pro posun slova doleva nebo doprava.',
    setSwipeName: 'Smazat švihnutím nahoru',
    setSwipeDesc: 'Švihni dlaždicí nahoru a slovo zahodíš. Vždy lze vrátit.',
    setDragName: 'Podržením přeskupit',
    setDragDesc: 'Podrž dlaždici, zvedni ji a přetáhni jinam. Náročnější na pohyb.',
    setAccess: 'Přístupnost',
    setScanName: 'Skenování spínačem',
    setScanDesc: 'Zvýraznění se samo posouvá; vyber stiskem klávesy nebo spínače.',
    setHapticName: 'Vibrace',
    setHapticDesc: 'Zavibruje při stisku klávesy/dlaždice (kde to jde).',
    setDarkName: 'Tmavý režim',
    setDarkDesc: 'Méně kontrastní plochy pro použití v šeru.',
    setLanguage: 'Jazyk',
    setLanguageDesc: 'Přepne celou tabulku i mluvící hlas. Děti mohou ťuknout i na EN / CZ nahoře.',
    setVoice: 'Mluvený hlas',
    setMoodName: 'Nálady hlasu',
    setMoodDesc: 'Dítě si může vybrat náladu, která mění výšku a rychlost hlasu. Vypnuto = jeden stálý hlas.',
    voiceMissing: 'V tabletu zatím není český hlas — přidej ho v nastavení řeči zařízení pro nejlepší výslovnost.',
  },
};

/* ---- Vocabulary: English word (id) -> Czech ---- */
const WORDS_CS = {
  // feelings
  happy: 'šťastný', sad: 'smutný', tired: 'unavený', scared: 'vyděšený',
  excited: 'nadšený', angry: 'naštvaný', love: 'láska', calm: 'klidný',
  silly: 'bláznivý', shy: 'stydlivý',
  // food
  apple: 'jablko', water: 'voda', milk: 'mléko', pizza: 'pizza',
  banana: 'banán', cookie: 'sušenka', sandwich: 'sendvič', pasta: 'těstoviny',
  cereal: 'cereálie', juice: 'džus',
  // school
  book: 'kniha', pencil: 'tužka', teacher: 'učitelka', art: 'výtvarka',
  math: 'matika', recess: 'přestávka', music: 'hudba', computer: 'počítač',
  science: 'věda', reading: 'čtení',
  // family
  mom: 'máma', dad: 'táta', sister: 'sestra', brother: 'bratr',
  grandma: 'babička', grandpa: 'děda', baby: 'miminko', dog: 'pes',
  cat: 'kočka', friend: 'kamarád',
  // activities
  play: 'hrát', draw: 'kreslit', run: 'běhat', jump: 'skákat',
  sleep: 'spát', sing: 'zpívat', dance: 'tancovat', swim: 'plavat',
  read: 'číst', build: 'stavět',
  // places
  home: 'domov', school: 'škola', park: 'park', store: 'obchod',
  bathroom: 'záchod', kitchen: 'kuchyně', outside: 'venku', car: 'auto',
  beach: 'pláž', doctor: 'doktor',
  // numbers
  one: 'jedna', two: 'dvě', three: 'tři', four: 'čtyři', five: 'pět',
  more: 'víc', less: 'míň', all: 'všechno', none: 'nic', some: 'trochu',
  // greetings
  hello: 'ahoj', goodbye: 'pa pa', please: 'prosím', 'thank you': 'děkuji',
  sorry: 'promiň', yes: 'ano', no: 'ne', okay: 'dobře',
  'good morning': 'dobré ráno', 'good night': 'dobrou noc',
  // snap targets + alts
  ball: 'míč', cup: 'hrnek',
  bread: 'chléb', wrap: 'tortilla', lunch: 'oběd',
  puppy: 'štěně', pet: 'mazlíček',
  football: 'fotbal', soccer: 'fotbal',
  novel: 'román', story: 'příběh',
  fruit: 'ovoce', snack: 'svačina',
  drink: 'pití', glass: 'sklenice',
};

const CATS_CS = {
  feelings: 'Pocity', food: 'Jídlo', school: 'Škola', family: 'Rodina',
  activities: 'Činnosti', places: 'Místa', numbers: 'Čísla', greetings: 'Ahoj',
};

const MOODS_CS = {
  happy: 'Šťastný', excited: 'Nadšený', calm: 'Klidný',
  curious: 'Zvědavý', sad: 'Smutný', angry: 'Naštvaný',
};

const PHRASES_CS = {
  'I need help': 'Potřebuju pomoc',
  'Bathroom please': 'Záchod prosím',
  "I'm hungry": 'Mám hlad',
  "I don't understand": 'Nerozumím',
  'Thank you': 'Děkuji',
  'Yes please': 'Ano prosím',
  'Can I play?': 'Můžu si hrát?',
  'All done': 'Hotovo',
};

/* ---- tiny Czech prediction table (keyboard is secondary in AAC) ---- */
const PREDICT_CS = {
  '':       ['Já',    'Chci',   'Můžu'],
  'ch':     ['chci',  'chleba', 'chvíli'],
  'chc':    ['chci',  'chceš',  'chceme'],
  'ma':     ['mám',   'máma',   'malý'],
  'mam':    ['mám',   'máma'],
  'po':     ['pomoc', 'potom',  'počkej'],
  'pom':    ['pomoc', 'pomoz',  'pomalu'],
  'ano':    ['ano'],
  'ne':     ['ne',    'nechci', 'nevím'],
  'pr':     ['prosím','proč',   'pryč'],
  'pro':    ['prosím','proč',   'protože'],
  'de':     ['děkuji','děti',   'den'],
  'dek':    ['děkuji'],
  'hl':     ['hlad',  'hledat'],
};

/* ---- resolvers ---- */
function t(lang, key) {
  return (UI[lang] || UI.en)[key] ?? UI.en[key] ?? key;
}
function trWord(lang, w) {
  if (lang !== 'cs' || !w) return w;
  return WORDS_CS[w.toLowerCase()] || w;
}
function trCat(lang, id, fallback) {
  return lang === 'cs' ? (CATS_CS[id] || fallback) : fallback;
}
function trMood(lang, id, fallback) {
  return lang === 'cs' ? (MOODS_CS[id] || fallback) : fallback;
}
function trPhrase(lang, text) {
  return lang === 'cs' ? (PHRASES_CS[text] || text) : text;
}
/* Czech word count is gender/number-sensitive: 1 slovo · 2–4 slova · 5+ slov */
function wordCount(lang, n) {
  if (lang === 'cs') {
    if (n === 1) return '1 slovo';
    if (n >= 2 && n <= 4) return n + ' slova';
    return n + ' slov';
  }
  return n + (n === 1 ? ' word' : ' words');
}

Object.assign(window, {
  LANGS, t, trWord, trCat, trMood, trPhrase, wordCount, PREDICT_CS,
});
