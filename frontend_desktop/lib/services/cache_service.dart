import 'dart:async';
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
import 'package:frontend_desktop/models/queue_entry_model.dart';

/// خدمة التخزين المحلي باستخدام Hive
/// مطابق 100% لطريقة مشروع eversheen
class CacheService {
  static const String _userBoxName = 'userBox';
  static const String _patientsBoxName = 'patientsBox';
  static const String _appointmentsBoxName = 'appointmentsBox';
  static const String _doctorsBoxName = 'doctorsBox';
  static const String _medicalRecordsBoxName = 'medicalRecordsBox';
  static const String _galleryBoxName = 'galleryBox';
  static const String _queueBoxName = 'queueBox';
  static const String _dentalChartsBoxName = 'dentalChartsBox';
  /// زد الرقم عند تغيير مخطط أي نموذج Hive لإسقاط الكاش القديم تلقائياً.
  static const int _cacheSchemaVersion = 3;
  static const String _schemaVersionKey = 'cache_schema_version';

  // Boxes
  late Box<UserModel> _userBox;
  late Box<PatientModel> _patientsBox;
  late Box<AppointmentModel> _appointmentsBox;
  late Box<DoctorModel> _doctorsBox;
  late Box<MedicalRecordModel> _medicalRecordsBox;
  late Box<GalleryImageModel> _galleryBox;
  late Box _queueBox;
  late Box _dentalChartsBox;

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();
  Future<void>? _initFuture;
  bool _isInitialized = false;
  String? _activeHivePath;

  /// تهيئة Hive وفتح الصناديق
  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _initImpl();
    try {
      await _initFuture!;
      _isInitialized = true;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initImpl() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final hiveDir = Directory(p.join(appSupportDir.path, 'hive'));
    if (!await hiveDir.exists()) {
      await hiveDir.create(recursive: true);
    }

    await Hive.initFlutter(hiveDir.path);
    _activeHivePath = hiveDir.path;

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

    try {
      await _migrateCacheSchemaIfNeeded();
      await _openAllBoxes();
    } catch (e) {
      print('⚠️ [CacheService] Primary hive open failed: $e');
      // Last-resort recovery:
      // if the primary hive directory is locked/corrupted, switch to a fresh
      // recovery directory so the app can continue running.
      try {
        await Hive.close();
      } catch (_) {}
      final recoveryDir = Directory(
        p.join(
          appSupportDir.path,
          'hive_recovery_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      if (!await recoveryDir.exists()) {
        await recoveryDir.create(recursive: true);
      }
      await Hive.initFlutter(recoveryDir.path);
      _activeHivePath = recoveryDir.path;
      await _migrateCacheSchemaIfNeeded();
      await _openAllBoxes();
    }
  }

  Future<void> _migrateCacheSchemaIfNeeded() async {
    try {
      final meta = await Hive.openBox('metaData');
      final current = meta.get(_schemaVersionKey);
      final currentVersion = current is int
          ? current
          : int.tryParse('$current') ?? 0;
      if (currentVersion == _cacheSchemaVersion) return;

      print(
        '⚠️ [CacheService] Cache schema $currentVersion -> $_cacheSchemaVersion, resetting typed boxes...',
      );

      // أسقط الصناديق المعرّضة لكسر المخطط فقط
      // (لا تمس المستخدم / الطابور / مخطط الأسنان المحلي)
      for (final boxName in [
        _appointmentsBoxName,
        _patientsBoxName,
        _medicalRecordsBoxName,
        _galleryBoxName,
        _doctorsBoxName,
      ]) {
        await _cleanupCorruptedBox(boxName);
      }

      await meta.put(_schemaVersionKey, _cacheSchemaVersion);
    } catch (e) {
      print('⚠️ [CacheService] Schema migration failed: $e');
      // لا نرمي الخطأ — التنظيف best-effort حتى لا يوقف الإقلاع
      await _cleanupCorruptedBox(_appointmentsBoxName);
    }
  }

  Future<void> _openAllBoxes() async {
    _userBox = await _openBoxWithRetry<UserModel>(_userBoxName);
    _patientsBox = await _openBoxWithRetry<PatientModel>(_patientsBoxName);
    _appointmentsBox = await _openBoxWithRetry<AppointmentModel>(
      _appointmentsBoxName,
    );
    _doctorsBox = await _openBoxWithRetry<DoctorModel>(_doctorsBoxName);
    _medicalRecordsBox = await _openBoxWithRetry<MedicalRecordModel>(
      _medicalRecordsBoxName,
    );
    _galleryBox = await _openBoxWithRetry<GalleryImageModel>(_galleryBoxName);
    _queueBox = await _openBoxWithRetry<dynamic>(_queueBoxName);
    _dentalChartsBox = await _openBoxWithRetry<dynamic>(_dentalChartsBoxName);
  }

  Future<Box<T>> _openBoxWithRetry<T>(
    String boxName, {
    int attempts = 5,
    Duration baseDelay = const Duration(milliseconds: 250),
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final box = await Hive.openBox<T>(boxName);
        // قراءة أولية لاكتشاف التلف مبكراً قبل استخدام الصندوق
        try {
          box.length;
          if (box.isNotEmpty) {
            box.getAt(0);
          }
        } catch (readError) {
          print(
            '⚠️ [CacheService] Box "$boxName" unreadable, recreating: $readError',
          );
          try {
            await box.close();
          } catch (_) {}
          try {
            await _cleanupCorruptedBox(boxName);
          } catch (_) {}
          continue;
        }
        return box;
      } catch (e, st) {
        lastError = e;
        final message = e.toString();
        var isLockError =
            e is PathAccessException || _isLockErrorMessage(message);
        final isCorruptedBox = e is RangeError ||
            e is TypeError ||
            message.contains('Not enough bytes available') ||
            message.contains('RangeError') ||
            message.contains('type ') ||
            message.contains('Wrong checksum') ||
            message.contains('invalid frame');

        print('⚠️ [CacheService] openBox("$boxName") attempt ${i + 1}: $e');

        // If cache data is corrupted, drop this box and recreate it.
        // This keeps the app alive after model/schema cache changes.
        if (isCorruptedBox) {
          await _cleanupCorruptedBox(boxName);
          // إذا بقي الملف مقفولاً نعيد المحاولة بانتظار قصير
          if (_isLockErrorMessage(message)) {
            isLockError = true;
          } else {
            continue;
          }
        }

        if (!isLockError || i == attempts - 1) {
          Error.throwWithStackTrace(e, st);
        }
        await Future<void>.delayed(
          Duration(milliseconds: baseDelay.inMilliseconds * (i + 1)),
        );
      }
    }
    throw lastError ?? Exception('Failed to open Hive box: $boxName');
  }

  bool _isLockErrorMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('lock failed') ||
        lower.contains('pathaccessexception') ||
        lower.contains('being used by another process') ||
        lower.contains('locked a portion') ||
        lower.contains('errno = 32') ||
        lower.contains('errno = 33') ||
        lower.contains('access is denied');
  }

  /// حذف صندوق تالف — لا يرمي استثناء أبداً (ملفات Hive قد تكون مقفولة من عملية أخرى).
  Future<void> _cleanupCorruptedBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    } catch (_) {}

    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {}

    final hivePath = _activeHivePath;
    if (hivePath == null || hivePath.isEmpty) return;

    await _deleteHiveFileBestEffort(p.join(hivePath, '$boxName.hive'));
    await _deleteHiveFileBestEffort(p.join(hivePath, '$boxName.lock'));

    // Give filesystem/lock manager a tiny cooldown before re-open.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _deleteHiveFileBestEffort(String path) async {
    final file = File(path);
    for (var i = 0; i < 5; i++) {
      try {
        if (!await file.exists()) return;
        await file.delete();
        return;
      } on PathAccessException catch (e) {
        print(
          '⚠️ [CacheService] Locked file delete retry ${i + 1}: $path ($e)',
        );
      } on FileSystemException catch (e) {
        print(
          '⚠️ [CacheService] File delete retry ${i + 1}: $path ($e)',
        );
      } catch (e) {
        print('⚠️ [CacheService] File delete failed: $path ($e)');
        break;
      }
      await Future<void>.delayed(Duration(milliseconds: 150 * (i + 1)));
    }

    // إن فشل الحذف بسبب القفل: أعد تسمية الملف حتى يفتح Hive ملفاً جديداً
    try {
      if (await file.exists()) {
        final tombstone = File(
          '$path.corrupt_${DateTime.now().millisecondsSinceEpoch}',
        );
        await file.rename(tombstone.path);
        print('⚠️ [CacheService] Renamed locked file -> ${tombstone.path}');
      }
    } catch (e) {
      print('⚠️ [CacheService] Could not remove/rename $path: $e');
    }
  }

  // ==================== Queue Operations ====================

  Future<void> saveQueueState({
    required String dateKey,
    required int nextNumber,
    required List<QueueEntry> entries,
  }) async {
    try {
      await _queueBox.put('state', {
        'date': dateKey,
        'nextNumber': nextNumber,
        'entries': entries.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      print('❌ [CacheService] Error saving queue: $e');
    }
  }

  ({String date, int nextNumber, List<QueueEntry> entries})? loadQueueState() {
    try {
      final raw = _queueBox.get('state');
      if (raw is! Map) return null;

      final date = raw['date']?.toString() ?? '';
      final nextNumber = raw['nextNumber'] is int
          ? raw['nextNumber'] as int
          : int.tryParse('${raw['nextNumber']}') ?? 1;
      final entriesRaw = raw['entries'];

      final entries = <QueueEntry>[];
      if (entriesRaw is List) {
        for (final item in entriesRaw) {
          if (item is Map) {
            entries.add(
              QueueEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      return (date: date, nextNumber: nextNumber, entries: entries);
    } catch (e) {
      print('❌ [CacheService] Error loading queue: $e');
      return null;
    }
  }

  Future<void> clearQueueState() async {
    try {
      await _queueBox.delete('state');
    } catch (e) {
      print('❌ [CacheService] Error clearing queue: $e');
    }
  }

  Future<void> reloadQueueBox() async {
    if (_queueBox.isOpen) {
      await _queueBox.close();
    }
    _queueBox = await Hive.openBox(_queueBoxName);
  }

  // ==================== Dental Chart Operations ====================

  /// حفظ مخطط الأسنان والملاحظات لمريض معين
  Future<void> saveDentalChart({
    required String patientId,
    required Map<String, List<String>> chart,
    required Map<String, List<Map<String, dynamic>>> notes,
    String? selectedTooth,
  }) async {
    try {
      if (patientId.isEmpty) return;

      await _dentalChartsBox.put(patientId, {
        'chart': chart.map(
          (tooth, statuses) => MapEntry(tooth, List<String>.from(statuses)),
        ),
        'notes': notes.map(
          (tooth, entries) => MapEntry(
            tooth,
            entries
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList(),
          ),
        ),
        if (selectedTooth != null && selectedTooth.isNotEmpty)
          'selectedTooth': selectedTooth,
      });
    } catch (e) {
      print('❌ [CacheService] Error saving dental chart: $e');
    }
  }

  /// جلب مخطط الأسنان والملاحظات لمريض معين
  ({
    Map<String, List<String>> chart,
    Map<String, List<Map<String, dynamic>>> notes,
    String? selectedTooth,
  })? getDentalChart(String patientId) {
    try {
      if (patientId.isEmpty) return null;
      final raw = _dentalChartsBox.get(patientId);
      if (raw is! Map) return null;

      final data = Map<String, dynamic>.from(raw);
      final chart = <String, List<String>>{};
      final notes = <String, List<Map<String, dynamic>>>{};

      final chartRaw = data['chart'];
      if (chartRaw is Map) {
        chartRaw.forEach((key, value) {
          final tooth = key.toString();
          if (value is List) {
            chart[tooth] = value.map((e) => e.toString()).toList();
          } else if (value is String && value.isNotEmpty) {
            chart[tooth] = [value];
          }
        });
      }

      final notesRaw = data['notes'];
      if (notesRaw is Map) {
        notesRaw.forEach((key, value) {
          final tooth = key.toString();
          final entries = <Map<String, dynamic>>[];
          if (value is List) {
            for (final item in value) {
              if (item is Map) {
                entries.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (value is Map) {
            // توافق مع صيغة قديمة: ملاحظة واحدة لكل سن
            entries.add(Map<String, dynamic>.from(value));
          }
          if (entries.isNotEmpty) {
            notes[tooth] = entries;
          }
        });
      }

      final selectedTooth = data['selectedTooth']?.toString();
      return (
        chart: chart,
        notes: notes,
        selectedTooth: selectedTooth != null && selectedTooth.isNotEmpty
            ? selectedTooth
            : null,
      );
    } catch (e) {
      print('❌ [CacheService] Error loading dental chart: $e');
      return null;
    }
  }

  Future<void> deleteDentalChart(String patientId) async {
    try {
      await _dentalChartsBox.delete(patientId);
    } catch (e) {
      print('❌ [CacheService] Error deleting dental chart: $e');
    }
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

  int _comparePatientsNewestFirst(PatientModel a, PatientModel b) {
    final aDate = DateTime.tryParse(a.createdAt ?? '');
    final bDate = DateTime.tryParse(b.createdAt ?? '');
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    return b.id.compareTo(a.id);
  }

  /// الحصول على جميع المرضى (مرتبة حسب الأحدث أولاً)
  List<PatientModel> getAllPatients() {
    try {
      final all = _patientsBox.values.toList();
      all.sort(_comparePatientsNewestFirst);
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
      all.sort(_comparePatientsNewestFirst);
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
    await _dentalChartsBox.clear();
  }

  /// إغلاق جميع الصناديق
  Future<void> closeAll() async {
    await _userBox.close();
    await _patientsBox.close();
    await _appointmentsBox.close();
    await _doctorsBox.close();
    await _medicalRecordsBox.close();
    await _galleryBox.close();
    await _queueBox.close();
    await _dentalChartsBox.close();
  }

  /// الحصول على حجم البيانات المخزنة
  int get totalCachedItems {
    return _userBox.length +
        _patientsBox.length +
        _appointmentsBox.length +
        _doctorsBox.length +
        _medicalRecordsBox.length +
        _galleryBox.length +
        _dentalChartsBox.length;
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
