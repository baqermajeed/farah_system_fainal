import 'package:get/get.dart';

import '../models/doctor_stats.dart';
import '../services/stats_service.dart';

class DoctorsController extends GetxController {
  final _stats = StatsService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  final RxList<DoctorStat> doctors = <DoctorStat>[].obs;

  Future<void> loadDoctors() async {
    loading.value = true;
    error.value = null;
    try {
      final docs = await _stats.getDoctors();
      doctors.assignAll(docs);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}


