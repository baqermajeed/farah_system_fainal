import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/models/gallery_image_model.dart';
import 'package:http_parser/http_parser.dart';

class DoctorService {
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

  // رفع صورة بروفايل للمريض (تحديث imageUrl)
  Future<PatientModel> uploadPatientImage({
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

      final formData = dio.FormData.fromMap({
        'image': multipartFile,
      });

      final response = await _api.post(
        ApiConstants.doctorUploadPatientImage(patientId),
        formData: formData,
      );

      if (response.statusCode == 200) {
        return _mapPatientOutToModel((response.data as Map).cast<String, dynamic>());
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

  // إضافة مريض جديد وربطه بالطبيب
  Future<PatientModel> addPatient({
    required String name,
    required String phoneNumber,
    required String gender,
    required int age,
    required String city,
  }) async {
    try {
      print('🏥 [DoctorService] Adding patient...');
      print('   📋 Endpoint: ${ApiConstants.doctorAddPatient}');
      print('   👤 Name: $name, Phone: $phoneNumber');
      
      final response = await _api.post(
        ApiConstants.doctorAddPatient,
        data: {
          'name': name,
          'phone': phoneNumber,
          'gender': gender,
          'age': age,
          'city': city,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final patient = _mapPatientOutToModel(data);
        print('✅ [DoctorService] Patient added successfully');
        return patient;
      } else {
        print('❌ [DoctorService] Failed with status: ${response.statusCode}');
        throw ApiException('فشل إضافة المريض');
      }
    } catch (e) {
      print('❌ [DoctorService] Error: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إضافة المريض: ${e.toString()}');
    }
  }

  // جلب قائمة المرضى للطبيب
  Future<List<PatientModel>> getMyPatients({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      print('🏥 [DoctorService] Fetching patients for doctor...');
      print('   📋 Endpoint: ${ApiConstants.doctorPatients}');
      print('   📋 Skip: $skip, Limit: $limit');
      
      final response = await _api.get(
        ApiConstants.doctorPatients,
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      print('🏥 [DoctorService] Response status: ${response.statusCode}');
      print('🏥 [DoctorService] Response data type: ${response.data.runtimeType}');
      print('🏥 [DoctorService] Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Handle different response formats
        dynamic responseData = response.data;
        
        // Check if it's already a List
        if (responseData is! List) {
          print('⚠️ [DoctorService] Response is not a List, trying to parse...');
          // Maybe it's wrapped in a map?
          if (responseData is Map) {
            if (responseData.containsKey('data')) {
              responseData = responseData['data'];
            } else if (responseData.containsKey('patients')) {
              responseData = responseData['patients'];
            } else {
              print('❌ [DoctorService] Response is a Map but no data/patients key found');
              print('   Keys: ${responseData.keys}');
              throw ApiException('تنسيق استجابة غير متوقع من السيرفر');
            }
          } else {
            print('❌ [DoctorService] Response is neither List nor Map');
            throw ApiException('تنسيق استجابة غير متوقع من السيرفر');
          }
        }
        
        final data = responseData as List;
        print('🏥 [DoctorService] Found ${data.length} patients');
        
        if (data.isEmpty) {
          print('⚠️ [DoctorService] No patients found. Make sure patients are assigned to this doctor.');
          print('   💡 Patients need to have primary_doctor_id or secondary_doctor_id set.');
        } else {
          print('🏥 [DoctorService] First patient sample: ${data.isNotEmpty ? data.first : "N/A"}');
        }
        
        final patients = data
            .map((json) => _mapPatientOutToModel(json))
            .toList();
        
        print('✅ [DoctorService] Successfully mapped ${patients.length} patients');
        return patients;
      } else {
        print('❌ [DoctorService] Failed with status: ${response.statusCode}');
        print('❌ [DoctorService] Response: ${response.data}');
        throw ApiException('فشل جلب قائمة المرضى');
      }
    } catch (e) {
      print('❌ [DoctorService] Error: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب قائمة المرضى: ${e.toString()}');
    }
  }

  Future<List<PatientModel>> getInactivePatients({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.doctorInactivePatients,
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data
            .map((json) => _mapPatientOutToModel(json))
            .toList();
      } else {
        throw ApiException('فشل جلب المرضى غير النشطين');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب المرضى غير النشطين: ${e.toString()}');
    }
  }

  // تحديد نوع العلاج للمريض
  Future<PatientModel> setTreatmentType({
    required String patientId,
    required String treatmentType,
  }) async {
    try {
      final response = await _api.post(
        '${ApiConstants.doctorPatientTreatment(patientId)}?treatment_type=$treatmentType',
      );

      if (response.statusCode == 200) {
        return _mapPatientOutToModel(response.data);
      } else {
        throw ApiException('فشل تحديث نوع العلاج');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تحديث نوع العلاج: ${e.toString()}');
    }
  }

  // إضافة سجل (ملاحظة) للمريض
  Future<MedicalRecordModel> addNote({
    required String patientId,
    String? note,
    File? imageFile,
    List<File>? imageFiles,
  }) async {
    try {
      print('📝 [DoctorService] Adding note for patient: $patientId');
      
      // استخدام imageFiles إذا كان متوفراً، وإلا استخدم imageFile
      final filesToSend = imageFiles ?? (imageFile != null ? [imageFile] : []);
      
      // إعداد FormData
      final formData = dio.FormData.fromMap({
        if (note != null && note.isNotEmpty) 'note': note,
      });
      
      // إضافة جميع الصور
      print('📸 [DoctorService] Adding ${filesToSend.length} images to form data');
      for (var i = 0; i < filesToSend.length; i++) {
        final file = filesToSend[i];
        final multipartFile = await dio.MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last.split('\\').last,
        );
        formData.files.add(MapEntry(
          'images',
          multipartFile,
        ));
        print('📸 [DoctorService] Added image ${i + 1}/${filesToSend.length}: ${file.path}');
      }
      
      final response = await _api.post(
        ApiConstants.doctorPatientNotes(patientId),
        formData: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [DoctorService] Note added successfully');
        return MedicalRecordModel.fromJson(response.data);
      } else {
        throw ApiException('فشل إضافة السجل');
      }
    } catch (e) {
      print('❌ [DoctorService] Error adding note: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إضافة السجل: ${e.toString()}');
    }
  }

  // تحديث سجل (ملاحظة) للمريض
  Future<MedicalRecordModel> updateNote({
    required String patientId,
    required String noteId,
    String? note,
    List<File>? imageFiles,
  }) async {
    try {
      print('📝 [DoctorService] Updating note $noteId for patient: $patientId');
      
      // إعداد FormData
      final formData = dio.FormData.fromMap({
        if (note != null && note.isNotEmpty) 'note': note,
      });
      
      // إضافة جميع الصور
      if (imageFiles != null && imageFiles.isNotEmpty) {
        print('📸 [DoctorService] Adding ${imageFiles.length} images to form data');
        for (var i = 0; i < imageFiles.length; i++) {
          final file = imageFiles[i];
          final multipartFile = await dio.MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last.split('\\').last,
          );
          formData.files.add(MapEntry(
            'images',
            multipartFile,
          ));
          print('📸 [DoctorService] Added image ${i + 1}/${imageFiles.length}: ${file.path}');
        }
      }
      
      final response = await _api.put(
        ApiConstants.doctorUpdateNote(patientId, noteId),
        formData: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [DoctorService] Note updated successfully');
        return MedicalRecordModel.fromJson(response.data);
      } else {
        throw ApiException('فشل تحديث السجل');
      }
    } catch (e) {
      print('❌ [DoctorService] Error updating note: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تحديث السجل: ${e.toString()}');
    }
  }

  // حذف سجل (ملاحظة) للمريض
  Future<void> deleteNote({
    required String patientId,
    required String noteId,
  }) async {
    try {
      print('🗑️ [DoctorService] Deleting note $noteId for patient: $patientId');
      
      final response = await _api.delete(
        ApiConstants.doctorDeleteNote(patientId, noteId),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ [DoctorService] Note deleted successfully');
      } else {
        throw ApiException('فشل حذف السجل');
      }
    } catch (e) {
      print('❌ [DoctorService] Error deleting note: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل حذف السجل: ${e.toString()}');
    }
  }

  // إضافة موعد جديد
  Future<AppointmentModel> addAppointment({
    required String patientId,
    required DateTime scheduledAt,
    String? note,
    File? imageFile,
    List<File>? imageFiles,
  }) async {
    try {
      print('📅 [DoctorService] Adding appointment for patient: $patientId');
      
      // استخدام imageFiles إذا كان متوفراً، وإلا استخدم imageFile
      final filesToSend = imageFiles ?? (imageFile != null ? [imageFile] : []);
      
      dio.Response response;
      
      // إعداد FormData مع عدة صور
      final formData = dio.FormData.fromMap({
            'scheduled_at': scheduledAt.toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
      
      // إضافة جميع الصور
      print('📸 [DoctorService] Adding ${filesToSend.length} images to form data');
      for (var i = 0; i < filesToSend.length; i++) {
        final file = filesToSend[i];
        final multipartFile = await dio.MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last.split('\\').last,
        );
        formData.files.add(MapEntry(
          'images',
          multipartFile,
        ));
        print('📸 [DoctorService] Added image ${i + 1}/${filesToSend.length}: ${file.path}');
      }
      print('📸 [DoctorService] Total files in formData: ${formData.files.length}');
      
        response = await _api.post(
          ApiConstants.doctorPatientAppointments(patientId),
        formData: formData,
        );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [DoctorService] Appointment added successfully');
        try {
          // التأكد من أن response.data هو Map
          final data = response.data;
          if (data is Map<String, dynamic>) {
            return AppointmentModel.fromJson(data);
          } else {
            print('⚠️ [DoctorService] Unexpected response data type: ${data.runtimeType}');
            // إنشاء AppointmentModel افتراضي إذا فشل parsing
            throw ApiException('خطأ في معالجة بيانات الموعد');
          }
        } catch (parseError) {
          print('❌ [DoctorService] Error parsing appointment response: $parseError');
          print('   Response data: ${response.data}');
          // رغم الخطأ في parsing، الموعد تمت إضافته بنجاح في Backend
          // لذا يمكن إرجاع null أو إعادة تحميل المواعيد
          throw ApiException('تمت إضافة الموعد لكن حدث خطأ في معالجة البيانات');
        }
      } else {
        throw ApiException('فشل إضافة الموعد');
      }
    } catch (e) {
      print('❌ [DoctorService] Error adding appointment: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إضافة الموعد: ${e.toString()}');
    }
  }

  // إضافة صورة للمعرض
  Future<Map<String, dynamic>> addGalleryImage({
    required String patientId,
    required List<int> imageBytes,
    String? note,
    String? fileName,
  }) async {
    try {
      final response = await _api.uploadFileBytes(
        ApiConstants.doctorPatientGallery(patientId),
        imageBytes,
        fileName: fileName ?? 'gallery.jpg',
        fileKey: 'image',
        additionalData: note != null ? {'note': note} : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ApiException('فشل رفع الصورة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل رفع الصورة: ${e.toString()}');
    }
  }

  // جلب مواعيد الطبيب
  Future<List<AppointmentModel>> getMyAppointments({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      
      if (day != null) queryParams['day'] = day;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      if (status != null) queryParams['status'] = status;

      final response = await _api.get(
        ApiConstants.doctorAppointments,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data
            .map((json) => AppointmentModel.fromJson(json))
            .toList();
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

  // جلب جميع مواعيد المرضى (للاستقبال)
  Future<List<AppointmentModel>> getAllAppointmentsForReception({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };

      if (day != null) queryParams['day'] = day;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      if (status != null) queryParams['status'] = status;

      final response = await _api.get(
        ApiConstants.receptionAppointments,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => AppointmentModel.fromJson(json)).toList();
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

  // جلب سجلات المريض
  Future<List<MedicalRecordModel>> getPatientNotes({
    required String patientId,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.doctorPatientNotes(patientId),
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data
            .map((json) => MedicalRecordModel.fromJson(json))
            .toList();
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

  // رفع صورة إلى معرض المريض
  Future<GalleryImageModel> uploadGalleryImage(
    String patientId,
    File imageFile,
    String? note,
  ) async {
    try {
      print('📸 [DoctorService] Uploading gallery image for patient: $patientId');
      
      final formData = dio.FormData.fromMap({
        'image': await dio.MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
        if (note != null && note.isNotEmpty) 'note': note,
      });

      final response = await _api.post(
        ApiConstants.doctorPatientGallery(patientId),
        formData: formData,
      );

      if (response.statusCode == 200) {
        print('✅ [DoctorService] Image uploaded successfully');
        return GalleryImageModel.fromJson(response.data);
      } else {
        throw ApiException('فشل رفع الصورة');
      }
    } catch (e) {
      print('❌ [DoctorService] Error uploading image: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل رفع الصورة: ${e.toString()}');
    }
  }

  // جلب مواعيد المريض المحدد
  Future<List<AppointmentModel>> getPatientAppointments(
    String patientId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      print('📅 [DoctorService] Fetching appointments for patient: $patientId');
      
      final response = await _api.get(
        ApiConstants.doctorPatientAppointments(patientId),
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        print('✅ [DoctorService] Fetched ${data.length} appointments');
        return data
            .map((json) => AppointmentModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('فشل جلب المواعيد');
      }
    } catch (e) {
      print('❌ [DoctorService] Error fetching appointments: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب المواعيد: ${e.toString()}');
    }
  }

  // جلب قائمة صور معرض المريض
  Future<List<GalleryImageModel>> getPatientGallery(
    String patientId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      print('📸 [DoctorService] Fetching gallery for patient: $patientId');
      
      final response = await _api.get(
        ApiConstants.doctorPatientGallery(patientId),
        queryParameters: {
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        print('✅ [DoctorService] Fetched ${data.length} gallery images');
        return data
            .map((json) => GalleryImageModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('فشل جلب صور المعرض');
      }
    } catch (e) {
      print('❌ [DoctorService] Error fetching gallery: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب صور المعرض: ${e.toString()}');
    }
  }

  // حذف موعد للمريض
  Future<bool> deleteAppointment(String patientId, String appointmentId) async {
    try {
      print('🗑️ [DoctorService] Deleting appointment: $appointmentId for patient: $patientId');
      
      final response = await _api.delete(
        ApiConstants.doctorDeleteAppointment(patientId, appointmentId),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ [DoctorService] Appointment deleted successfully');
        return true;
      } else {
        throw ApiException('فشل حذف الموعد');
      }
    } catch (e) {
      print('❌ [DoctorService] Error deleting appointment: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل حذف الموعد: ${e.toString()}');
    }
  }

  // تحديث حالة الموعد
  Future<AppointmentModel> updateAppointmentStatus(
    String patientId,
    String appointmentId,
    String status,
  ) async {
    try {
      print('🔄 [DoctorService] Updating appointment status: $appointmentId to $status');
      
      final response = await _api.patch(
        ApiConstants.doctorUpdateAppointmentStatus(patientId, appointmentId),
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        print('✅ [DoctorService] Appointment status updated successfully');
        return AppointmentModel.fromJson(response.data);
      } else {
        throw ApiException('فشل تحديث حالة الموعد');
      }
    } catch (e) {
      print('❌ [DoctorService] Error updating appointment status: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تحديث حالة الموعد: ${e.toString()}');
    }
  }

  // حذف صورة من معرض المريض
  Future<bool> deleteGalleryImage(String patientId, String imageId) async {
    try {
      print('🗑️ [DoctorService] Deleting gallery image: $imageId for patient: $patientId');
      
      final response = await _api.delete(
        ApiConstants.doctorDeleteGalleryImage(patientId, imageId),
      );

      if (response.statusCode == 200) {
        print('✅ [DoctorService] Gallery image deleted successfully');
        return true;
      } else {
        throw ApiException('فشل حذف الصورة');
      }
    } catch (e) {
      print('❌ [DoctorService] Error deleting gallery image: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل حذف الصورة: ${e.toString()}');
    }
  }

  // تحويل PatientOut من Backend إلى PatientModel
  PatientModel _mapPatientOutToModel(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      city: json['city'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      doctorIds: json['doctor_ids'] != null
          ? List<String>.from(json['doctor_ids'])
          : (json['doctorIds'] != null
              ? List<String>.from(json['doctorIds'])
              : (json['primary_doctor_id'] != null || json['secondary_doctor_id'] != null
                  ? [
                      if (json['primary_doctor_id'] != null) json['primary_doctor_id'],
                      if (json['secondary_doctor_id'] != null) json['secondary_doctor_id'],
                    ].whereType<String>().toList()
                  : const [])),
      treatmentHistory: json['treatment_type'] != null
          ? [json['treatment_type']]
          : null,
    );
  }
}

