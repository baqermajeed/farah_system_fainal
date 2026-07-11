import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/appointment_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment_model.dart';

/// جدول مواعيد الأطباء (للاستقبال / مركز الاتصالات).
class StaffDoctorAppointmentsView extends StatefulWidget {
  const StaffDoctorAppointmentsView({
    super.key,
    required this.appointmentController,
    this.readOnly = false,
    this.onOpenPatient,
  });

  final AppointmentController appointmentController;
  final bool readOnly;
  final void Function(AppointmentModel appointment)? onOpenPatient;

  @override
  State<StaffDoctorAppointmentsView> createState() =>
      _StaffDoctorAppointmentsViewState();
}

class _StaffDoctorAppointmentsViewState extends State<StaffDoctorAppointmentsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  AppointmentController get _controller => widget.appointmentController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadDoctorAppointments(
        isInitial: true,
        isRefresh: true,
        filter: 'هذا الشهر',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    String? filter;
    switch (index) {
      case 0:
        filter = 'اليوم';
        break;
      case 1:
        filter = 'هذا الشهر';
        break;
      case 2:
        filter = 'المتأخرون';
        break;
      case 3:
        filter = 'تصفية مخصصة';
        break;
    }
    _controller.appointments.clear();
    _controller.loadDoctorAppointments(
      isInitial: false,
      isRefresh: true,
      filter: filter,
      customFilterStart: _rangeStart,
      customFilterEnd: _rangeEnd,
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _rangeStart ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (start == null || !mounted) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _rangeEnd ?? start,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: DateTime(start.year + 5),
    );
    if (end == null || !mounted) return;

    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
    });
    _controller.appointments.clear();
    _controller.loadDoctorAppointments(
      isInitial: false,
      isRefresh: true,
      filter: 'تصفية مخصصة',
      customFilterStart: _rangeStart,
      customFilterEnd: _rangeEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 37.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF4FEFF),
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29649FCC),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            padding: EdgeInsets.zero,
            indicator: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10.r),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            unselectedLabelStyle:
                TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'اليوم'),
              Tab(text: 'هذا الشهر'),
              Tab(text: 'المتأخرون'),
              Tab(text: 'تصفية مخصصة'),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTable('اليوم'),
              _buildTable('هذا الشهر'),
              _buildTable('المتأخرون'),
              _buildTable('تصفية مخصصة'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(String filter) {
    final showCustomControls = filter == 'تصفية مخصصة';

    return Obx(() {
      final isLoading = _controller.isLoading.value;
      final items = _controller.appointments;

      Widget body;
      if (isLoading && items.isEmpty) {
        body = const Center(child: CircularProgressIndicator());
      } else if (items.isEmpty) {
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 56.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 12.h),
              Text(
                'لا توجد مواعيد',
                style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      } else {
        body = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29649FCC),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200 &&
                        !_controller.isLoadingMoreAppointments.value &&
                        _controller.hasMoreAppointments.value) {
                      _controller.loadMoreAppointments(filter: filter);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: items.length +
                        (_controller.isLoadingMoreAppointments.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return Padding(
                          padding: EdgeInsets.all(16.h),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _buildRow(items[index], filter);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (!showCustomControls) return body;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _pickCustomRange,
              icon: const Icon(Icons.date_range),
              label: Text(
                (_rangeStart == null || _rangeEnd == null)
                    ? 'اختر الفترة (من - إلى)'
                    : '${DateFormat('yyyy/MM/dd', 'ar').format(_rangeStart!)}  →  ${DateFormat('yyyy/MM/dd', 'ar').format(_rangeEnd!)}',
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(child: body),
        ],
      );
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          if (!widget.readOnly) ...[
            SizedBox(width: 90.w),
            SizedBox(width: 16.w),
          ],
          SizedBox(
            width: 120.w,
            child: Text(
              'رقم الهاتف',
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 120.w,
            child: Text(
              'الموعد',
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 100.w,
            child: Text(
              'اسم الطبيب',
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              'اسم المريض',
              textAlign: TextAlign.right,
              style: _headerStyle(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF76C6D1),
    );
  }

  Widget _buildRow(AppointmentModel appointment, String filter) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final formattedDate = dateFormat.format(appointment.date);
    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:$minute ${isPM ? 'م' : 'ص'}';
    final appointmentText = '$formattedDate $timeText';
    final isLate = filter == 'المتأخرون' ||
        (appointment.date.isBefore(DateTime.now()) &&
            appointment.status == 'pending');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      margin: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          if (!widget.readOnly) ...[
            SizedBox(
              width: 90.w,
              height: 30.h,
              child: ElevatedButton(
                onPressed: widget.onOpenPatient == null
                    ? null
                    : () => widget.onOpenPatient!(appointment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text('عرض', style: TextStyle(fontSize: 12.sp)),
              ),
            ),
            SizedBox(width: 16.w),
          ],
          SizedBox(
            width: 120.w,
            child: Text(
              appointment.patientPhone ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 120.w,
            child: Text(
              appointmentText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: isLate ? Colors.red : AppColors.textPrimary,
                fontWeight: isLate ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 100.w,
            child: Text(
              appointment.doctorName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              appointment.patientName,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
