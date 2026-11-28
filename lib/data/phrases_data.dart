import '../core/app_language.dart';
import 'phrase.dart';

/// Seed phrase sets — genuinely per-language and independent
/// (IMPLEMENTATION_PLAN §6.1.4). English from the prototype's
/// `STARTER_PHRASES`; Czech from `PHRASES_CS`, seeded as its own list.
///
/// Schema v2 (M5/M2, R1 review): every seed phrase carries a stable id
/// (0..7 per language — [PhrasesController.add] continues above the list's
/// highest id), and the fabricated `uses` counts are gone (M2, owner
/// decision 2026-11-28 — the counter was never incremented and only ever
/// displayed these numbers).
const Map<AppLanguage, List<Phrase>> kSeedPhrases = {
  AppLanguage.en: [
    Phrase(id: 0, text: 'I need help', pinned: true),
    Phrase(id: 1, text: 'Bathroom please', pinned: true),
    Phrase(id: 2, text: "I'm hungry", pinned: true),
    Phrase(id: 3, text: "I don't understand", pinned: true),
    Phrase(id: 4, text: 'Thank you', pinned: false),
    Phrase(id: 5, text: 'Yes please', pinned: false),
    Phrase(id: 6, text: 'Can I play?', pinned: false),
    Phrase(id: 7, text: 'All done', pinned: false),
  ],
  AppLanguage.cs: [
    Phrase(id: 0, text: 'Potřebuju pomoc', pinned: true),
    Phrase(id: 1, text: 'Záchod prosím', pinned: true),
    Phrase(id: 2, text: 'Mám hlad', pinned: true),
    Phrase(id: 3, text: 'Nerozumím', pinned: true),
    Phrase(id: 4, text: 'Děkuji', pinned: false),
    Phrase(id: 5, text: 'Ano prosím', pinned: false),
    Phrase(id: 6, text: 'Můžu si hrát?', pinned: false),
    Phrase(id: 7, text: 'Hotovo', pinned: false),
  ],
  AppLanguage.uk: [
    Phrase(id: 0, text: 'Мені потрібна допомога', pinned: true),
    Phrase(id: 1, text: 'В туалет, будь ласка', pinned: true),
    Phrase(id: 2, text: 'Я голодний', pinned: true),
    Phrase(id: 3, text: 'Я не розумію', pinned: true),
    Phrase(id: 4, text: 'Дякую', pinned: false),
    Phrase(id: 5, text: 'Так, будь ласка', pinned: false),
    Phrase(id: 6, text: 'Можна мені погратися?', pinned: false),
    Phrase(id: 7, text: 'Готово', pinned: false),
  ],
};
