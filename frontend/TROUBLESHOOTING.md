# 🔧 حل المشاكل الشائعة - Troubleshooting Guide

دليل شامل لحل المشاكل الشائعة التي قد تواجهها أثناء تطوير أو تشغيل التطبيق.

---

## 📋 جدول المحتويات

1. [مشاكل التثبيت](#مشاكل-التثبيت)
2. [مشاكل Hive](#مشاكل-hive)
3. [مشاكل GetX](#مشاكل-getx)
4. [مشاكل ScreenUtil](#مشاكل-screenutil)
5. [مشاكل البناء](#مشاكل-البناء)
6. [مشاكل UI](#مشاكل-ui)
7. [مشاكل الأداء](#مشاكل-الأداء)

---

## 🔨 مشاكل التثبيت

### ❌ المشكلة: `flutter pub get` يفشل

**الأعراض:**
```
Running "flutter pub get" in farah_sys_final...
Error: Package not found
```

**الحل:**
```bash
# 1. نظف الكاش
flutter clean

# 2. احذف pubspec.lock
rm pubspec.lock  # في Linux/Mac
del pubspec.lock  # في Windows

# 3. أعد تثبيت الحزم
flutter pub get

# 4. إذا استمرت المشكلة
flutter pub cache repair
```

---

### ❌ المشكلة: إصدار Flutter غير متوافق

**الأعراض:**
```
Your Flutter version is too old.
Required: 3.9.2
Current: 3.7.0
```

**الحل:**
```bash
# ترقية Flutter
flutter upgrade

# أو تحديد إصدار محدد
flutter version 3.9.2
```

---

## 💾 مشاكل Hive

### ❌ المشكلة: `HiveError: Cannot find the generated adapter`

**الأعراض:**
```
HiveError: Cannot find the generated adapter for UserModel
```

**الحل:**
```bash
# 1. تأكد من وجود part في Model
# في أول الملف:
part 'user_model.g.dart';

# 2. شغل build_runner
flutter pub run build_runner build --delete-conflicting-outputs

# 3. تأكد من تسجيل Adapter في main.dart
Hive.registerAdapter(UserModelAdapter());
```

---

### ❌ المشكلة: `Box is already open`

**الأعراض:**
```
HiveError: Box myBox is already open
```

**الحل:**
```dart
// بدلاً من:
await Hive.openBox('myBox');

// استخدم:
if (!Hive.isBoxOpen('myBox')) {
  await Hive.openBox('myBox');
}

// أو مباشرة:
final box = await Hive.openBox('myBox');
```

---

### ❌ المشكلة: `TypeId already registered`

**الأعراض:**
```
HiveError: TypeId 0 is already registered
```

**الحل:**
```dart
// تأكد من أن كل Model له TypeId فريد:

@HiveType(typeId: 0)  // UserModel
@HiveType(typeId: 1)  // PatientModel
@HiveType(typeId: 2)  // AppointmentModel
// وهكذا... كل Model رقم مختلف
```

---

## 🎯 مشاكل GetX

### ❌ المشكلة: `Controller is not registered`

**الأعراض:**
```
"MyController" not found. You need to call "Get.put()"
```

**الحل:**
```dart
// في الشاشة، قبل استخدام Controller:
final controller = Get.put(MyController());

// أو في main.dart (للـ Controllers العامة):
void main() {
  Get.put(AuthController());
  runApp(MyApp());
}
```

---

### ❌ المشكلة: التنقل لا يعمل

**الأعراض:**
```
Get.toNamed() لا ينتقل للشاشة الجديدة
```

**الحل:**
```dart
// 1. تأكد من استخدام GetMaterialApp بدلاً من MaterialApp
GetMaterialApp(
  // ...
)

// 2. تأكد من تسجيل الشاشة في getPages
getPages: [
  GetPage(
    name: AppRoutes.myScreen,
    page: () => const MyScreen(),
  ),
],

// 3. تأكد من الاسم صحيح
Get.toNamed(AppRoutes.myScreen); // وليس '/my-screen'
```

---

### ❌ المشكلة: `Obx` لا يتحدث

**الأعراض:**
```
البيانات تتغير لكن UI لا يتحدث
```

**الحل:**
```dart
// 1. تأكد من استخدام .obs
final RxString name = ''.obs;  // صحيح
final String name = '';          // خطأ

// 2. تأكد من استخدام Obx
Obx(() => Text(controller.name.value))  // صحيح
Text(controller.name.value)              // خطأ

// 3. تأكد من استخدام .value
controller.name.value = 'new';  // صحيح
controller.name = 'new';        // خطأ
```

---

## 📱 مشاكل ScreenUtil

### ❌ المشكلة: الأحجام غير صحيحة

**الأعراض:**
```
النصوص والأيقونات صغيرة جداً أو كبيرة جداً
```

**الحل:**
```dart
// 1. تأكد من تهيئة ScreenUtil في main
ScreenUtilInit(
  designSize: const Size(393, 852),  // حجم التصميم الأصلي
  builder: (context, child) {
    return GetMaterialApp(...);
  },
)

// 2. استخدم الوحدات الصحيحة
fontSize: 16.sp,    // للخطوط
width: 100.w,       // للعرض
height: 50.h,       // للارتفاع
padding: EdgeInsets.all(16.w),
```

---

## 🏗️ مشاكل البناء

### ❌ المشكلة: خطأ في build_runner

**الأعراض:**
```
[SEVERE] build_runner:build_runner on ...:
Error: ...
```

**الحل:**
```bash
# 1. نظف المشروع
flutter clean

# 2. احذف الملفات المولدة
find . -name "*.g.dart" -delete  # Linux/Mac
# أو يدوياً في Windows

# 3. أعد البناء
flutter pub run build_runner build --delete-conflicting-outputs

# 4. إذا استمرت المشكلة
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### ❌ المشكلة: `Import conflicts`

**الأعراض:**
```
Error: A member named 'MyClass' is defined in 'file1.dart' and 'file2.dart'.
```

**الحل:**
```dart
// استخدم as للتمييز:
import 'package:my_package/file1.dart' as file1;
import 'package:my_package/file2.dart' as file2;

// ثم استخدم:
file1.MyClass()
file2.MyClass()
```

---

## 🎨 مشاكل UI

### ❌ المشكلة: `RenderFlex overflowed`

**الأعراض:**
```
The yellow and black warning stripes appear
RenderFlex overflowed by X pixels
```

**الحل:**
```dart
// 1. استخدم Expanded أو Flexible
Row(
  children: [
    Expanded(
      child: Text('نص طويل جداً...'),
    ),
  ],
)

// 2. استخدم SingleChildScrollView
SingleChildScrollView(
  child: Column(
    children: [...],
  ),
)

// 3. حدد maxLines للنص
Text(
  'نص طويل',
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

---

### ❌ المشكلة: النص لا يظهر بالعربية RTL

**الأعراض:**
```
النص بالعربية يظهر من اليسار لليمين
```

**الحل:**
```dart
// في main.dart تأكد من:
builder: (context, widget) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: widget!,
  );
},

// أو في widget محدد:
Directionality(
  textDirection: TextDirection.rtl,
  child: Text('نص عربي'),
)
```

---

### ❌ المشكلة: الصور لا تظهر

**الأعراض:**
```
Image not found or failed to load
```

**الحل:**
```dart
// 1. تأكد من إضافة المسار في pubspec.yaml
flutter:
  assets:
    - image_ui/

// 2. استخدم المسار الصحيح
Image.asset('image_ui/logo.png')

// 3. أضف errorBuilder
Image.asset(
  'image_ui/logo.png',
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.error);
  },
)

// 4. بعد تعديل pubspec.yaml:
flutter pub get
```

---

## ⚡ مشاكل الأداء

### ❌ المشكلة: التطبيق بطيء

**الحل:**
```dart
// 1. استخدم const حيثما أمكن
const Text('نص')

// 2. استخدم ListView.builder بدلاً من ListView
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemWidget(items[index]);
  },
)

// 3. تجنب rebuild غير ضروري
// استخدم Obx فقط للأجزاء المتغيرة

// 4. استخدم AutomaticKeepAliveClientMixin للـ Tabs
class MyTab extends StatefulWidget {
  @override
  _MyTabState createState() => _MyTabState();
}

class _MyTabState extends State<MyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}
```

---

## 🔍 نصائح عامة

### تشخيص المشاكل

```bash
# 1. فحص الأخطاء
flutter analyze

# 2. تشغيل الاختبارات
flutter test

# 3. عرض logs
flutter logs

# 4. تنظيف المشروع
flutter clean
flutter pub get

# 5. إعادة بناء كل شيء
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

---

## 📞 الحصول على مساعدة

إذا لم تجد الحل هنا:

1. **راجع الوثائق:**
   - [Flutter Docs](https://flutter.dev/docs)
   - [GetX Docs](https://pub.dev/packages/get)
   - [Hive Docs](https://docs.hivedb.dev/)

2. **ابحث في:**
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
   - [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)

3. **افتح Issue:**
   - في مستودع المشروع مع:
     - وصف المشكلة
     - خطوات إعادة إنتاجها
     - رسالة الخطأ كاملة
     - إصدار Flutter و Dart

---

**آخر تحديث:** 2025-12-06
