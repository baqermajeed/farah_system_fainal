import 'package:flutter/foundation.dart';
import 'package:upgrader/upgrader.dart';

/// فحص التحديث من Google Play / App Store عند توفر إصدار أحدث.
class AppUpgrader {
  AppUpgrader._();

  static final Upgrader instance = Upgrader(
    languageCode: 'ar',
    countryCode: 'IQ',
    messages: _MandatoryUpdateMessages(),
    durationUntilAlertAgain: Duration.zero,
    debugLogging: kDebugMode,
  );
}

class _MandatoryUpdateMessages extends UpgraderMessages {
  _MandatoryUpdateMessages() : super(code: 'ar');

  @override
  String get title => 'تحديث مطلوب';

  @override
  String get body =>
      'يتوفر إصدار جديد من {{appName}} ({{currentAppStoreVersion}}). '
      'إصدارك الحالي {{currentInstalledVersion}}. '
      'يرجى التحديث للمتابعة في استخدام التطبيق.';

  @override
  String get buttonTitleUpdate => 'تحديث الآن';
}
