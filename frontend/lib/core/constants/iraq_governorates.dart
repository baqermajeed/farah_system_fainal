/// محافظات العراق — مصدر موحّد محلي (لا يأتي من السيرفر).
/// السيرفر يخزّن اسم المحافظة كنص حر في حقل `city`.
class IraqGovernorates {
  IraqGovernorates._();

  /// المحافظات الـ 18 الرسمية بالعربية.
  static const List<String> arabicNames = [
    'بغداد',
    'البصرة',
    'نينوى',
    'أربيل',
    'السليمانية',
    'النجف',
    'كربلاء',
    'المثنى',
    'القادسية',
    'بابل',
    'واسط',
    'ديالى',
    'كركوك',
    'صلاح الدين',
    'الأنبار',
    'ذي قار',
    'ميسان',
    'دهوك',
  ];

  /// تحويل من الإنجليزية (كما يُخزَّن أحياناً في قاعدة البيانات) إلى العربية.
  static const Map<String, String> englishToArabic = {
    'Baghdad': 'بغداد',
    'Basra': 'البصرة',
    'Nineveh': 'نينوى',
    'Mosul': 'نينوى',
    'Erbil': 'أربيل',
    'Sulaymaniyah': 'السليمانية',
    'Najaf': 'النجف',
    'Karbala': 'كربلاء',
    'Muthanna': 'المثنى',
    'Qadisiyyah': 'القادسية',
    'Diwaniyah': 'القادسية',
    'Babil': 'بابل',
    'Wasit': 'واسط',
    'Diyala': 'ديالى',
    'Kirkuk': 'كركوك',
    'Saladin': 'صلاح الدين',
    'Anbar': 'الأنبار',
    'Dhi Qar': 'ذي قار',
    'Maysan': 'ميسان',
    'Duhok': 'دهوك',
  };

  /// أسماء عربية قديمة/بديلة تُحوَّل إلى الاسم الرسمي.
  static const Map<String, String> arabicAliases = {
    'النجف الاشرف': 'النجف',
    'الموصل': 'نينوى',
    'الديوانية': 'القادسية',
  };

  /// يحوّل القيمة المخزّنة (عربي/إنجليزي) إلى اسم عربي للعرض والاختيار.
  static String? toArabic(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;
    final value = stored.trim();

    if (englishToArabic.containsKey(value)) {
      return englishToArabic[value];
    }
    if (arabicAliases.containsKey(value)) {
      return arabicAliases[value];
    }
    if (arabicNames.contains(value)) {
      return value;
    }
    return value;
  }

  /// يحوّل الاسم العربي المختار إلى إنجليزي للحفظ في الـ API.
  static String? toEnglish(String? arabic) {
    if (arabic == null || arabic.trim().isEmpty) return null;
    final canonical = arabicAliases[arabic.trim()] ?? arabic.trim();

    for (final entry in englishToArabic.entries) {
      if (entry.value == canonical) return entry.key;
    }
    return canonical;
  }
}
