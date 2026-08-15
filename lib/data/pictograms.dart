import '../core/app_language.dart';

/// A picture symbol: emoji is language-neutral; label + spoken word vary.
/// Ported verbatim from the prototype's `PICTOGRAMS` + `WORDS_CS`
/// (IMPLEMENTATION_PLAN §6 / §6.2).
class Pictogram {
  final String emoji;
  final String en;
  final String cs;
  final String uk;
  const Pictogram(this.emoji, this.en, this.cs, this.uk);

  String word(AppLanguage l) => switch (l) {
        AppLanguage.en => en,
        AppLanguage.cs => cs,
        AppLanguage.uk => uk,
      };
}

/// Pictograms grouped by category id. 8 categories × 10 symbols.
const Map<String, List<Pictogram>> kPictograms = {
  'feelings': [
    Pictogram('😊', 'happy', 'šťastný', 'щасливий'),
    Pictogram('😢', 'sad', 'smutný', 'сумний'),
    Pictogram('😴', 'tired', 'unavený', 'втомлений'),
    Pictogram('😨', 'scared', 'vyděšený', 'наляканий'),
    Pictogram('🤩', 'excited', 'nadšený', 'радісний'),
    Pictogram('😠', 'angry', 'naštvaný', 'сердитий'),
    Pictogram('❤️', 'love', 'láska', 'любов'),
    Pictogram('😌', 'calm', 'klidný', 'спокійний'),
    Pictogram('🤪', 'silly', 'bláznivý', 'кумедний'),
    Pictogram('🙈', 'shy', 'stydlivý', 'сором’язливий'),
  ],
  'food': [
    Pictogram('🍎', 'apple', 'jablko', 'яблуко'),
    Pictogram('💧', 'water', 'voda', 'вода'),
    Pictogram('🥛', 'milk', 'mléko', 'молоко'),
    Pictogram('🍕', 'pizza', 'pizza', 'піца'),
    Pictogram('🍌', 'banana', 'banán', 'банан'),
    Pictogram('🍪', 'cookie', 'sušenka', 'печиво'),
    Pictogram('🥪', 'sandwich', 'sendvič', 'бутерброд'),
    Pictogram('🍝', 'pasta', 'těstoviny', 'макарони'),
    Pictogram('🥣', 'cereal', 'cereálie', 'пластівці'),
    Pictogram('🧃', 'juice', 'džus', 'сік'),
  ],
  'school': [
    Pictogram('📚', 'book', 'kniha', 'книжка'),
    Pictogram('✏️', 'pencil', 'tužka', 'олівець'),
    Pictogram('👩‍🏫', 'teacher', 'učitelka', 'вчителька'),
    Pictogram('🎨', 'art', 'výtvarka', 'малювання'),
    Pictogram('➗', 'math', 'matika', 'математика'),
    Pictogram('🛝', 'recess', 'přestávka', 'перерва'),
    Pictogram('🎵', 'music', 'hudba', 'музика'),
    Pictogram('💻', 'computer', 'počítač', 'комп’ютер'),
    Pictogram('🔬', 'science', 'věda', 'наука'),
    Pictogram('📖', 'reading', 'čtení', 'читання'),
  ],
  'family': [
    Pictogram('👩', 'mom', 'máma', 'мама'),
    Pictogram('👨', 'dad', 'táta', 'тато'),
    Pictogram('👧', 'sister', 'sestra', 'сестра'),
    Pictogram('👦', 'brother', 'bratr', 'брат'),
    Pictogram('👵', 'grandma', 'babička', 'бабуся'),
    Pictogram('👴', 'grandpa', 'děda', 'дідусь'),
    Pictogram('👶', 'baby', 'miminko', 'малюк'),
    Pictogram('🐶', 'dog', 'pes', 'пес'),
    Pictogram('🐱', 'cat', 'kočka', 'кіт'),
    Pictogram('🧒', 'friend', 'kamarád', 'друг'),
  ],
  'activities': [
    Pictogram('🎮', 'play', 'hrát', 'гратися'),
    Pictogram('🖍️', 'draw', 'kreslit', 'малювати'),
    Pictogram('🏃', 'run', 'běhat', 'бігати'),
    Pictogram('🤸', 'jump', 'skákat', 'стрибати'),
    Pictogram('😴', 'sleep', 'spát', 'спати'),
    Pictogram('🎤', 'sing', 'zpívat', 'співати'),
    Pictogram('💃', 'dance', 'tancovat', 'танцювати'),
    Pictogram('🏊', 'swim', 'plavat', 'плавати'),
    Pictogram('📖', 'read', 'číst', 'читати'),
    Pictogram('🧱', 'build', 'stavět', 'будувати'),
  ],
  'places': [
    Pictogram('🏠', 'home', 'domov', 'дім'),
    Pictogram('🏫', 'school', 'škola', 'школа'),
    Pictogram('🌳', 'park', 'park', 'парк'),
    Pictogram('🛒', 'store', 'obchod', 'магазин'),
    Pictogram('🚻', 'bathroom', 'záchod', 'туалет'),
    Pictogram('🍳', 'kitchen', 'kuchyně', 'кухня'),
    Pictogram('☀️', 'outside', 'venku', 'надворі'),
    Pictogram('🚗', 'car', 'auto', 'авто'),
    Pictogram('🏖️', 'beach', 'pláž', 'пляж'),
    Pictogram('🏥', 'doctor', 'doktor', 'лікар'),
  ],
  'numbers': [
    Pictogram('1️⃣', 'one', 'jedna', 'один'),
    Pictogram('2️⃣', 'two', 'dvě', 'два'),
    Pictogram('3️⃣', 'three', 'tři', 'три'),
    Pictogram('4️⃣', 'four', 'čtyři', 'чотири'),
    Pictogram('5️⃣', 'five', 'pět', 'п’ять'),
    Pictogram('➕', 'more', 'víc', 'більше'),
    Pictogram('➖', 'less', 'míň', 'менше'),
    Pictogram('💯', 'all', 'všechno', 'усе'),
    Pictogram('0️⃣', 'none', 'nic', 'нічого'),
    Pictogram('🤏', 'some', 'trochu', 'трохи'),
  ],
  'greetings': [
    Pictogram('👋', 'hello', 'ahoj', 'привіт'),
    Pictogram('🖐️', 'goodbye', 'pa pa', 'бувай'),
    Pictogram('🙏', 'please', 'prosím', 'будь ласка'),
    Pictogram('💝', 'thank you', 'děkuji', 'дякую'),
    Pictogram('😔', 'sorry', 'promiň', 'вибач'),
    Pictogram('✅', 'yes', 'ano', 'так'),
    Pictogram('❌', 'no', 'ne', 'ні'),
    Pictogram('👌', 'okay', 'dobře', 'гаразд'),
    Pictogram('🌅', 'good morning', 'dobré ráno', 'доброго ранку'),
    Pictogram('🌙', 'good night', 'dobrou noc', 'на добраніч'),
  ],
};
