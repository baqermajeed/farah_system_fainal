import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:frontend_desktop/services/api_service.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/models/doctor_model.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/models/medical_record_model.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';
import 'package:http_parser/http_parser.dart';

class PatientService {
  final _api = ApiService();

  MediaType? _guessImageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return null;
  }

  // جلب بيانات المريض الحالي
  Future<PatientModel> getMyProfile() async {
    try {
      final response = await _api.get(ApiConstants.patientMe);

      if (response.statusCode == 200) {
        final data = response.data;
        return _mapPatientOutToModel(data);
      } else {
        throw ApiException('فشل جلب بيانات المريض');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب بيانات المريض: ${e.toString()}');
    }
  }

  // تحديث ملف المريض الشخصي
  Future<PatientModel> updateMyProfile({
    String? name,
    String? gender,
    int? age,
    String? city,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (gender != null) data['gender'] = gender;
      if (age != null) data['age'] = age;
      if (city != null) data['city'] = city;

      final response = await _api.put(ApiConstants.patientUpdateMe, data: data);

      if (response.statusCode == 200) {
        return _mapPatientOutToModel(response.data);
      } else {
        throw ApiException('فشل تحديث الملف الشخصي');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تحديث الملف الشخصي: ${e.toString()}');
    }
  }

  // إنشاء مريض جديد (للاستقبال)
  Future<PatientModel> createPatientForReception({
    required String name,
    required String phoneNumber,
    required String gender,
    required int age,
    required String city,
    String? visitType,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.receptionCreatePatient,
        data: {
          'name': name,
          'phone': phoneNumber,
          'gender': gender,
          'age': age,
          'city': city,
          if (visitType != null) 'visit_type': visitType,
        },
      );

      if (response.statusCode == 200) {
        return _mapPatientOutToModel(response.data);
      } else {
        throw ApiException('فشل إضافة المريض');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إضافة المريض: ${e.toString()}');
    }
  }

  // رفع صورة بروفايل للمريض (للاستقبال)
  // بعض نسخ الباك-إند ترجع المريض بعد الرفع، وبعضها ترجع 200 بدون جسم.
  Future<PatientModel?> uploadPatientImageForReception({
    required String patientId,
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      final multipartFile = await _buildMultipartFile(
        imageFile: imageFile,
        imageBytes: imageBytes,
        fileName: fileName,
      );

      final response = await _api.post(
        ApiConstants.receptionUploadPatientImage(patientId),
        formData: dio.FormData.fromMap({'image': multipartFile}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final map = data.cast<String, dynamic>();
          if (map['patient'] is Map) {
            return _mapPatientOutToModel(
              (map['patient'] as Map).cast<String, dynamic>(),
            );
          }
          return _mapPatientOutToModel(map);
        }
        return null;
      }
      throw ApiException('فشل رفع صورة المريض');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل رفع صورة المريض: ${e.toString()}');
    }
  }

  Future<dio.MultipartFile> _buildMultipartFile({
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    if (imageBytes != null) {
      final name =
          fileName ?? 'patient_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return dio.MultipartFile.fromBytes(
        imageBytes,
        filename: name,
        contentType: _guessImageContentType(name),
      );
    }

    if (imageFile != null) {
      return dio.MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last.split('\\').last,
        contentType: _guessImageContentType(imageFile.path),
      );
    }

    throw ApiException('No image provided');
  }

  // جلب جميع المرضى (للاستقبال)
  Future<List<PatientModel>> getAllPatients({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.receptionPatients,
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => _mapPatientOutToModel(json)).toList();
      } else {
        throw ApiException('فشل جلب قائمة المرضى');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب قائمة المرضى: ${e.toString()}');
    }
  }

  // ⭐ البحث عن المرضى (للاستقبال) - بنفس طريقة eversheen
  Future<List<PatientModel>> searchPatients({
    required String searchQuery,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.receptionPatients,
        queryParameters: {'skip': skip, 'limit': limit, 'search': searchQuery},
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => _mapPatientOutToModel(json)).toList();
      } else {
        throw ApiException('فشل البحث عن المرضى');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل البحث عن المرضى: ${e.toString()}');
    }
  }

  // جلب قائمة جميع الأطباء (للاستقبال)
  Future<List<DoctorModel>> getAllDoctors() async {
    try {
      final response = await _api.get(ApiConstants.receptionDoctors);

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => DoctorModel.fromJson(json)).toList();
      } else {
        throw ApiException('فشل جلب قائمة الأطباء');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب قائمة الأطباء: ${e.toString()}');
    }
  }

  // جلب الأطباء المرتبطين بمريض
  Future<List<DoctorModel>> getPatientDoctors(String patientId) async {
    try {
      final response = await _api.get(
        ApiConstants.receptionPatientDoctors(patientId),
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => DoctorModel.fromJson(json)).toList();
      } else {
        throw ApiException('فشل جلب أطباء المريض');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب أطباء المريض: ${e.toString()}');
    }
  }

  // ربط المريض بقائمة من الأطباء
  Future<bool> assignPatientToDoctors(
    String patientId,
    List<String> doctorIds,
  ) async {
    try {
      final response = await _api.post(
        '${ApiConstants.receptionAssignPatient}?patient_id=$patientId',
        data: doctorIds,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw ApiException('فشل ربط المريض بالأطباء');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل ربط المريض بالأطباء: ${e.toString()}');
    }
  }

  // جلب مواعيد المريض
  Future<Map<String, List<AppointmentModel>>> getMyAppointments() async {
    try {
      final response = await _api.get(ApiConstants.patientAppointments);

      if (response.statusCode == 200) {
        final data = response.data;
        final primary = (data['primary'] as List? ?? [])
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        final secondary = (data['secondary'] as List? ?? [])
            .map((json) => AppointmentModel.fromJson(json))
            .toList();

        return {'primary': primary, 'secondary': secondary};
      } else {
        throw ApiException('فشل جلب المواعيد');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب المواعيد: ${e.toString()}');
    }
  }

  // جلب سجلات المريض (Notes)
  Future<List<MedicalRecordModel>> getMyNotes() async {
    try {
      final response = await _api.get(ApiConstants.patientNotes);

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => MedicalRecordModel.fromJson(json)).toList();
      } else {
        throw ApiException('فشل جلب السجلات');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب السجلات: ${e.toString()}');
    }
  }

  // جلب معرض الصور
  Future<List<Map<String, dynamic>>> getMyGallery() async {
    try {
      final response = await _api.get(ApiConstants.patientGallery);

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw ApiException('فشل جلب المعرض');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب المعرض: ${e.toString()}');
    }
  }

  // جلب صور المعرض لمريض معيّن كما يراها موظف الاستقبال
  // (فقط الصور التي رفعها هذا الموظف نفسه)
  Future<List<GalleryImageModel>> getReceptionPatientGallery(
    String patientId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.receptionPatientGallery(patientId),
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data
            .map(
              (json) => GalleryImageModel.fromJson(
                (json as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      } else {
        throw ApiException('فشل جلب صور المعرض (الاستقبال)');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب صور المعرض (الاستقبال): ${e.toString()}');
    }
  }

  // رفع صورة إلى معرض المريض من واجهة الاستقبال
  Future<GalleryImageModel> uploadReceptionGalleryImage({
    required String patientId,
    required File imageFile,
    String? note,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        'image': await dio.MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last.split('\\').last,
        ),
        if (note != null && note.isNotEmpty) 'note': note,
      });

      final response = await _api.post(
        ApiConstants.receptionPatientGallery(patientId),
        formData: formData,
      );

      if (response.statusCode == 200) {
        return GalleryImageModel.fromJson(
          (response.data as Map).cast<String, dynamic>(),
        );
      } else {
        throw ApiException('فشل رفع الصورة (الاستقبال)');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل رفع الصورة (الاستقبال): ${e.toString()}');
    }
  }

  // جلب معلومات الطبيب المرتبط بالمريض
  Future<Map<String, dynamic>> getMyDoctor() async {
    try {
      final response = await _api.get(ApiConstants.patientDoctor);

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'id': data['id'] ?? '',
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'imageUrl': data['imageUrl'] ?? data['image_url'],
        };
      } else {
        throw ApiException('فشل جلب معلومات الطبيب');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب معلومات الطبيب: ${e.toString()}');
    }
  }

  // جلب بيانات المريض والأطباء المرتبطين به من QR code (نفس مبدأ الموبايل)
  Future<Map<String, dynamic>?> getPatientByQrCodeWithDoctors(
    String qrCode,
  ) async {
    try {
      print(
        '🔍 [Desktop PatientService] getPatientByQrCodeWithDoctors called with QR code: $qrCode',
      );
      final response = await _api.get(ApiConstants.qrScan(qrCode));

      print(
        '📡 [Desktop PatientService] QR scan response status: ${response.statusCode}',
      );
      print(
        '📡 [Desktop PatientService] QR scan response data: ${response.data}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        print(
          '📋 [Desktop PatientService] Response data type: ${data.runtimeType}',
        );
        print(
          '📋 [Desktop PatientService] Response keys: ${data.keys.toList()}',
        );
        print(
          '📋 [Desktop PatientService] Patient in response: ${data['patient']}',
        );
        print(
          '📋 [Desktop PatientService] Doctors in response: ${data['doctors']}',
        );

        if (!data.containsKey('patient') || data['patient'] == null) {
          print(
            '⚠️ [Desktop PatientService] Patient is null or missing in response',
          );
          return null;
        }

        try {
          final patient = _mapPatientOutToModel(
            data['patient'] as Map<String, dynamic>,
          );
          final doctorsList = data['doctors'];
          final doctors = (doctorsList != null && doctorsList is List)
              ? doctorsList
                    .map(
                      (json) =>
                          DoctorModel.fromJson(json as Map<String, dynamic>),
                    )
                    .toList()
              : <DoctorModel>[];

          print(
            '✅ [Desktop PatientService] Successfully parsed patient: ${patient.name} and ${doctors.length} doctors',
          );

          return {'patient': patient, 'doctors': doctors};
        } catch (e) {
          print('❌ [Desktop PatientService] Error parsing patient data: $e');
          rethrow;
        }
      } else {
        print(
          '❌ [Desktop PatientService] Unexpected status code: ${response.statusCode}',
        );
        throw ApiException('فشل جلب بيانات المريض');
      }
    } catch (e) {
      print(
        '❌ [Desktop PatientService] Error in getPatientByQrCodeWithDoctors: $e',
      );
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب بيانات المريض: ${e.toString()}');
    }
  }

  // جلب قائمة الأطباء المرتبطين بالمريض
  Future<List<Map<String, dynamic>>> getMyDoctors() async {
    try {
      final response = await _api.get(ApiConstants.patientDoctors);

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data
            .map(
              (doctor) => {
                'id': doctor['id'] ?? '',
                'name': doctor['name'] ?? '',
                'phone': doctor['phone'] ?? '',
                'imageUrl': doctor['imageUrl'] ?? doctor['image_url'],
              },
            )
            .toList();
      } else {
        throw ApiException('فشل جلب قائمة الأطباء');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب قائمة الأطباء: ${e.toString()}');
    }
  }

  // تحويل PatientOut من Backend إلى PatientModel
  PatientModel _mapPatientOutToModel(Map<String, dynamic> json) {
    List<String> doctorIds = [];
    if (json['doctor_ids'] != null) {
      doctorIds = List<String>.from(json['doctor_ids']);
    } else if (json['doctorIds'] != null) {
      doctorIds = List<String>.from(json['doctorIds']);
    } else {
      if (json['primary_doctor_id'] != null) {
        doctorIds.add(json['primary_doctor_id']);
      }
      if (json['secondary_doctor_id'] != null) {
        doctorIds.add(json['secondary_doctor_id']);
      }
    }

    return PatientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      city: json['city'] ?? '',
      visitType: json['visit_type'] ?? json['visitType'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      doctorIds: doctorIds,
      treatmentHistory: json['treatment_type'] != null
          ? [json['treatment_type']]
          : null,
      qrCodeData: json['qr_code_data'] ?? json['qrCodeData'],
      qrImagePath: json['qr_image_path'] ?? json['qrImagePath'],
      paymentMethods: json['payment_methods'] != null
          ? List<String>.from(json['payment_methods'])
          : (json['paymentMethods'] != null
                ? List<String>.from(json['paymentMethods'])
                : null),
      activityStatus:
          (json['activity_status'] ?? json['activityStatus'] ?? 'pending')
              .toString(),
    );
  }

  Future<PatientModel> activatePatient(String patientId) async {
    try {
      final response = await _api.post(
        ApiConstants.receptionActivatePatient(patientId),
      );
      if (response.statusCode == 200) {
        return _mapPatientOutToModel(
          (response.data as Map).cast<String, dynamic>(),
        );
      }
      throw ApiException('فشل تنشيط المريض');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل تنشيط المريض: ${e.toString()}');
    }
  }
}
