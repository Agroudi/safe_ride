/// Words that may mean the user is in an emergency, in English, Modern
/// Standard Arabic and Egyptian Arabic. Read on the phone, before anything is
/// sent, so the screen can offer Get help at once — with no network and
/// without waiting for, or trusting, the AI.
///
/// A match never decides anything: it only shows the Get help shortcut. It
/// never calls, sends, shares or blocks. A false match costs one banner; a
/// missed one costs nothing, because Get help is always on the screen too.
abstract final class EmergencySignal {
  static final RegExp _english = RegExp(
    r'\b(accident|crash(ed)?|collision|injur(ed|y)|hurt|bleeding|unconscious|'
    r'fainted|ambulance|emergency|help me|attacked|on fire|trapped)\b',
    caseSensitive: false,
  );

  /// Normalized Arabic (see [_normalize]) — Modern Standard and Egyptian.
  static const List<String> _arabic = <String>[
    'حادث', // accident, حادثه
    'اصطدام',
    'تصادم',
    'مصاب', // injured
    'اصابه',
    'جريح',
    'نزيف',
    'ينزف',
    'بينزف',
    'فاقد الوعي',
    'اغمي عليه',
    'حريق',
    'حريقه',
    'ولعت',
    'طوارئ',
    'النجده',
    'نجده',
    'ساعدني',
    'ساعدوني',
    'الحقوني',
    'الحقني',
    'اسعاف',
    'اتخبطت',
    'خبطتني',
    'محبوس',
    'اعتداء',
  ];

  static final RegExp _diacritics = RegExp('[ً-ْـ]');

  /// True when [text] holds a word that may mean an emergency.
  static bool detect(String text) {
    if (_english.hasMatch(text)) return true;
    final String arabic = _normalize(text);
    return _arabic.any(arabic.contains);
  }

  /// Arabic as people type it: no diacritics or tatweel, one alef, ه for ة,
  /// ي for ى.
  static String _normalize(String text) => text
      .replaceAll(_diacritics, '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}
