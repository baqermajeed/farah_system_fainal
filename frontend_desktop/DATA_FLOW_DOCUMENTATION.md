# توثيق شامل: آلية تخزين وجلب وتحديث البيانات في Frontend Desktop

## 📋 جدول المحتويات
1. [نظرة عامة](#نظرة-عامة)
2. [بنية التخزين](#بنية-التخزين)
3. [آلية جلب البيانات](#آلية-جلب-البيانات)
4. [آلية التحديث](#آلية-التحديث)
5. [التخزين في Hive](#التخزين-في-hive)
6. [التعامل مع الإجراءات](#التعامل-مع-الإجراءات)
7. [أمثلة عملية](#أمثلة-عملية)

---

## 🎯 نظرة عامة

المشروع يستخدم **نظام تخزين محلي باستخدام Hive** مع **CacheService** موحد:

1. **Hive** - للتخزين المحلي السريع (مرضى، مواعيد، أطباء، سجلات طبية، معرض صور)
2. **CacheService** - خدمة موحدة لإدارة جميع عمليات التخزين
3. **API Server** - المصدر الرئيسي للبيانات

### الملفات الرئيسية:
- `lib/services/cache_service.dart` - خدمة Hive الرئيسية
- `lib/services/api_service.dart` - طبقة الاتصال بالسيرفر
- `lib/services/patient_service.dart` - خدمات المرضى
- `lib/controllers/patient_controller.dart` - منطق المرضى

---

## 🗄️ بنية التخزين

### 1. Hive Boxes (في CacheService)

```dart
// الصناديق المستخدمة:
- patients: Box          // قائمة المرضى
- appointments: Box       // المواعيد
- medicalRecords: Box    // السجلات الطبية (مجمعة حسب patientId)
- gallery: Box            // معرض الصور (مجمعة حسب patientId)
- doctors: Box            // قائمة الأطباء
- user: Box               // بيانات المستخدم الحالي
- metaData: Box           // بيانات وصفية (أوقات التحديث)
```

### 2. النماذج المدعومة

| النموذج | التخزين | المفاتيح |
|---------|---------|----------|
| `PatientModel` | `patients` Box | `'list'` - قائمة كاملة |
| `AppointmentModel` | `appointments` Box | `'list'` - قائمة كاملة |
| `DoctorModel` | `doctors` Box | `'list'` - قائمة كاملة |
| `UserModel` | `user` Box | `'currentUser'` - المستخدم الحالي |
| `MedicalRecordModel` | `medicalRecords` Box | `patientId` - لكل مريض |
| `GalleryImageModel` | `gallery` Box | `patientId` - لكل مريض |

---

## 📥 آلية جلب البيانات

### التدفق العام (Cache-First):

```
1. Controller يطلب البيانات
   ↓
2. CacheService - محاولة قراءة من Cache
   ↓
3. إذا موجود → عرض فوري
   ↓
4. Service يجلب من API (في الخلفية)
   ↓
5. تحويل JSON إلى Models
   ↓
6. حفظ في Hive عبر CacheService
   ↓
7. تحديث UI بالبيانات الجديدة
```

### مثال: جلب المرضى

#### 1. في Controller (`patient_controller.dart`):

```dart
Future<void> loadPatientsSmart() async {
  try {
    isLoading.value = true;
    final cacheService = CacheService();
    
    // 1. محاولة قراءة من Cache
    final cachedPatients = cacheService.getAllPatients();
    if (cachedPatients.isNotEmpty) {
      // عرض فوري من Cache
      patients.value = cachedPatients;
      isLoading.value = false;
      
      // التحقق من التحديثات في الخلفية
      _checkForUpdates();
      return;
    }
    
    // 2. جلب من API إذا لم يكن هناك Cache
    final patientsList = await _patientService.getAllPatients(...);
    
    // 3. حفظ في Cache
    await cacheService.savePatients(patientsList);
    
    // 4. تحديث UI
    patients.value = patientsList;
  } finally {
    isLoading.value = false;
  }
}
```

#### 2. في CacheService:

```dart
List<PatientModel> getAllPatients() {
  final data = _patientsBox.get('list');
  if (data == null || data is! List) return [];
  
  return data
      .map((json) => PatientModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ))
      .toList();
}
```

---

## 🔄 آلية التحديث

### استراتيجية Cache-First (المطبقة):

```
1. تحميل من Cache أولاً (إن وجد) → عرض فوري
   ↓
2. محاولة التحديث من السيرفر في الخلفية
   ↓
3. إذا نجح: تحديث Cache + تحديث UI
   ↓
4. إذا فشل: الاستمرار باستخدام Cache
```

### مثال: تحديث بيانات المريض

```dart
// في patient_controller.dart
Future<void> setTreatmentType({
  required String patientId,
  required String treatmentType,
}) async {
  try {
    // 1. تحديث متفائل في UI و Cache
    final index = patients.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      final updated = patients[index].copyWith(...);
      patients[index] = updated;
      
      // حفظ في Cache
      await CacheService().savePatient(updated);
    }
    
    // 2. إرسال للـ API
    final updatedPatient = await _doctorService.setTreatmentType(...);
    
    // 3. تحديث بالبيانات المؤكدة من السيرفر
    patients[index] = updatedPatient;
    await CacheService().savePatient(updatedPatient);
    
  } catch (e) {
    // Rollback في حالة الخطأ
    // ...
  }
}
```

---

## 💾 التخزين في Hive

### التهيئة (`main.dart`):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة CacheService
  await CacheService().init();
  
  // فتح صناديق إضافية للتوافق مع الكود القديم
  await Hive.openBox('doctors');
  await Hive.openBox('user');
  await Hive.openBox('metaData');
  
  runApp(const MyApp());
}
```

### تهيئة CacheService:

```dart
Future<void> init() async {
  await Hive.initFlutter();
  
  // فتح جميع الصناديق
  _patientsBox = await Hive.openBox(_patientsBoxName);
  _appointmentsBox = await Hive.openBox(_appointmentsBoxName);
  _medicalRecordsBox = await Hive.openBox(_medicalRecordsBoxName);
  _galleryBox = await Hive.openBox(_galleryBoxName);
  _doctorsBox = await Hive.openBox(_doctorsBoxName);
  _userBox = await Hive.openBox(_userBoxName);
}
```

### عمليات Hive:

#### حفظ المرضى:

```dart
// حفظ قائمة مرضى
Future<void> savePatients(List<PatientModel> patients) async {
  await _patientsBox.put(
    'list',
    patients.map((p) => p.toJson()).toList(),
  );
  await setLastUpdateTime('patients');
}

// حفظ مريض واحد
Future<void> savePatient(PatientModel patient) async {
  final all = getAllPatients();
  final index = all.indexWhere((p) => p.id == patient.id);
  if (index != -1) {
    all[index] = patient; // تحديث
  } else {
    all.insert(0, patient); // إضافة جديد
  }
  await savePatients(all);
}
```

#### قراءة المرضى:

```dart
// جلب جميع المرضى
List<PatientModel> getAllPatients() {
  final data = _patientsBox.get('list');
  if (data == null || data is! List) return [];
  
  return data
      .map((json) => PatientModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ))
      .toList();
}

// جلب مريض معين
PatientModel? getPatient(String id) {
  final all = getAllPatients();
  try {
    return all.firstWhere((p) => p.id == id);
  } catch (e) {
    return null;
  }
}
```

#### حفظ السجلات الطبية (مجمعة حسب المريض):

```dart
Future<void> saveMedicalRecords(
  String patientId,
  List<MedicalRecordModel> records,
) async {
  await _medicalRecordsBox.put(
    patientId,
    records.map((r) => r.toJson()).toList(),
  );
  await setLastUpdateTime('medicalRecords_$patientId');
}

List<MedicalRecordModel> getMedicalRecords(String patientId) {
  final data = _medicalRecordsBox.get(patientId);
  if (data == null || data is! List) return [];
  
  return data
      .map((json) => MedicalRecordModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ))
      .toList();
}
```

#### تتبع وقت التحديث:

```dart
// حفظ وقت التحديث
Future<void> setLastUpdateTime(String key) async {
  final box = await Hive.openBox('metaData');
  await box.put('lastUpdate_$key', DateTime.now().millisecondsSinceEpoch);
}

// قراءة آخر وقت تحديث
DateTime? getLastUpdateTime(String key) {
  final box = Hive.box('metaData');
  final timestamp = box.get('lastUpdate_$key');
  return timestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(timestamp as int)
      : null;
}

// التحقق من ضرورة التحديث
bool shouldRefresh(String key, {Duration maxAge = const Duration(hours: 24)}) {
  final lastUpdate = getLastUpdateTime(key);
  if (lastUpdate == null) return true;
  
  final age = DateTime.now().difference(lastUpdate);
  return age > maxAge;
}
```

---

## ⚙️ التعامل مع الإجراءات

### 1. إضافة مريض جديد

```dart
// في patient_controller.dart
void addPatient(PatientModel patient) {
  // التحقق إذا كان موجود
  final existingIndex = patients.indexWhere((p) => p.id == patient.id);
  
  if (existingIndex != -1) {
    patients[existingIndex] = patient; // تحديث
  } else {
    patients.insert(0, patient); // إضافة جديد
  }
  
  // حفظ في Cache
  CacheService().savePatient(patient);
}
```

### 2. تحديث بيانات المستخدم

```dart
// في auth_controller.dart
Future<void> updateUser(UserModel user) async {
  // حفظ في Cache
  await CacheService().saveUser(user);
  
  // تحديث في Controller
  currentUser.value = user;
}
```

### 3. حذف البيانات

```dart
// مسح جميع البيانات
Future<void> clearAll() async {
  await CacheService().clearAll();
}

// مسح نوع معين
Future<void> clearPatients() async {
  await CacheService().clearPatients();
}
```

---

## 📝 أمثلة عملية

### مثال 1: تطبيق Cache-First على المرضى

```dart
// في patient_controller.dart
Future<void> loadPatientsSmart() async {
  try {
    isLoading.value = true;
    final cacheService = CacheService();
    
    // 1. محاولة قراءة من Cache
    final cachedPatients = cacheService.getAllPatients();
    if (cachedPatients.isNotEmpty) {
      // عرض فوري
      patients.value = cachedPatients;
      isLoading.value = false;
      
      // التحقق من التحديثات في الخلفية
      _checkForUpdates();
      return;
    }
    
    // 2. جلب من API
    final patientsList = await _patientService.getAllPatients(...);
    
    // 3. حفظ في Cache
    await cacheService.savePatients(patientsList);
    
    // 4. تحديث UI
    patients.value = patientsList;
  } finally {
    isLoading.value = false;
  }
}
```

### مثال 2: التحقق من التحديثات

```dart
Future<void> _checkForUpdates() async {
  try {
    final cacheService = CacheService();
    
    // التحقق إذا كان الوقت مناسب للتحديث
    if (!cacheService.shouldRefresh('patients', maxAge: Duration(hours: 1))) {
      return; // لا حاجة للتحديث
    }
    
    // جلب التحديثات من API
    final recentPatients = await _patientService.getAllPatients(...);
    
    // دمج التحديثات
    final cached = cacheService.getAllPatients();
    final merged = _mergePatients(cached, recentPatients);
    
    // حفظ المحدث
    await cacheService.savePatients(merged);
    patients.value = merged;
    
  } catch (e) {
    // لا نعرض خطأ لأن Cache موجود ويعمل
    print('Error checking updates: $e');
  }
}
```

### مثال 3: Optimistic Updates

```dart
Future<void> updatePatient(PatientModel patient) async {
  // 1. تحديث متفائل في UI
  final index = patients.indexWhere((p) => p.id == patient.id);
  if (index != -1) {
    patients[index] = patient;
    await CacheService().savePatient(patient);
  }
  
  try {
    // 2. إرسال للـ API
    final updated = await _patientService.updatePatient(patient);
    
    // 3. تحديث بالبيانات المؤكدة
    patients[index] = updated;
    await CacheService().savePatient(updated);
    
  } catch (e) {
    // Rollback في حالة الخطأ
    // ...
  }
}
```

---

## 🔍 ملخص التدفق الكامل

### سيناريو: فتح التطبيق لأول مرة

```
1. main() → تهيئة CacheService
   ↓
2. SplashScreen → انتظار التهيئة
   ↓
3. HomePage → PatientController.loadPatientsSmart()
   ↓
4. CacheService.getAllPatients() → Cache فارغ
   ↓
5. جلب من API
   ↓
6. حفظ في Cache
   ↓
7. عرض في UI
```

### سيناريو: فتح التطبيق مع وجود Cache

```
1. main() → تهيئة CacheService
   ↓
2. HomePage → PatientController.loadPatientsSmart()
   ↓
3. CacheService.getAllPatients() → قراءة من Cache (فوري)
   ↓
4. عرض في UI (سريع)
   ↓
5. التحقق من التحديثات في الخلفية
   ↓
6. تحديث Cache + UI إذا لزم الأمر
```

### سيناريو: بدون إنترنت

```
1. loadPatientsSmart() → محاولة قراءة من Cache
   ↓
2. Cache موجود → عرض البيانات
   ↓
3. محاولة التحديث من API → فشل
   ↓
4. الاستمرار باستخدام Cache
   ↓
5. عرض رسالة "لا يوجد اتصال" (اختياري)
```

---

## 📌 نقاط مهمة

### ✅ ما يعمل حالياً:
- ✅ CacheService موحد لجميع عمليات التخزين
- ✅ Cache-First strategy مطبقة
- ✅ تخزين المرضى والمواعيد والأطباء
- ✅ تخزين السجلات الطبية والمعرض (مجمعة حسب المريض)
- ✅ تتبع أوقات التحديث
- ✅ Optimistic Updates

### 💡 توصيات:
1. استخدام CacheService في جميع Controllers
2. تطبيق Cache-First في جميع عمليات الجلب
3. استخدام shouldRefresh للتحقق من ضرورة التحديث
4. تطبيق Optimistic Updates للعمليات السريعة

---

## 📚 مراجع

- [Hive Documentation](https://docs.hivedb.dev/)
- [GetX Documentation](https://pub.dev/packages/get)
- ملف `cache_service.dart` في المشروع

---

**آخر تحديث**: تم إنشاء هذا التوثيق بعد تطبيق نظام CacheService الموحد.

