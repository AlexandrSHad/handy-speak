import '../core/app_language.dart';

/// A picture symbol: emoji is language-neutral; label + spoken word vary.
/// Ported verbatim from the prototype's `PICTOGRAMS` + `WORDS_CS`
/// (IMPLEMENTATION_PLAN §6 / §6.2).
class Pictogram {
  final String emoji;
  final String en;
  final String cs;
  const Pictogram(this.emoji, this.en, this.cs);

  String word(AppLanguage l) => l == AppLanguage.cs ? cs : en;
}

/// Pictograms grouped by category id. 8 categories × 10 symbols.
const Map<String, List<Pictogram>> kPictograms = {
  'feelings': [
    Pictogram('😊', 'happy', 'šťastný'),
    Pictogram('😢', 'sad', 'smutný'),
    Pictogram('😴', 'tired', 'unavený'),
    Pictogram('😨', 'scared', 'vyděšený'),
    Pictogram('🤩', 'excited', 'nadšený'),
    Pictogram('😠', 'angry', 'naštvaný'),
    Pictogram('❤️', 'love', 'láska'),
    Pictogram('😌', 'calm', 'klidný'),
    Pictogram('🤪', 'silly', 'bláznivý'),
    Pictogram('🙈', 'shy', 'stydlivý'),
  ],
  'food': [
    Pictogram('🍎', 'apple', 'jablko'),
    Pictogram('💧', 'water', 'voda'),
    Pictogram('🥛', 'milk', 'mléko'),
    Pictogram('🍕', 'pizza', 'pizza'),
    Pictogram('🍌', 'banana', 'banán'),
    Pictogram('🍪', 'cookie', 'sušenka'),
    Pictogram('🥪', 'sandwich', 'sendvič'),
    Pictogram('🍝', 'pasta', 'těstoviny'),
    Pictogram('🥣', 'cereal', 'cereálie'),
    Pictogram('🧃', 'juice', 'džus'),
  ],
  'school': [
    Pictogram('📚', 'book', 'kniha'),
    Pictogram('✏️', 'pencil', 'tužka'),
    Pictogram('👩‍🏫', 'teacher', 'učitelka'),
    Pictogram('🎨', 'art', 'výtvarka'),
    Pictogram('➗', 'math', 'matika'),
    Pictogram('🛝', 'recess', 'přestávka'),
    Pictogram('🎵', 'music', 'hudba'),
    Pictogram('💻', 'computer', 'počítač'),
    Pictogram('🔬', 'science', 'věda'),
    Pictogram('📖', 'reading', 'čtení'),
  ],
  'family': [
    Pictogram('👩', 'mom', 'máma'),
    Pictogram('👨', 'dad', 'táta'),
    Pictogram('👧', 'sister', 'sestra'),
    Pictogram('👦', 'brother', 'bratr'),
    Pictogram('👵', 'grandma', 'babička'),
    Pictogram('👴', 'grandpa', 'děda'),
    Pictogram('👶', 'baby', 'miminko'),
    Pictogram('🐶', 'dog', 'pes'),
    Pictogram('🐱', 'cat', 'kočka'),
    Pictogram('🧒', 'friend', 'kamarád'),
  ],
  'activities': [
    Pictogram('🎮', 'play', 'hrát'),
    Pictogram('🖍️', 'draw', 'kreslit'),
    Pictogram('🏃', 'run', 'běhat'),
    Pictogram('🤸', 'jump', 'skákat'),
    Pictogram('😴', 'sleep', 'spát'),
    Pictogram('🎤', 'sing', 'zpívat'),
    Pictogram('💃', 'dance', 'tancovat'),
    Pictogram('🏊', 'swim', 'plavat'),
    Pictogram('📖', 'read', 'číst'),
    Pictogram('🧱', 'build', 'stavět'),
  ],
  'places': [
    Pictogram('🏠', 'home', 'domov'),
    Pictogram('🏫', 'school', 'škola'),
    Pictogram('🌳', 'park', 'park'),
    Pictogram('🛒', 'store', 'obchod'),
    Pictogram('🚻', 'bathroom', 'záchod'),
    Pictogram('🍳', 'kitchen', 'kuchyně'),
    Pictogram('☀️', 'outside', 'venku'),
    Pictogram('🚗', 'car', 'auto'),
    Pictogram('🏖️', 'beach', 'pláž'),
    Pictogram('🏥', 'doctor', 'doktor'),
  ],
  'numbers': [
    Pictogram('1️⃣', 'one', 'jedna'),
    Pictogram('2️⃣', 'two', 'dvě'),
    Pictogram('3️⃣', 'three', 'tři'),
    Pictogram('4️⃣', 'four', 'čtyři'),
    Pictogram('5️⃣', 'five', 'pět'),
    Pictogram('➕', 'more', 'víc'),
    Pictogram('➖', 'less', 'míň'),
    Pictogram('💯', 'all', 'všechno'),
    Pictogram('0️⃣', 'none', 'nic'),
    Pictogram('🤏', 'some', 'trochu'),
  ],
  'greetings': [
    Pictogram('👋', 'hello', 'ahoj'),
    Pictogram('🖐️', 'goodbye', 'pa pa'),
    Pictogram('🙏', 'please', 'prosím'),
    Pictogram('💝', 'thank you', 'děkuji'),
    Pictogram('😔', 'sorry', 'promiň'),
    Pictogram('✅', 'yes', 'ano'),
    Pictogram('❌', 'no', 'ne'),
    Pictogram('👌', 'okay', 'dobře'),
    Pictogram('🌅', 'good morning', 'dobré ráno'),
    Pictogram('🌙', 'good night', 'dobrou noc'),
  ],
};
