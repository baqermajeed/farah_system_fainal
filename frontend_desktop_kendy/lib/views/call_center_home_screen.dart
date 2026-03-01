import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/auth_controller.dart';
import '../controllers/call_center_appointments_controller.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/image_utils.dart';

class CallCenterHomeScreen extends StatefulWidget {
  const CallCenterHomeScreen({super.key});

  @override
  State<CallCenterHomeScreen> createState() => _CallCenterHomeScreenState();
}

class _CallCenterHomeScreenState extends State<CallCenterHomeScreen> {
  final AuthController _authController = Get.put(AuthController());
  final CallCenterAppointmentsController _appointmentsController =
      Get.put(CallCenterAppointmentsController());
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _appointmentsController.loadAppointments();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _appointmentsController.loadAppointments(
        search: _searchController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Logo section (top center)
            Expanded(
              child: Row(
                children: [
                  // Main Content Area
                  Expanded(
                    child: Column(
                      children: [
                        // Top Bar (Header)
                        _buildTopBar(),
                        // Table
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 0,
                              right: 16.w,
                              left: 16.w,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 260.w,
                                  child: _buildStatsPanel(),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _buildAppointmentsTable(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right Sidebar Navigation
                  _buildRightSidebarNavigation(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ' 📞 📆 لوحــــة تحكم مركــــز الاتصــــالات ',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1.2,
                ),
              ),
              
            ],
          ),

          SizedBox(width: 20.w),

          // Add Appointment Button (Inverted Style)
          GestureDetector(
            onTap: () => _showCreateAppointmentDialog(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              height: 50.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF4A88B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'موعد جديد',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 20.w),

          // Search
          Container(
            width: 400.w,
            height: 50.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: false, // Prevent double background with global theme
                hintText: 'ابحث عن اسم المريض أو رقم الهاتف...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13.sp,
                ),
                // Search Icon on the right (start of Arabic text)
                suffixIcon: Container(
                  margin: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF4A88B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 14.h,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          SizedBox(width: 20.w),

          // User Profile
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    return Obx(() {
      final user = _authController.currentUser.value;
      final userName = user?.name ?? 'الموظف';
      final imageUrl = user?.imageUrl;
      final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

      return Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _authController.logout(),
              icon: const Icon(Icons.logout_rounded),
              color: AppColors.error,
              iconSize: 20.sp,
              tooltip: 'تسجيل الخروج',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                padding: EdgeInsets.all(8.r),
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  'متصل',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            CircleAvatar(
              radius: 22.r,
              backgroundColor: AppColors.primaryLight,
              child: validImageUrl != null &&
                      ImageUtils.isValidImageUrl(validImageUrl)
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: validImageUrl,
                        fit: BoxFit.cover,
                        width: 44.r,
                        height: 44.r,
                        placeholder: (context, url) => Container(
                          color: AppColors.primaryLight,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAppointmentsTable() {
    return Obx(() {
      final isLoading = _appointmentsController.loading.value;
      final list = _appointmentsController.appointments;
      final err = _appointmentsController.error.value;

      if (isLoading && list.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (err != null && list.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 60.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 16.h),
              Text(
                'تعذر تحميل المواعيد',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                err,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        );
      }

      if (list.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 48.sp,
                  color: const Color(0xFF649FCC),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'لا توجد مواعيد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'يمكنك إضافة مواعيد جديدة من القائمة العلوية',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: EdgeInsets.only(right: 4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('الموظف', flex: 2),
                  _buildHeaderCell('رقم الهاتف', flex: 2),
                  _buildHeaderCell('التاريخ', flex: 2),
                  _buildHeaderCell('اليوم والوقت', flex: 3),
                  _buildHeaderCell('المريض', flex: 2),
                  SizedBox(width: 40.w), // Actions placeholder
                ],
              ),
            ),
            // Table Rows
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      hoverColor: const Color(0xFFF1F5F9),
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 18.h),
                        child: Row(
                          children: [
                            _buildBodyCell(
                              item.createdByUsername.isNotEmpty
                                  ? item.createdByUsername
                                  : '-',
                              flex: 2,
                            ),
                            _buildBodyCell(
                              item.patientPhone,
                              flex: 2,
                              isPhone: true,
                            ),
                            _buildBodyCell(
                              _formatDate(item.scheduledAt),
                              flex: 2,
                            ),
                            _buildBodyCell(
                              _formatDayTime(item.scheduledAt),
                              flex: 3,
                            ),
                            _buildBodyCell(
                              item.patientName,
                              flex: 2,
                              isBold: true,
                              color: const Color(0xFF649FCC),
                            ),
                            SizedBox(
                              width: 40.w,
                              child: Icon(
                                Icons.more_vert_rounded,
                                color: Colors.grey[400],
                                size: 20.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildBodyCell(
    String text, {
    int flex = 1,
    bool isBold = false,
    bool isPhone = false,
    Color? color,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text.isEmpty ? '-' : text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? const Color(0xFF334155),
          fontFamily: isPhone ? 'Courier' : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _showCreateAppointmentDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 10,
          insetPadding: EdgeInsets.all(24.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500.w),
            child: StatefulBuilder(
              builder: (context, setState) {
                String dateLabel = 'اختر التاريخ';
                String timeLabel = 'اختر الوقت';
                if (selectedDate != null) {
                  dateLabel = _formatDate(selectedDate!);
                }
                if (selectedTime != null) {
                  final now = DateTime.now();
                  final dt = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  timeLabel = _formatTime(dt);
                }

                return Container(
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'إضافة موعد جديد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        SizedBox(height: 32.h),

                        // Name Field
                        TextFormField(
                          controller: nameController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'اسم المريض',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                        SizedBox(height: 16.h),

                        // Phone Field
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                        SizedBox(height: 24.h),

                        // Date & Time Pickers
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365 * 2),
                                    ),
                                    initialDate: selectedDate ?? DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: AppColors.primary,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          color: AppColors.primary),
                                      SizedBox(height: 8.h),
                                      Text(
                                        dateLabel,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: selectedDate != null
                                              ? Colors.black
                                              : Colors.grey,
                                          fontWeight: selectedDate != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        selectedTime ?? TimeOfDay.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: AppColors.primary,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() => selectedTime = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.access_time,
                                          color: AppColors.primary),
                                      SizedBox(height: 8.h),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: selectedTime != null
                                              ? Colors.black
                                              : Colors.grey,
                                          fontWeight: selectedTime != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (selectedDate == null ||
                                      selectedTime == null) {
                                    Get.snackbar(
                                      'تنبيه',
                                      'يرجى اختيار التاريخ والوقت',
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: AppColors.error,
                                      colorText: AppColors.white,
                                      margin: EdgeInsets.all(20.r),
                                    );
                                    return;
                                  }
                                  final scheduledAt = DateTime(
                                    selectedDate!.year,
                                    selectedDate!.month,
                                    selectedDate!.day,
                                    selectedTime!.hour,
                                    selectedTime!.minute,
                                  );
                                  await _appointmentsController
                                      .createAppointment(
                                    patientName: nameController.text.trim(),
                                    patientPhone: phoneController.text.trim(),
                                    scheduledAt: scheduledAt,
                                  );
                                  if (mounted) {
                                    Navigator.of(ctx).pop();
                                    Get.snackbar(
                                      'تم',
                                      'تمت إضافة الموعد بنجاح',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.success,
                                      colorText: AppColors.white,
                                      margin: EdgeInsets.all(20.r),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'حفظ الموعد',
                                  style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ),
                                child: Text(
                                  'إلغاء',
                                  style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsPanel() {
    return Obx(() {
      final list = _appointmentsController.appointments;
      final todayCount = _countToday(list);
      final monthCount = _countThisMonth(list);
      final totalCount = list.length;
      final rangeCount = (_rangeStart != null && _rangeEnd != null)
          ? _countInRange(list, _rangeStart!, _rangeEnd!)
          : 0;

      final rangeLabel = (_rangeStart != null && _rangeEnd != null)
          ? '${_formatDate(_rangeStart!)} → ${_formatDate(_rangeEnd!)}'
          : 'اختر فترة';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: _StatCard(
              title: 'مواعيد اليوم',
              value: todayCount.toString(),
              icon: Icons.today_rounded,
              color: const Color(0xFF5B9FCC),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _StatCard(
              title: 'مواعيد هذا الشهر',
              value: monthCount.toString(),
              icon: Icons.date_range_rounded,
              color: const Color(0xFF4CAF50),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _StatCard(
              title: 'كل المواعيد',
              value: totalCount.toString(),
              icon: Icons.list_alt_rounded,
              color: const Color(0xFF3498DB),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _StatCard(
              title: 'ضمن فترة محددة',
              value: rangeCount.toString(),
              subtitle: rangeLabel,
              icon: Icons.filter_alt_rounded,
              color: const Color(0xFFF39C12),
              onTap: _pickRange,
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _StatCard(
              title: 'المواعيد المقبولة',
              value: '--',
              subtitle: 'قريباً',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF9B59B6),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_rangeStart != null && _rangeEnd != null)
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : DateTimeRange(start: now, end: now),
    );
    if (range == null) return;
    if (!mounted) return;
    setState(() {
      _rangeStart = range.start;
      _rangeEnd = range.end;
    });
  }

  Widget _buildRightSidebarNavigation() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = (110.w).clamp(72.0, 130.0);
        final h = constraints.maxHeight;

        final topPad = (h * 0.06).clamp(12.0, 50.0);
        final bottomPad = (h * 0.08).clamp(16.0, 100.0);
        final logoSize = (h * 0.18).clamp(64.0, 120.0);
        final bottomIconSize = (h * 0.12).clamp(44.0, 80.0);
        final gapAfterLogo = (h * 0.02).clamp(8.0, 16.0);
        final gapBeforeBottom = (h * 0.03).clamp(10.0, 25.0);

        return Container(
          width: sidebarWidth,
          color: const Color(0xFF325066),
          child: Column(
            children: [
              SizedBox(height: topPad),

              // Logo Section (scales down if height is tight)
              SizedBox(
                height: logoSize,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/kendy_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapAfterLogo),

              // Vertical Text (force single line + scale down to avoid wrapping)
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'عيادة الكندي التخصصية لطب الاسنان',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapBeforeBottom),

              // Bottom Icon (scales down)
              SizedBox(
                height: bottomIconSize,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/happy 2.png',
                      width: bottomIconSize,
                      height: bottomIconSize,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medical_services_outlined,
                          color: Colors.white,
                          size: 30.sp,
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomPad),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute ${isPM ? 'م' : 'ص'}';
  }

  String _formatDayTime(DateTime dt) {
    final weekday = _formatWeekday(dt.weekday);
    return '$weekday ${_formatTime(dt)}';
  }

  String _formatWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الاربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
      default:
        return 'الاحد';
    }
  }

  int _countToday(List<dynamic> list) {
    final now = DateTime.now();
    return list.where((item) {
      final dt = (item.createdAt as DateTime?) ?? item.scheduledAt as DateTime;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).length;
  }

  int _countThisMonth(List<dynamic> list) {
    final now = DateTime.now();
    return list.where((item) {
      final dt = (item.createdAt as DateTime?) ?? item.scheduledAt as DateTime;
      return dt.year == now.year && dt.month == now.month;
    }).length;
  }

  int _countInRange(List<dynamic> list, DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return list.where((item) {
      final dt = (item.createdAt as DateTime?) ?? item.scheduledAt as DateTime;
      return dt.isAfter(s.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(e.add(const Duration(seconds: 1)));
    }).length;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isCompact = availableHeight < 80;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 6.w : 8.w),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: isCompact ? 16.sp : 18.sp,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12.sp,
                        color: Colors.grey[400],
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 6.h : 8.h),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isCompact ? 18.sp : 20.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF649FCC),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isCompact ? 10.sp : 11.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

