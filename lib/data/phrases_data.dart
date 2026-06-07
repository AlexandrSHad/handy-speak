import '../core/app_language.dart';
import '../state/phrases_controller.dart';

/// Seed phrase sets — genuinely per-language and independent
/// (IMPLEMENTATION_PLAN §6.1.4). English from the prototype's
/// `STARTER_PHRASES`; Czech from `PHRASES_CS`, seeded as its own list.
const Map<AppLanguage, List<Phrase>> kSeedPhrases = {
  AppLanguage.en: [
    Phrase(text: 'I need help', pinned: true, uses: 42),
    Phrase(text: 'Bathroom please', pinned: true, uses: 31),
    Phrase(text: "I'm hungry", pinned: true, uses: 28),
    Phrase(text: "I don't understand", pinned: true, uses: 19),
    Phrase(text: 'Thank you', pinned: false, uses: 24),
    Phrase(text: 'Yes please', pinned: false, uses: 22),
    Phrase(text: 'Can I play?', pinned: false, uses: 14),
    Phrase(text: 'All done', pinned: false, uses: 12),
  ],
  AppLanguage.cs: [
    Phrase(text: 'Potřebuju pomoc', pinned: true, uses: 42),
    Phrase(text: 'Záchod prosím', pinned: true, uses: 31),
    Phrase(text: 'Mám hlad', pinned: true, uses: 28),
    Phrase(text: 'Nerozumím', pinned: true, uses: 19),
    Phrase(text: 'Děkuji', pinned: false, uses: 24),
    Phrase(text: 'Ano prosím', pinned: false, uses: 22),
    Phrase(text: 'Můžu si hrát?', pinned: false, uses: 14),
    Phrase(text: 'Hotovo', pinned: false, uses: 12),
  ],
};
