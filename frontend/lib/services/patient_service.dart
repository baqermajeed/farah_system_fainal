import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
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
  Future<void> uploadPatientImageForReception({
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

      if (response.statusCode == 200) return;
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
      print('📅 [PatientService] getMyAppointments called');
      print(
        '📅 [PatientService] Endpoint: ${ApiConstants.patientAppointments}',
      );
      final response = await _api.get(ApiConstants.patientAppointments);
      print('📅 [PatientService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('📅 [PatientService] Response data: $data');
        final primary = (data['primary'] as List? ?? [])
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
        final secondary = (data['secondary'] as List? ?? [])
            .map((json) => AppointmentModel.fromJson(json))
            .toList();

        print(
          '📅 [PatientService] Parsed ${primary.length} primary and ${secondary.length} secondary appointments',
        );
        return {'primary': primary, 'secondary': secondary};
      } else {
        print(
          '❌ [PatientService] Unexpected status code: ${response.statusCode}',
        );
        throw ApiException('فشل جلب المواعيد');
      }
    } catch (e, stackTrace) {
      print('❌ [PatientService] Error in getMyAppointments: $e');
      print('❌ [PatientService] Stack trace: $stackTrace');
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

  // جلب قائمة الأطباء المرتبطين بالمريض
  Future<List<Map<String, dynamic>>> getMyDoctors() async {
    try {
      final response = await _api.get(ApiConstants.patientDoctors);

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((doctor) => {
          'id': doctor['id'] ?? '',
          'name': doctor['name'] ?? '',
          'phone': doctor['phone'] ?? '',
          'imageUrl': doctor['imageUrl'] ?? doctor['image_url'],
        }).toList();
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
  // جلب بيانات المريض من QR code
  Future<PatientModel?> getPatientByQrCode(String qrCode) async {
    try {
      final response = await _api.get(ApiConstants.qrScan(qrCode));

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['patient'] == null) {
          return null;
        }
        return _mapPatientOutToModel(data['patient']);
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

  // جلب بيانات المريض والأطباء المرتبطين به من QR code
  Future<Map<String, dynamic>?> getPatientByQrCodeWithDoctors(String qrCode) async {
    try {
      print('🔍 [PatientService] getPatientByQrCodeWithDoctors called with QR code: $qrCode');
      final response = await _api.get(ApiConstants.qrScan(qrCode));
      
      print('📡 [PatientService] QR scan response status: ${response.statusCode}');
      print('📡 [PatientService] QR scan response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        print('📋 [PatientService] Response data type: ${data.runtimeType}');
        print('📋 [PatientService] Response keys: ${data.keys.toList()}');
        print('📋 [PatientService] Patient in response: ${data['patient']}');
        print('📋 [PatientService] Doctors in response: ${data['doctors']}');
        
        // التحقق من وجود patient في response
        if (!data.containsKey('patient') || data['patient'] == null) {
          print('⚠️ [PatientService] Patient is null or missing in response');
          return null;
        }
        
        try {
          final patient = _mapPatientOutToModel(data['patient'] as Map<String, dynamic>);
          final doctorsList = data['doctors'];
          final doctors = (doctorsList != null && doctorsList is List)
              ? doctorsList
                  .map((json) => DoctorModel.fromJson(json as Map<String, dynamic>))
                  .toList()
              : <DoctorModel>[];
          print('✅ [PatientService] Successfully parsed patient: ${patient.name} and ${doctors.length} doctors');
          return {
            'patient': patient,
            'doctors': doctors,
          };
        } catch (e) {
          print('❌ [PatientService] Error parsing patient data: $e');
          rethrow;
        }
      } else {
        print('❌ [PatientService] Unexpected status code: ${response.statusCode}');
        throw ApiException('فشل جلب بيانات المريض');
      }
    } catch (e) {
      print('❌ [PatientService] Error in getPatientByQrCodeWithDoctors: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب بيانات المريض: ${e.toString()}');
    }
  }

  PatientModel _mapPatientOutToModel(Map<String, dynamic> json) {
    // Support both old format (primary_doctor_id, secondary_doctor_id) and new format (doctor_ids)
    List<String> doctorIds = [];
    if (json['doctor_ids'] != null) {
      doctorIds = List<String>.from(json['doctor_ids']);
    } else if (json['doctorIds'] != null) {
      doctorIds = List<String>.from(json['doctorIds']);
    } else {
      // Backward compatibility: convert old format to new format
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
      imageUrl: json['imageUrl'] ?? json['image_url'],
      doctorIds: doctorIds,
      treatmentHistory: json['treatment_type'] != null
          ? [json['treatment_type']]
          : null,
      qrCodeData: json['qr_code_data'] ?? json['qrCodeData'],
      qrImagePath: json['qr_image_path'] ?? json['qrImagePath'],
    );
  }
}
