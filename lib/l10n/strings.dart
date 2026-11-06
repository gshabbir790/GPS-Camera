/// زبان: 'en' (ڈیفالٹ) یا 'ur'
class S {
  static String lang = 'en';
  static bool get ur => lang == 'ur';
  static String t(String en, String urdu) => ur ? urdu : en;
}
