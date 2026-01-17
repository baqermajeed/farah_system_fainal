# 🌐 دليل تكامل API - API Integration Guide

دليل شامل لتكامل التطبيق مع Backend API في المستقبل.

---

## 📋 نظرة عامة

حالياً التطبيق يستخدم قاعدة بيانات محلية (Hive). هذا الدليل يوضح كيفية التكامل مع Backend API.

---

## 🏗️ البنية المقترحة

```
lib/
├── 📁 services/
│   ├── api_service.dart           # الخدمة الأساسية للـ API
│   ├── auth_service.dart          # خدمة المصادقة
│   ├── patient_service.dart       # خدمة المرضى
│   ├── appointment_service.dart   # خدمة المواعيد
│   └── chat_service.dart          # خدمة المحادثات
│
├── 📁 core/
│   └── 📁 network/
│       ├── api_constants.dart     # ثوابت API
│       ├── api_interceptor.dart   # Interceptor للطلبات
│       └── api_exception.dart     # معالجة الأخطاء
```

---

## 📦 الحزم المطلوبة

أضف الحزم التالية لـ `pubspec.yaml`:

```yaml
dependencies:
  # HTTP Client
  dio: ^5.3.3

  # Storage for tokens
  flutter_secure_storage: ^9.0.0

  # JSON Serialization (اختياري)
  json_annotation: ^4.8.1

dev_dependencies:
  json_serializable: ^6.7.1
```

---

## 🔧 الإعداد الأساسي

### 1. API Constants

```dart
// lib/core/network/api_constants.dart
class ApiConstants {
  // Base URL
  static const String baseUrl = 'https://api.farah-clinic.com';

  // API Version
  static const String apiVersion = '/api/v1';

  // Endpoints
  static const String login = '$apiVersion/auth/login';
  static const String register = '$apiVersion/auth/register';
  static const String logout = '$apiVersion/auth/logout';

  // Patients
  static const String patients = '$apiVersion/patients';
  static String patientById(String id) => '$patients/$id';

  // Appointments
  static const String appointments = '$apiVersion/appointments';
  static String appointmentById(String id) => '$appointments/$id';

  // Messages
  static const String messages = '$apiVersion/messages';
  static const String sendMessage = '$messages/send';

  // Medical Records
  static const String medicalRecords = '$apiVersion/medical-records';

  // Timeout
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;
}
```

### 2. API Service

```dart
// lib/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token to headers
          final token = await _storage.read(key: 'token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // Handle errors globally
          if (error.response?.statusCode == 401) {
            // Token expired - logout
            _handleUnauthorized();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> _handleUnauthorized() async {
    await _storage.delete(key: 'token');
    // Navigate to login
  }

  // GET Request
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST Request
  Future<Response> post(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PUT Request
  Future<Response> put(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // DELETE Request
  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Upload File
  Future<Response> uploadFile(
    String endpoint,
    String filePath, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        ...?additionalData,
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
```

---

## 🔐 خدمة المصادقة

```dart
// lib/services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/models/user_model.dart';

class AuthService {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  // تسجيل الدخول
  Future<UserModel> login({
    required String phoneNumber,
    String? username,
    required String userType,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.login,
        data: {
          'phone_number': phoneNumber,
          'username': username,
          'user_type': userType,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // حفظ الـ Token
        await _storage.write(key: 'token', value: data['token']);

        // إرجاع المستخدم
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception('فشل تسجيل الدخول');
      }
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل مستخدم جديد
  Future<UserModel> register({
    required String name,
    required String phoneNumber,
    required String gender,
    required int age,
    required String city,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.register,
        data: {
          'name': name,
          'phone_number': phoneNumber,
          'gender': gender,
          'age': age,
          'city': city,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        await _storage.write(key: 'token', value: data['token']);
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception('فشل التسجيل');
      }
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
      await _storage.delete(key: 'token');
    } catch (e) {
      rethrow;
    }
  }

  // التحقق من تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'token');
    return token != null;
  }
}
```

---

## 📅 خدمة المواعيد

```dart
// lib/services/appointment_service.dart
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/models/appointment_model.dart';

class AppointmentService {
  final _api = ApiService();

  // جلب جميع المواعيد
  Future<List<AppointmentModel>> getAppointments() async {
    try {
      final response = await _api.get(ApiConstants.appointments);

      if (response.statusCode == 200) {
        final List data = response.data['appointments'];
        return data.map((json) => AppointmentModel.fromJson(json)).toList();
      } else {
        throw Exception('فشل تحميل المواعيد');
      }
    } catch (e) {
      rethrow;
    }
  }

  // إضافة موعد جديد
  Future<AppointmentModel> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime date,
    required String time,
    String? notes,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.appointments,
        data: {
          'patient_id': patientId,
          'doctor_id': doctorId,
          'date': date.toIso8601String(),
          'time': time,
          'notes': notes,
        },
      );

      if (response.statusCode == 201) {
        return AppointmentModel.fromJson(response.data['appointment']);
      } else {
        throw Exception('فشل إضافة الموعد');
      }
    } catch (e) {
      rethrow;
    }
  }

  // تحديث حالة موعد
  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    try {
      await _api.put(
        ApiConstants.appointmentById(appointmentId),
        data: {'status': status},
      );
    } catch (e) {
      rethrow;
    }
  }

  // حذف موعد
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _api.delete(ApiConstants.appointmentById(appointmentId));
    } catch (e) {
      rethrow;
    }
  }
}
```

---

## 🔄 تحديث Controllers

### مثال: تحديث AuthController

```dart
// lib/controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/models/user_model.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkLoggedInUser();
  }

  Future<void> checkLoggedInUser() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      // يمكن جلب بيانات المستخدم من API
      Get.offAllNamed(AppRoutes.patientHome);
    }
  }

  Future<void> loginPatient(String phoneNumber) async {
    try {
      isLoading.value = true;

      final user = await _authService.login(
        phoneNumber: phoneNumber,
        userType: 'patient',
      );

      currentUser.value = user;
      Get.offAllNamed(AppRoutes.patientHome);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تسجيل الدخول: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      currentUser.value = null;
      Get.offAllNamed(AppRoutes.userSelection);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تسجيل الخروج');
    }
  }
}
```

---

## 🔄 الانتقال التدريجي

### الخطوة 1: استخدام كلاهما (Hive + API)

```dart
// يمكن استخدام Hive للـ offline mode و API للمزامنة
Future<void> loadData() async {
  try {
    // 1. جلب من API
    final apiData = await _apiService.getData();

    // 2. حفظ في Hive للـ offline mode
    final box = await Hive.openBox('myData');
    await box.put('data', apiData);

    // 3. استخدام البيانات
    data.value = apiData;
  } catch (e) {
    // في حال فشل API، استخدم Hive
    final box = await Hive.openBox('myData');
    final cachedData = box.get('data');
    if (cachedData != null) {
      data.value = cachedData;
    }
  }
}
```

### الخطوة 2: المزامنة التلقائية

```dart
// lib/services/sync_service.dart
class SyncService {
  Future<void> syncData() async {
    // 1. جلب التغييرات المحلية
    final localChanges = await _getLocalChanges();

    // 2. إرسالها للـ API
    await _api.post('/sync', data: localChanges);

    // 3. جلب التغييرات من السيرفر
    final serverChanges = await _api.get('/sync');

    // 4. تحديث البيانات المحلية
    await _updateLocalData(serverChanges);
  }
}
```

---

## 📱 WebSocket للـ Real-time

```dart
// lib/services/websocket_service.dart
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late WebSocketChannel _channel;

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://api.farah-clinic.com/ws'),
    );

    _channel.stream.listen((message) {
      // معالجة الرسائل الواردة
      print('Received: $message');
    });
  }

  void sendMessage(String message) {
    _channel.sink.add(message);
  }

  void disconnect() {
    _channel.sink.close();
  }
}
```

---

## 🧪 الاختبار

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farah_sys_final/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('login returns UserModel on success', () async {
      final authService = AuthService();

      final user = await authService.login(
        phoneNumber: '0777777777',
        userType: 'patient',
      );

      expect(user, isNotNull);
      expect(user.userType, equals('patient'));
    });
  });
}
```

---

## 📝 ملاحظات مهمة

1. **الأمان:** لا تحفظ الـ token في SharedPreferences، استخدم FlutterSecureStorage
2. **Error Handling:** تأكد من معالجة جميع الأخطاء المحتملة
3. **Timeout:** استخدم timeout مناسب للطلبات
4. **Retry:** أضف منطق لإعادة المحاولة في حال الفشل
5. **Cache:** استخدم Hive للتخزين المؤقت وتحسين الأداء

---

**جاهز للتكامل! 🚀**
