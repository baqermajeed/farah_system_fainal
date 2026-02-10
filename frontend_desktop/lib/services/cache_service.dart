import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/models/doctor_model.dart';
import 'package:frontend_desktop/models/user_model.dart';
import 'package:frontend_desktop/models/medical_record_model.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';

/// خدمة التخزين المحلي باستخدام Hive
/// مطابق 100% لطريقة مشروع eversheen
class CacheService {
  static const String _userBoxName = 'userBox';
  static const String _patientsBoxName = 'patientsBox';
  static const String _appointmentsBoxName = 'appointmentsBox';
  static const String _doctorsBoxName = 'doctorsBox';
  static const String _medicalRecordsBoxName = 'medicalRecordsBox';
  static const String _galleryBoxName = 'galleryBox';

  // Boxes
  late Box<UserModel> _userBox;
  late Box<PatientModel> _patientsBox;
  late Box<AppointmentModel> _appointmentsBox;
  late Box<DoctorModel> _doctorsBox;
  late Box<MedicalRecordModel> _medicalRecordsBox;
  late Box<GalleryImageModel> _galleryBox;

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  /// تهيئة Hive وفتح الصناديق
  Future<void> init() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final hiveDir = Directory(p.join(appSupportDir.path, 'hive'));
    if (!await hiveDir.exists()) {
      await hiveDir.create(recursive: true);
    }

    await Hive.initFlutter(hiveDir.path);

    // تسجيل المحولات (Adapters)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PatientModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppointmentModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(DoctorModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MedicalRecordModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(GalleryImageModelAdapter());
    }

    // فتح الصناديق
    _userBox = await Hive.openBox<UserModel>(_userBoxName);
    _patientsBox = await Hive.openBox<PatientModel>(_patientsBoxName);
    _appointmentsBox = await Hive.openBox<AppointmentModel>(_appointmentsBoxName);
    _doctorsBox = await Hive.openBox<DoctorModel>(_doctorsBoxName);
    _medicalRecordsBox = await Hive.openBox<MedicalRecordModel>(_medicalRecordsBoxName);
    _galleryBox = await Hive.openBox<GalleryImageModel>(_galleryBoxName);
  }

  // ==================== User Operations ====================

  /// حفظ بيانات المستخدم
  Future<void> saveUser(UserModel user) async {
    try {
      await _userBox.put('currentUser', user);
      await setLastUpdateTime('user');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving user: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على بيانات المستخدم
  UserModel? getUser() {
    try {
      return _userBox.get('currentUser');
    } catch (e) {
      print('❌ [CacheService] Error getting user: $e');
      return null;
    }
  }

  /// حذف بيانات المستخدم
  Future<void> deleteUser() async {
    await _userBox.delete('currentUser');
  }

  // ==================== Patients Operations ====================

  /// حفظ قائمة المرضى (يحفظ فقط أول 100 مريض لتجنب Cache كبير)
  Future<void> savePatients(List<PatientModel> patients) async {
    try {
      if (patients.isEmpty) return;
      
      // ✅ حل نهائي: حفظ فقط أول 100 مريض في Cache لتجنب حجم كبير
      final patientsToCache = patients.take(100).toList();
      
      // استخدام batch operations لتجنب blocking UI thread
      final Map<String, PatientModel> patientsMap = {};
      for (var patient in patientsToCache) {
        if (patient.id.isNotEmpty) {
          patientsMap[patient.id] = patient;
        }
      }
      
      if (patientsMap.isEmpty) return;
      
      // مسح القديم ثم الحفظ الجديد
      await _patientsBox.clear();
      await _patientsBox.putAll(patientsMap);
      await setLastUpdateTime('patients');
      
      print('💾 [CacheService] Saved ${patientsMap.length} patients to cache (limited to 100)');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving patients: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على جميع المرضى (مرتبة حسب الأحدث أولاً)
  List<PatientModel> getAllPatients() {
    try {
      final all = _patientsBox.values.toList();
      // ترتيب حسب ID (تنازلي) للحصول على الأحدث أولاً
      // MongoDB ObjectIds تحتوي على timestamp، لذا الأكبر = الأحدث
      all.sort((a, b) => b.id.compareTo(a.id));
      return all;
    } catch (e) {
      print('❌ [CacheService] Error getting all patients: $e');
      return [];
    }
  }

  /// الحصول على أول N مريض من Cache (مرتبة حسب الأحدث أولاً)
  List<PatientModel> getFirstPatients(int limit) {
    try {
      final all = _patientsBox.values.toList();
      // ترتيب حسب ID (تنازلي) للحصول على الأحدث أولاً
      all.sort((a, b) => b.id.compareTo(a.id));
      return all.take(limit).toList();
    } catch (e) {
      print('❌ [CacheService] Error getting first patients: $e');
      return [];
    }
  }

  /// الحصول على مريض معين
  PatientModel? getPatient(String id) {
    return _patientsBox.get(id);
  }

  /// حفظ مريض واحد
  Future<void> savePatient(PatientModel patient) async {
    try {
      if (patient.id.isEmpty) return;
      await _patientsBox.put(patient.id, patient);
    } catch (e) {
      print('❌ [CacheService] Error saving patient: $e');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// حذف مريض
  Future<void> deletePatient(String id) async {
    await _patientsBox.delete(id);
  }

  /// مسح جميع المرضى
  Future<void> clearPatients() async {
    await _patientsBox.clear();
  }

  // ==================== Appointments Operations ====================

  /// حفظ قائمة المواعيد (يحفظ فقط أول 100 موعد لتجنب Cache كبير)
  Future<void> saveAppointments(List<AppointmentModel> appointments) async {
    try {
      if (appointments.isEmpty) return;
      
      // ✅ حل نهائي: حفظ فقط أول 100 موعد في Cache لتجنب حجم كبير
      final appointmentsToCache = appointments.take(100).toList();
      
      // استخدام batch operations لتجنب blocking UI thread
      final Map<String, AppointmentModel> appointmentsMap = {};
      for (var appointment in appointmentsToCache) {
        if (appointment.id.isNotEmpty) {
          appointmentsMap[appointment.id] = appointment;
        }
      }
      
      if (appointmentsMap.isEmpty) return;
      
      // مسح القديم ثم الحفظ الجديد
      await _appointmentsBox.clear();
      await _appointmentsBox.putAll(appointmentsMap);
      await setLastUpdateTime('appointments');
      
      print('💾 [CacheService] Saved ${appointmentsMap.length} appointments to cache (limited to 100)');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving appointments: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على جميع المواعيد
  List<AppointmentModel> getAllAppointments() {
    try {
      return _appointmentsBox.values.toList();
    } catch (e) {
      print('❌ [CacheService] Error getting all appointments: $e');
      return [];
    }
  }

  /// الحصول على أول N موعد من Cache (لتحسين الأداء)
  List<AppointmentModel> getFirstAppointments(int limit) {
    try {
      final all = _appointmentsBox.values.toList();
      return all.take(limit).toList();
    } catch (e) {
      print('❌ [CacheService] Error getting first appointments: $e');
      return [];
    }
  }

  /// الحصول على مواعيد مريض معين
  List<AppointmentModel> getPatientAppointments(String patientId) {
    return _appointmentsBox.values
        .where((appointment) => appointment.patientId == patientId)
        .toList();
  }

  /// حفظ موعد واحد
  Future<void> saveAppointment(AppointmentModel appointment) async {
    try {
      if (appointment.id.isEmpty) return;
      await _appointmentsBox.put(appointment.id, appointment);
    } catch (e) {
      print('❌ [CacheService] Error saving appointment: $e');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// حذف موعد
  Future<void> deleteAppointment(String id) async {
    await _appointmentsBox.delete(id);
  }

  /// مسح جميع المواعيد
  Future<void> clearAppointments() async {
    await _appointmentsBox.clear();
  }

  // ==================== Doctors Operations ====================

  /// حفظ قائمة الأطباء
  Future<void> saveDoctors(List<DoctorModel> doctors) async {
    try {
      if (doctors.isEmpty) return;
      
      // استخدام batch operations لتجنب blocking UI thread
      final Map<String, DoctorModel> doctorsMap = {};
      for (var doctor in doctors) {
        if (doctor.id.isNotEmpty) {
          doctorsMap[doctor.id] = doctor;
        }
      }
      
      if (doctorsMap.isEmpty) return;
      
      // مسح القديم ثم الحفظ الجديد
      await _doctorsBox.clear();
      await _doctorsBox.putAll(doctorsMap);
      await setLastUpdateTime('doctors');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving doctors: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على جميع الأطباء
  List<DoctorModel> getAllDoctors() {
    return _doctorsBox.values.toList();
  }

  /// الحصول على طبيب معين
  DoctorModel? getDoctor(String id) {
    return _doctorsBox.get(id);
  }

  /// حفظ طبيب واحد
  Future<void> saveDoctor(DoctorModel doctor) async {
    await _doctorsBox.put(doctor.id, doctor);
  }

  /// حذف طبيب
  Future<void> deleteDoctor(String id) async {
    await _doctorsBox.delete(id);
  }

  /// مسح جميع الأطباء
  Future<void> clearDoctors() async {
    await _doctorsBox.clear();
  }

  // ==================== Medical Records Operations ====================

  /// حفظ سجلات طبية لمريض معين
  Future<void> saveMedicalRecords(
    String patientId,
    List<MedicalRecordModel> records,
  ) async {
    try {
      if (records.isEmpty) return;
      
      // حفظ كل سجل باستخدام مفتاح مركب: patientId_recordId
      // استخدام batch operations لتجنب blocking UI thread
      final Map<String, MedicalRecordModel> recordsMap = {};
      for (var record in records) {
        if (record.id.isNotEmpty && patientId.isNotEmpty) {
          recordsMap['${patientId}_${record.id}'] = record;
        }
      }
      
      if (recordsMap.isEmpty) return;
      
      await _medicalRecordsBox.putAll(recordsMap);
      await setLastUpdateTime('medicalRecords_$patientId');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving medical records: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على السجلات الطبية لمريض معين
  List<MedicalRecordModel> getMedicalRecords(String patientId) {
    return _medicalRecordsBox.values
        .where((record) => record.patientId == patientId)
        .toList();
  }

  /// حفظ سجل طبي واحد
  Future<void> saveMedicalRecord(MedicalRecordModel record) async {
    await _medicalRecordsBox.put('${record.patientId}_${record.id}', record);
  }

  /// حذف سجل طبي
  Future<void> deleteMedicalRecord(String patientId, String recordId) async {
    await _medicalRecordsBox.delete('${patientId}_$recordId');
  }

  /// مسح السجلات الطبية لمريض معين
  Future<void> clearMedicalRecords(String patientId) async {
    final keysToDelete = _medicalRecordsBox.keys
        .where((key) => key.toString().startsWith('${patientId}_'))
        .toList();
    for (var key in keysToDelete) {
      await _medicalRecordsBox.delete(key);
    }
  }

  // ==================== Gallery Operations ====================

  /// حفظ صور المعرض لمريض معين
  Future<void> saveGalleryImages(
    String patientId,
    List<GalleryImageModel> images,
  ) async {
    try {
      if (images.isEmpty) return;
      
      // حفظ كل صورة باستخدام مفتاح مركب: patientId_imageId
      // استخدام batch operations لتجنب blocking UI thread
      final Map<String, GalleryImageModel> imagesMap = {};
      for (var image in images) {
        if (image.id.isNotEmpty && patientId.isNotEmpty) {
          imagesMap['${patientId}_${image.id}'] = image;
        }
      }
      
      if (imagesMap.isEmpty) return;
      
      await _galleryBox.putAll(imagesMap);
      await setLastUpdateTime('gallery_$patientId');
    } catch (e, stackTrace) {
      print('❌ [CacheService] Error saving gallery images: $e');
      print('❌ [CacheService] Stack trace: $stackTrace');
      // لا نرمي الخطأ حتى لا يتوقف التطبيق
    }
  }

  /// الحصول على صور المعرض لمريض معين
  List<GalleryImageModel> getGalleryImages(String patientId) {
    return _galleryBox.values
        .where((image) => image.patientId == patientId)
        .toList();
  }

  /// حفظ صورة واحدة
  Future<void> saveGalleryImage(GalleryImageModel image) async {
    await _galleryBox.put('${image.patientId}_${image.id}', image);
  }

  /// حذف صورة
  Future<void> deleteGalleryImage(String patientId, String imageId) async {
    await _galleryBox.delete('${patientId}_$imageId');
  }

  /// مسح صور المعرض لمريض معين
  Future<void> clearGalleryImages(String patientId) async {
    final keysToDelete = _galleryBox.keys
        .where((key) => key.toString().startsWith('${patientId}_'))
        .toList();
    for (var key in keysToDelete) {
      await _galleryBox.delete(key);
    }
  }

  // ==================== General Operations ====================

  /// مسح جميع البيانات المخزنة
  Future<void> clearAll() async {
    await _userBox.clear();
    await _patientsBox.clear();
    await _appointmentsBox.clear();
    await _doctorsBox.clear();
    await _medicalRecordsBox.clear();
    await _galleryBox.clear();
  }

  /// إغلاق جميع الصناديق
  Future<void> closeAll() async {
    await _userBox.close();
    await _patientsBox.close();
    await _appointmentsBox.close();
    await _doctorsBox.close();
    await _medicalRecordsBox.close();
    await _galleryBox.close();
  }

  /// الحصول على حجم البيانات المخزنة
  int get totalCachedItems {
    return _userBox.length +
        _patientsBox.length +
        _appointmentsBox.length +
        _doctorsBox.length +
        _medicalRecordsBox.length +
        _galleryBox.length;
  }

  /// التحقق من وجود بيانات مخزنة
  bool get hasCache {
    return totalCachedItems > 0;
  }

  /// الحصول على آخر وقت تحديث
  DateTime? getLastUpdateTime(String key) {
    final box = Hive.box('metaData');
    final timestamp = box.get('lastUpdate_$key');
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp as int)
        : null;
  }

  /// تحديث وقت التحديث الأخير
  Future<void> setLastUpdateTime(String key) async {
    final box = await Hive.openBox('metaData');
    await box.put('lastUpdate_$key', DateTime.now().millisecondsSinceEpoch);
  }
}
