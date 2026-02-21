class ApiConstants {
  /// Base URL for all API calls.
  /// Default: `https://sys-api.farahdent.com`.
  /// Use `--dart-define=API_BASE_URL=<url>` or `--dart-define=API_HOST=<host>`
  /// only when you need to target a different backend.
  static const String _defaultBaseUrl = 'https://sys-api.farahdent.com';

  static const String _apiHostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final baseUrlOverride = _apiBaseUrlOverride.trim();
    if (baseUrlOverride.isNotEmpty) {
      return baseUrlOverride;
    }

    final hostOverride = _apiHostOverride.trim();
    if (hostOverride.isNotEmpty) {
      if (hostOverride.startsWith('http://') ||
          hostOverride.startsWith('https://')) {
        return hostOverride;
      }
      return 'https://$hostOverride';
    }

    return _defaultBaseUrl;
  }

  // API Endpoints
  static const String authRequestOtp = '/auth/request-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authCreatePatientAccount = '/auth/create-patient-account';
  static const String authStaffLogin = '/auth/staff-login';
  static const String authMe = '/auth/me';
  static const String authRefresh = '/auth/refresh';
  static const String authUpdateProfile = '/auth/me';
  static const String authUploadImage = '/auth/me/upload-image';

  // Patient Endpoints
  static const String patientMe = '/patient/me';
  static const String patientUpdateMe = '/patient/me';
  static const String patientDoctor = '/patient/doctor';
  static const String patientDoctors = '/patient/doctors';
  static const String patientAppointments = '/patient/appointments';
  static const String patientNotes = '/patient/notes';
  static const String patientGallery = '/patient/gallery';

  // Reception Endpoints
  static const String receptionPatients = '/reception/patients';
  static const String receptionCreatePatient = '/reception/patients';
  static const String receptionAppointments = '/reception/appointments';
  static const String receptionDoctors = '/reception/doctors';
  static String receptionDoctorWorkingHours(String doctorId) =>
      '/reception/doctors/$doctorId/working-hours';
  static String receptionDoctorAvailableSlots(String doctorId, String date) =>
      '/reception/doctors/$doctorId/available-slots/$date';
  static String receptionPatientDoctors(String patientId) =>
      '/reception/patients/$patientId/doctors';
  static const String receptionAssignPatient = '/reception/assign';
  static String receptionUploadPatientImage(String patientId) =>
      '/reception/patients/$patientId/upload-image';
  static String receptionPatientGallery(String patientId) =>
      '/reception/patients/$patientId/gallery';

  // Call Center Endpoints
  static const String callCenterAppointments = '/call-center/appointments';

  // Doctor Endpoints
  static const String doctorPatients = '/doctor/patients';
  static const String doctorInactivePatients = '/doctor/patients/inactive';
  static const String doctorAddPatient = '/doctor/patients';
  static String doctorPatientTreatment(String patientId) =>
      '/doctor/patients/$patientId/treatment';
  static String doctorPatientPaymentMethods(String patientId) =>
      '/doctor/patients/$patientId/payment-methods';
  static String doctorPatientNotes(String patientId) =>
      '/doctor/patients/$patientId/notes';
  static String doctorUpdateNote(String patientId, String noteId) =>
      '/doctor/patients/$patientId/notes/$noteId';
  static String doctorDeleteNote(String patientId, String noteId) =>
      '/doctor/patients/$patientId/notes/$noteId';
  static String doctorPatientAppointments(String patientId) =>
      '/doctor/patients/$patientId/appointments';
  static String doctorDeleteAppointment(
    String patientId,
    String appointmentId,
  ) => '/doctor/patients/$patientId/appointments/$appointmentId';
  static String doctorUpdateAppointmentStatus(
    String patientId,
    String appointmentId,
  ) => '/doctor/patients/$patientId/appointments/$appointmentId/status';
  static String doctorUpdateAppointmentDateTime(
    String patientId,
    String appointmentId,
  ) => '/doctor/patients/$patientId/appointments/$appointmentId/datetime';
  static String doctorWorkingHours = '/doctor/working-hours';
  static String doctorAvailableSlots(String date) =>
      '/doctor/available-slots/$date';
  static String doctorPatientGallery(String patientId) =>
      '/doctor/patients/$patientId/gallery';
  static String doctorDeleteGalleryImage(String patientId, String imageId) =>
      '/doctor/patients/$patientId/gallery/$imageId';
  static String doctorUploadPatientImage(String patientId) =>
      '/doctor/patients/$patientId/upload-image';
  static String doctorTransferPatient(String patientId) =>
      '/doctor/patients/$patientId/transfer';
  static const String doctorDoctors = '/doctor/doctors';
  static const String doctorAppointments = '/doctor/appointments';

  // Implant Stages Endpoints
  static String getImplantStages(String patientId) =>
      '/patients/$patientId/implant-stages';
  static String initializeImplantStages(String patientId) =>
      '/patients/$patientId/implant-stages/initialize';
  static String updateImplantStageDate(String patientId, String stageName) =>
      '/patients/$patientId/implant-stages/$stageName/date';
  static String completeImplantStage(String patientId, String stageName) =>
      '/patients/$patientId/implant-stages/$stageName/complete';
  static String uncompleteImplantStage(String patientId, String stageName) =>
      '/patients/$patientId/implant-stages/$stageName/uncomplete';

  // Chat Endpoints
  static const String chatList = '/chat/list';
  static String chatMessages(String patientId) => '/chat/$patientId/messages';
  static String chatSendMessage(String patientId) =>
      '/chat/$patientId/messages';
  static String chatMarkRead(String roomId, String messageId) =>
      '/chat/rooms/$roomId/messages/$messageId/read';

  // QR Code Endpoints
  static String qrScan(String code) => '/qr/scan?code=$code';

  // Stats Endpoints
  static String doctorPatientTransferStats(String doctorId) =>
      '/stats/doctors/$doctorId/patient-transfers';
  static const String doctorAllDoctorsTransferStats = '/doctor/doctors/transfer-stats';

  // Socket.IO
  static String get socketUrl =>
      baseUrl.replaceFirst('http://', '').replaceFirst('https://', '');
  static const String socketNamespace = '/socket.io';

  // Timeout
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';
}
