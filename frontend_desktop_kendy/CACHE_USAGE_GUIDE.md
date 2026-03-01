# دليل استخدام CacheService

## نظرة عامة

`CacheService` هو خدمة موحدة لإدارة التخزين المحلي باستخدام Hive. توفر واجهة بسيطة لحفظ وجلب جميع أنواع البيانات في التطبيق.

---

## التهيئة

يتم تهيئة CacheService تلقائياً في `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة CacheService
  await CacheService().init();
  
  runApp(const MyApp());
}
```

---

## الاستخدام الأساسي

### 1. حفظ البيانات

#### حفظ قائمة مرضى:
```dart
final cacheService = CacheService();
await cacheService.savePatients(patientsList);
```

#### حفظ مريض واحد:
```dart
await cacheService.savePatient(patient);
```

#### حفظ مواعيد:
```dart
await cacheService.saveAppointments(appointmentsList);
```

#### حفظ سجلات طبية:
```dart
await cacheService.saveMedicalRecords(patientId, recordsList);
```

#### حفظ صور المعرض:
```dart
await cacheService.saveGalleryImages(patientId, imagesList);
```

#### حفظ بيانات المستخدم:
```dart
await cacheService.saveUser(userModel);
```

---

### 2. قراءة البيانات

#### جلب جميع المرضى:
```dart
final patients = cacheService.getAllPatients();
```

#### جلب مريض معين:
```dart
final patient = cacheService.getPatient(patientId);
```

#### جلب المواعيد:
```dart
final appointments = cacheService.getAllAppointments();
```

#### جلب سجلات طبية:
```dart
final records = cacheService.getMedicalRecords(patientId);
```

#### جلب صور المعرض:
```dart
final images = cacheService.getGalleryImages(patientId);
```

#### جلب بيانات المستخدم:
```dart
final user = cacheService.getUser();
```

---

### 3. حذف البيانات

#### مسح جميع المرضى:
```dart
await cacheService.clearPatients();
```

#### مسح جميع المواعيد:
```dart
await cacheService.clearAppointments();
```

#### مسح سجلات طبية:
```dart
await cacheService.clearMedicalRecords(patientId);
```

#### مسح جميع البيانات:
```dart
await cacheService.clearAll();
```

---

## Cache-First Strategy

### مثال تطبيقي:

```dart
Future<void> loadPatients() async {
  final cacheService = CacheService();
  
  try {
    isLoading.value = true;
    
    // 1. محاولة قراءة من Cache
    final cachedPatients = cacheService.getAllPatients();
    if (cachedPatients.isNotEmpty) {
      // عرض فوري من Cache
      patients.value = cachedPatients;
      isLoading.value = false;
      
      // تحديث في الخلفية
      _updateFromAPI();
      return;
    }
    
    // 2. جلب من API إذا لم يكن هناك Cache
    final patientsList = await _patientService.getAllPatients();
    
    // 3. حفظ في Cache
    await cacheService.savePatients(patientsList);
    
    // 4. عرض
    patients.value = patientsList;
    
  } finally {
    isLoading.value = false;
  }
}

Future<void> _updateFromAPI() async {
  try {
    final patientsList = await _patientService.getAllPatients();
    await CacheService().savePatients(patientsList);
    patients.value = patientsList;
  } catch (e) {
    // لا نعرض خطأ لأن Cache موجود ويعمل
    print('Error updating from API: $e');
  }
}
```

---

## تتبع أوقات التحديث

### حفظ وقت التحديث:
```dart
await cacheService.setLastUpdateTime('patients');
```

### قراءة آخر وقت تحديث:
```dart
final lastUpdate = cacheService.getLastUpdateTime('patients');
```

### التحقق من ضرورة التحديث:
```dart
if (cacheService.shouldRefresh('patients', maxAge: Duration(hours: 24))) {
  // حان وقت التحديث
  await loadFromAPI();
}
```

---

## Optimistic Updates

### مثال: تحديث متفائل

```dart
Future<void> updatePatient(PatientModel patient) async {
  final cacheService = CacheService();
  
  // 1. تحديث متفائل في UI و Cache
  final index = patients.indexWhere((p) => p.id == patient.id);
  if (index != -1) {
    patients[index] = patient;
    await cacheService.savePatient(patient);
  }
  
  try {
    // 2. إرسال للـ API
    final updated = await _patientService.updatePatient(patient);
    
    // 3. تحديث بالبيانات المؤكدة
    patients[index] = updated;
    await cacheService.savePatient(updated);
    
  } catch (e) {
    // Rollback في حالة الخطأ
    // ...
  }
}
```

---

## دوال مساعدة

### التحقق من وجود Cache:
```dart
if (cacheService.hasCache) {
  print('يوجد بيانات محفوظة');
}
```

### الحصول على حجم البيانات:
```dart
final totalItems = cacheService.totalCachedItems;
print('إجمالي العناصر: $totalItems');
```

---

## أمثلة متقدمة

### دمج التحديثات بذكاء:

```dart
List<PatientModel> _mergePatients(
  List<PatientModel> cached,
  List<PatientModel> recent,
) {
  final cachedMap = <String, PatientModel>{};
  for (final p in cached) {
    cachedMap[p.id] = p;
  }
  
  // إضافة/تحديث من recent
  for (final recentPatient in recent) {
    cachedMap[recentPatient.id] = recentPatient;
  }
  
  return cachedMap.values.toList();
}
```

---

## ملاحظات مهمة

1. **CacheService هو Singleton**: استخدم `CacheService()` مباشرة
2. **JSON Serialization**: يستخدم `toJson()` و `fromJson()` للنماذج
3. **Error Handling**: جميع الدوال تحتوي على معالجة أخطاء
4. **Background Updates**: التحديثات في الخلفية لا تمنع عرض Cache

---

## استكشاف الأخطاء

### المشكلة: البيانات لا تُحفظ
**الحل**: تأكد من استدعاء `setLastUpdateTime()` بعد الحفظ

### المشكلة: البيانات القديمة تظهر
**الحل**: استخدم `shouldRefresh()` للتحقق من ضرورة التحديث

### المشكلة: خطأ في parsing
**الحل**: تأكد من أن النماذج تحتوي على `toJson()` و `fromJson()`

---

## الخلاصة

✅ CacheService يوفر واجهة موحدة لجميع عمليات التخزين
✅ Cache-First strategy يضمن تجربة مستخدم سريعة
✅ تتبع أوقات التحديث يسمح بالتحديث الذكي
✅ Optimistic Updates تحسن من استجابة التطبيق

للمزيد من المعلومات، راجع `DATA_FLOW_DOCUMENTATION.md`

