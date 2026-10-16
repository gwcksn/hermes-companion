/// Greetings, thanks and praise that make Hermes happy (English and Indonesian).
final _friendly = RegExp(
  r'\b(thanks?|thank you|thx|terima kasih|makasih|good (morning|night|job)|selamat (pagi|siang|sore|malam)|well done|great job)\b',
  caseSensitive: false,
);

bool isFriendlyMessage(String text) => _friendly.hasMatch(text);
