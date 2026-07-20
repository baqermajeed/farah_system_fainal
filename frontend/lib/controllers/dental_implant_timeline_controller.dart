import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';

/// Controller لشاشة تايم لاين زراعة الأسنان — حالة/منطق العرض هنا،
/// بينما بيانات المراحل تُدار عبر [ImplantStageController] الخاص بالشاشة
/// (نسخة جديدة في كل زيارة، مثل نمط AppointmentsScreenController).
class DentalImplantTimelineController extends GetxController {
  /// أسماء المراحل كما هي مخزّنة في الـ API
  static const List<String> allStageNames = [
    'مرحلة زراعة الاسنان',
    'مرحلة رفع خيط العملية',
    'متابعة حالة المريض',
    'المتابعة الثانية لحالة المريض',
    'التقاط طبعة الاسنان',
    'التركيب التجريبي الاول',
    'التركيب التجريبي الثاني',
    'التركيب النهائي الاخير',
  ];

  /// أسماء العرض المطابقة للتصميم
  static const List<String> displayStageNames = [
    'مرحلة زراعة الاسنان',
    'مرحلة رفع خيط العملية',
    'متابعة حالة المريض',
    'المتابعة الثانية لحالة المريض',
    'التقاط طبعة الاسنان',
    'التركيب التجريبي الاول',
    'التركيب التجريبي الثاني',
    'التركيب النهائي الدائم',
  ];

  static const List<String> completedDescriptions = [
    'تمت زراعة الغرسة بنجاح',
    'تم رفع خيط العملية بنجاح',
    'تمت المتابعة والتقييم',
    'تمت المتابعة الثانية بنجاح',
    'تم التقاط الطبعة بنجاح',
    'تم التركيب التجريبي الاول بنجاح',
    'تم التركيب التجريبي الثاني بنجاح',
    'تم التركيب النهائي بنجاح',
  ];

  late ImplantStageController implantStageController;
  PatientController get patientController => Get.find<PatientController>();
  AuthController get authController => Get.find<AuthController>();

  String get patientId => authController.patientProfileId.value ?? '';

  @override
  void onInit() {
    super.onInit();
    // Ensure controller exists once for this screen session (fresh copy per visit).
    implantStageController = Get.put(ImplantStageController());
  }

  @override
  void onReady() {
    super.onReady();
    loadData();
  }

  Future<void> loadData() async {
    final id = authController.patientProfileId.value;
    if (id == null || id.isEmpty) return;

    await Future.wait([
      patientController.loadMyDoctor(),
      implantStageController.loadStages(id),
    ]);
  }

  String doctorSubtitle() {
    final name = patientController.myDoctor.value?['name']?.toString();
    if (name != null && name.isNotEmpty) {
      return 'مع د. $name';
    }
    return 'متابعة مراحل زراعة أسنانك';
  }

  int? lastCompletedIndex(List<ImplantStageModel> patientStages) {
    int? lastCompletedIndex;
    for (int i = patientStages.length - 1; i >= 0; i--) {
      if (!patientStages[i].isCompleted) continue;
      final indexInAll = allStageNames.indexOf(patientStages[i].stageName);
      if (indexInAll != -1) {
        lastCompletedIndex = indexInAll;
        break;
      }
    }
    return lastCompletedIndex;
  }

  ImplantStageModel stageForName(
    String stageName,
    List<ImplantStageModel> patientStages,
    String patientId,
  ) {
    return patientStages.firstWhere(
      (s) => s.stageName == stageName,
      orElse: () => ImplantStageModel(
        id: '',
        patientId: patientId,
        stageName: stageName,
        scheduledAt: DateTime.now(),
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  DateTime? treatmentStartDate(List<ImplantStageModel> patientStages) {
    if (patientStages.isEmpty) return null;
    final firstName = allStageNames.first;
    final first = patientStages.where((s) => s.stageName == firstName);
    if (first.isNotEmpty) return first.first.scheduledAt;
    return patientStages.first.scheduledAt;
  }
}
