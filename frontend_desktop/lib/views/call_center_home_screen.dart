import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/auth_controller.dart';
import '../controllers/call_center_appointments_controller.dart';
import '../core/constants/app_colors.dart';
import '../models/call_center_appointment_model.dart';
import '../core/utils/image_utils.dart';

/// محافظات العراق
const List<String> _iraqGovernorates = [
  'بغداد',
  'البصرة',
  'نينوى',
  'أربيل',
  'السليمانية',
  'النجف',
  'كربلاء',
  'المثنى',
  'القادسية',
  'بابل',
  'واسط',
  'ديالى',
  'كركوك',
  'صلاح الدين',
  'الأنبار',
  'ذي قار',
  'ميسان',
  'دهوك',
];

/// المنصات (مصدر الحجز)
const List<String> _bookingPlatforms = [
  'انستكرام',
  'واتساب',
  'تيك توك',
  'فيسبوك',
  'اتصال',
];

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
                  _buildHeaderCell('المحافظة', flex: 2),
                  _buildHeaderCell('المنصة', flex: 2),
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
                              item.governorate.isNotEmpty
                                  ? item.governorate
                                  : '-',
                              flex: 2,
                            ),
                            _buildBodyCell(
                              item.platform.isNotEmpty ? item.platform : '-',
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
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.grey[400],
                                  size: 20.sp,
                                ),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _showEditAppointmentDialog(context, item);
                                  } else if (value == 'delete') {
                                    final confirm = await Get.dialog<bool>(
                                      AlertDialog(
                                        title: const Text('تأكيد الحذف'),
                                        content: const Text(
                                          'هل أنت متأكد من حذف هذا الموعد؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: Text('إلغاء', style: TextStyle(color: Colors.grey[600])),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: Text('حذف', style: TextStyle(color: AppColors.error)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _appointmentsController.deleteAppointment(item.id);
                                      if (context.mounted) {
                                        Get.snackbar(
                                          'تم',
                                          'تم حذف الموعد',
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor: AppColors.success,
                                          colorText: AppColors.white,
                                          margin: EdgeInsets.all(20.r),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20),
                                        SizedBox(width: 8),
                                        Text('تعديل الموعد'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('حذف', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
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

  /// أوقات جاهزة كل ساعة من ٨ صباحاً إلى ٨ مساءً
  List<TimeOfDay> get _quickTimeSlots {
    final list = <TimeOfDay>[];
    for (int h = 8; h <= 20; h++) {
      list.add(TimeOfDay(hour: h, minute: 0));
    }
    return list;
  }

  Future<void> _showDateTimeSheet({
    required BuildContext context,
    required DateTime? initialDate,
    required TimeOfDay? initialTime,
    required void Function(DateTime? date, TimeOfDay? time) onPicked,
  }) async {
    DateTime? date = initialDate;
    TimeOfDay? time = initialTime;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final dateStr = date != null ? _formatDate(date!) : 'اختر التاريخ';
          String timeStr = 'اختر الوقت';
          if (time != null) {
            final dt = DateTime(2000, 1, 1, time!.hour, time!.minute);
            timeStr = _formatTime(dt);
          }

          return Container(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h + MediaQuery.of(ctx).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'التاريخ والوقت',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 20.h),
                // التاريخ
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      initialDate: date ?? DateTime.now(),
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
                    if (picked != null) setModalState(() => date = picked);
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 22.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            dateStr + (timeStr != 'اختر الوقت' ? '  •  $timeStr' : ''),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                              color: date != null ? const Color(0xFF334155) : Colors.grey,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: Colors.grey[400], size: 22.sp),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'الوقت (اضغط على وقت)',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _quickTimeSlots.map((t) {
                    final isSelected = time != null && time!.hour == t.hour && time!.minute == t.minute;
                    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
                    final label = _formatTime(dt);
                    return Material(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10.r),
                      child: InkWell(
                        onTap: () => setModalState(() => time = t),
                        borderRadius: BorderRadius.circular(10.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      onPicked(date, time);
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      elevation: 0,
                    ),
                    child: Text('تم', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateAppointmentDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? selectedGovernorate;
    String? selectedPlatform;

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
                        SizedBox(height: 16.h),

                        // المحافظة (محافظات العراق)
                        DropdownButtonFormField<String>(
                          value: selectedGovernorate,
                          decoration: InputDecoration(
                            labelText: 'المحافظة',
                            prefixIcon: const Icon(Icons.location_city_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          hint: const Text('اختر المحافظة'),
                          items: _iraqGovernorates
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => selectedGovernorate = v),
                        ),
                        SizedBox(height: 16.h),

                        // المنصة (مصدر الحجز)
                        DropdownButtonFormField<String>(
                          value: selectedPlatform,
                          decoration: InputDecoration(
                            labelText: 'المنصة',
                            prefixIcon: const Icon(Icons.devices_other_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          hint: const Text('اختر المنصة'),
                          items: _bookingPlatforms
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => selectedPlatform = v),
                        ),
                        SizedBox(height: 24.h),

                        // التاريخ والوقت — زر واحد يفتح ورقة واحدة للاختيار السريع
                        InkWell(
                          onTap: () async {
                            await _showDateTimeSheet(
                              context: context,
                              initialDate: selectedDate,
                              initialTime: selectedTime,
                              onPicked: (date, time) {
                                setState(() {
                                  selectedDate = date;
                                  selectedTime = time;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 18.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12.r),
                              color: (selectedDate != null &&
                                      selectedTime != null)
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primary,
                                  size: 28.sp,
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'التاريخ والوقت',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        (selectedDate != null &&
                                                selectedTime != null)
                                            ? '$dateLabel  •  $timeLabel'
                                            : 'اضغط لاختيار التاريخ والوقت',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: (selectedDate != null &&
                                                  selectedTime != null)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: (selectedDate != null &&
                                                  selectedTime != null)
                                              ? const Color(0xFF334155)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14.sp,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
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
                                    governorate: selectedGovernorate ?? '',
                                    platform: selectedPlatform ?? '',
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

  Future<void> _showEditAppointmentDialog(
    BuildContext context,
    CallCenterAppointmentModel item,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item.patientName);
    final phoneController = TextEditingController(text: item.patientPhone);
    DateTime? selectedDate = item.scheduledAt;
    TimeOfDay? selectedTime = TimeOfDay(
      hour: item.scheduledAt.hour,
      minute: item.scheduledAt.minute,
    );
    String? selectedGovernorate =
        item.governorate.isNotEmpty ? item.governorate : null;
    String? selectedPlatform =
        item.platform.isNotEmpty ? item.platform : null;

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
                String dateLabel = selectedDate != null
                    ? _formatDate(selectedDate!)
                    : 'اختر التاريخ';
                String timeLabel = 'اختر الوقت';
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
                          'تعديل الموعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        SizedBox(height: 32.h),
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
                        SizedBox(height: 16.h),
                        DropdownButtonFormField<String>(
                          value: selectedGovernorate,
                          decoration: InputDecoration(
                            labelText: 'المحافظة',
                            prefixIcon: const Icon(Icons.location_city_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          hint: const Text('اختر المحافظة'),
                          items: _iraqGovernorates
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => selectedGovernorate = v),
                        ),
                        SizedBox(height: 16.h),
                        DropdownButtonFormField<String>(
                          value: selectedPlatform,
                          decoration: InputDecoration(
                            labelText: 'المنصة',
                            prefixIcon: const Icon(Icons.devices_other_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          hint: const Text('اختر المنصة'),
                          items: _bookingPlatforms
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => selectedPlatform = v),
                        ),
                        SizedBox(height: 24.h),
                        InkWell(
                          onTap: () async {
                            await _showDateTimeSheet(
                              context: context,
                              initialDate: selectedDate,
                              initialTime: selectedTime,
                              onPicked: (date, time) {
                                setState(() {
                                  selectedDate = date;
                                  selectedTime = time;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 18.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12.r),
                              color: (selectedDate != null && selectedTime != null)
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_rounded,
                                    color: AppColors.primary, size: 28.sp),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('التاريخ والوقت',
                                          style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey[600])),
                                      SizedBox(height: 4.h),
                                      Text(
                                        (selectedDate != null &&
                                                selectedTime != null)
                                            ? '$dateLabel  •  $timeLabel'
                                            : 'اضغط لاختيار التاريخ والوقت',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: (selectedDate != null &&
                                                  selectedTime != null)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: (selectedDate != null &&
                                                  selectedTime != null)
                                              ? const Color(0xFF334155)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 14.sp, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 32.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (selectedDate == null || selectedTime == null) {
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
                                  await _appointmentsController.updateAppointment(
                                    id: item.id,
                                    patientName: nameController.text.trim(),
                                    patientPhone: phoneController.text.trim(),
                                    scheduledAt: scheduledAt,
                                    governorate: selectedGovernorate ?? '',
                                    platform: selectedPlatform ?? '',
                                  );
                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    Get.snackbar(
                                      'تم',
                                      'تم تعديل الموعد بنجاح',
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
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r)),
                                  elevation: 0,
                                ),
                                child: Text('حفظ التعديل',
                                    style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ),
                                child: Text('إلغاء',
                                    style: TextStyle(
                                        fontSize: 16.sp,
                                        color: Colors.grey[600])),
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
    final list = _appointmentsController.appointments;
    final result = await showDialog<DateTimeRange?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RangePickerDialog(
        initialStart: _rangeStart,
        initialEnd: _rangeEnd,
        appointmentsList: list,
        formatDate: _formatDate,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _rangeStart = result.start;
        _rangeEnd = result.end;
      });
    }
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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF649FCC),
                Color(0xFF4A88B8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: topPad),
              Container(
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapAfterLogo),
              Flexible(
                fit: FlexFit.loose,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'مركز فرح التخصصي لطب الاسنان',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapBeforeBottom),
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

/// دايلوج اختيار الفترة وعرض الإحصائيات
class _RangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final List<CallCenterAppointmentModel> appointmentsList;
  final String Function(DateTime) formatDate;

  const _RangePickerDialog({
    this.initialStart,
    this.initialEnd,
    required this.appointmentsList,
    required this.formatDate,
  });

  @override
  State<_RangePickerDialog> createState() => _RangePickerDialogState();
}

class _RangePickerDialogState extends State<_RangePickerDialog> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  int _countInRange(DateTime start, DateTime end) {
    final list = widget.appointmentsList;
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return list.where((item) {
      final dt = item.createdAt ?? item.scheduledAt;
      return dt.isAfter(s.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(e.add(const Duration(seconds: 1)));
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final count = (_start != null && _end != null && _start!.isBefore(_end!.add(const Duration(days: 1))))
        ? _countInRange(_start!, _end!)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      elevation: 12,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: 420.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.date_range_rounded, color: AppColors.primary, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إحصائيات ضمن فترة',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          'اختر من وإلى',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.grey[600], size: 22.sp),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              _DateCard(
                label: 'من تاريخ',
                date: _start,
                formatDate: widget.formatDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                    initialDate: _start ?? now,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
              SizedBox(height: 12.h),
              _DateCard(
                label: 'إلى تاريخ',
                date: _end,
                formatDate: widget.formatDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: _start ?? DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                    initialDate: _end ?? _start ?? now,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _end = picked);
                },
              ),
              if (count != null) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights_rounded, color: AppColors.primary, size: 28.sp),
                      SizedBox(width: 10.w),
                      Text(
                        'عدد المواعيد: ',
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text('إلغاء', style: TextStyle(color: Colors.grey[700], fontSize: 15.sp)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_start != null && _end != null)
                          ? () {
                              if (_start!.isAfter(_end!)) {
                                setState(() {
                                  final t = _start;
                                  _start = _end;
                                  _end = t;
                                });
                              }
                              Navigator.of(context).pop(DateTimeRange(start: _start!, end: _end!));
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        elevation: 0,
                      ),
                      child: Text('تطبيق', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _DateCard({
    required this.label,
    required this.date,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      date != null ? formatDate(date!) : 'اضغط لاختيار التاريخ',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: date != null ? FontWeight.bold : FontWeight.w500,
                        color: date != null ? const Color(0xFF2C3E50) : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16.sp, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
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
                        color: const Color(0xFF2C3E50),
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

