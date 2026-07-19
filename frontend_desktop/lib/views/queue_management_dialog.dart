import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_desktop/controllers/queue_controller.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/queue_ticket_print_service.dart';
import 'package:frontend_desktop/views/queue_display_screen.dart';

Future<void> showQueueManagementDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) {
      final screenSize = MediaQuery.sizeOf(dialogContext);
      final widthFactor = screenSize.width < 560
          ? 0.98
          : screenSize.width < 900
              ? 0.92
              : 0.82;
      final heightFactor = screenSize.height < 700 ? 0.96 : 0.9;

      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          heightFactor: heightFactor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900.w,
              maxHeight: 800.h,
              minHeight: 360.h,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: QueueManagementDialogContent(dialogContext: dialogContext),
            ),
          ),
        ),
      );
    },
  );
}

class QueueManagementDialogContent extends StatefulWidget {
  final BuildContext dialogContext;

  const QueueManagementDialogContent({super.key, required this.dialogContext});

  @override
  State<QueueManagementDialogContent> createState() =>
      _QueueManagementDialogContentState();
}

class _QueueManagementDialogContentState
    extends State<QueueManagementDialogContent> {
  QueueController? _queueController;
  final TextEditingController _nameController = TextEditingController();
  String? _editingId;

  static const _headerGradient = LinearGradient(
    colors: [Color(0xFF4A88B8), Color(0xFF5B9FCC)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  TextStyle get _titleStyle => GoogleFonts.cairo(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  TextStyle get _labelStyle => GoogleFonts.cairo(
        fontSize: 10.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<QueueController>()) {
      _queueController = Get.find<QueueController>();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEditing => _editingId != null;

  int get _previewNumber {
    final controller = _queueController;
    if (controller == null) return 1;
    if (_isEditing) {
      return controller.findById(_editingId!)?.number ?? 0;
    }
    return controller.nextNumber.value;
  }

  int get _waitingCount => _queueController?.waitingEntries.length ?? 0;

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
    });
  }

  void _refresh() => setState(() {});

  void _callNextAnesthesia() {
    if (_queueController?.callNextAnesthesia() == true) {
      _refresh();
    }
  }

  void _callNextSurgery() {
    if (_queueController?.callNextSurgery() == true) {
      _refresh();
    }
  }

  Future<void> _confirmClearQueue() async {
    final controller = _queueController;
    if (controller == null) return;

    final confirmed = await showDialog<bool>(
      context: widget.dialogContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'تصفير الطابور',
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل تريد تصفير الطابور بالكامل؟\nسيتم حذف جميع الأسماء وإعادة الترقيم من 1.',
          style: GoogleFonts.cairo(fontSize: 14.sp),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'تصفير',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    controller.clearQueue();
    _resetForm();
    _refresh();
    Get.snackbar(
      'تم التصفير',
      'تم تصفير الطابور وإعادة الترقيم من 1',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _openDisplayScreen() async {
    try {
      await openQueueDisplayScreen(widget.dialogContext);
      if (!mounted) return;
      Get.snackbar(
        'شاشة العرض',
        'تم فتح شاشة الطابور على الشاشة الثانية',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primary,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'تنبيه',
        'تعذر فتح شاشة العرض: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    }
    _refresh();
  }

  Future<void> _submit() async {
    final controller = _queueController;
    if (controller == null) return;

    final name = _nameController.text;
    if (_isEditing) {
      if (controller.updatePatient(_editingId!, name)) {
        _resetForm();
      }
      return;
    }

    final assignedNumber = controller.nextNumber.value;
    if (controller.addPatient(name)) {
      final printedName = name.trim();
      _nameController.clear();
      _refresh();
      await QueueTicketPrintService.showPrintPrompt(
        name: printedName,
        number: assignedNumber,
      );
    }
  }

  void _startEdit(QueueEntry entry) {
    setState(() {
      _editingId = entry.id;
      _nameController.text = entry.name;
    });
  }

  Future<void> _printEntryTicket(QueueEntry entry) async {
    try {
      final method = await QueueTicketPrintService.printTicket(
        name: entry.name.trim(),
        number: entry.number,
      );
      Get.snackbar(
        'تمت الطباعة',
        'تم الإرسال عبر: $method',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'تنبيه',
        'فشلت طباعة التذكرة\n$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
        duration: const Duration(seconds: 6),
      );
    }
  }

  void _callAnesthesiaEntry(QueueEntry entry) {
    final controller = _queueController;
    if (controller == null) return;
    if (controller.callAnesthesia(entry.id)) {
      _refresh();
    }
  }

  void _callSurgeryEntry(QueueEntry entry) {
    final controller = _queueController;
    if (controller == null) return;
    if (controller.callSurgery(entry.id)) {
      _refresh();
    }
  }

  Future<void> _confirmPostpone(QueueEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: widget.dialogContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'تأجيل المراجع',
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل تريد تأجيل "${entry.name}" (رقم ${entry.number})؟\nسيُعتبر غير حاضر ويختفي من شاشة العرض.',
          style: GoogleFonts.cairo(fontSize: 14.sp),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'تأجيل',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _queueController?.postponePatient(entry.id);
      if (_editingId == entry.id) {
        _resetForm();
      } else {
        _refresh();
      }
    }
  }

  Future<void> _confirmDelete(QueueEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: widget.dialogContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'حذف من الطابور',
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل تريد حذف "${entry.name}" (رقم ${entry.number})؟',
          style: GoogleFonts.cairo(fontSize: 14.sp),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _queueController?.deletePatient(entry.id);
      if (_editingId == entry.id) {
        _resetForm();
      } else {
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640.w;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isCompact: isCompact),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 10.w : 14.w,
                  6.h,
                  isCompact ? 10.w : 14.w,
                  8.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormCard(isCompact: isCompact),
                    SizedBox(height: 6.h),
                    Expanded(child: _buildTable()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8.w : 10.w,
        vertical: isCompact ? 6.h : 8.h,
      ),
      decoration: const BoxDecoration(gradient: _headerGradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'إدارة الطابور',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: isCompact ? 14.sp : 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: isCompact ? 30.w : 34.w,
              height: isCompact ? 30.w : 34.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.format_list_numbered_rounded,
                color: Colors.white,
                size: isCompact ? 16.sp : 18.sp,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(widget.dialogContext).pop(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.all(4.w),
              constraints: BoxConstraints(
                minWidth: 32.w,
                minHeight: 32.w,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: isCompact ? 16.sp : 18.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8.w : 10.w,
        vertical: isCompact ? 8.h : 8.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEditing)
            Container(
              margin: EdgeInsets.only(bottom: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 14.sp, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'وضع التعديل — رقم $_previewNumber',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetForm,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNameField(),
                    SizedBox(height: 6.h),
                    Center(child: _buildNumberBox()),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildNameField()),
                    SizedBox(width: 8.w),
                    _buildNumberBox(),
                  ],
                ),
          SizedBox(height: 6.h),
          _buildActionsAndStatsRow(isCompact: isCompact),
        ],
      ),
    );
  }

  Widget _buildActionsAndStatsRow({required bool isCompact}) {
    final waitingChip = _statChip(
      icon: Icons.people_outline_rounded,
      label: 'بالانتظار',
      value: '$_waitingCount',
      color: AppColors.info,
    );

    if (isCompact) {
      return Column(
        children: [
          Row(
            children: [
              waitingChip,
              SizedBox(width: 4.w),
              Expanded(
                child: _primaryButton(
                  onPressed: _confirmClearQueue,
                  icon: Icons.delete_sweep_rounded,
                  label: 'تصفير',
                  color: AppColors.error,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _secondaryButton(
                  onPressed: _openDisplayScreen,
                  icon: Icons.tv_rounded,
                  label: 'شاشة العرض',
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: _primaryButton(
                  onPressed: _callNextSurgery,
                  icon: Icons.local_hospital_rounded,
                  label: 'استدعاء عملية',
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _primaryButton(
                  onPressed: _callNextAnesthesia,
                  icon: Icons.vaccines_rounded,
                  label: 'استدعاء البنچ',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: double.infinity,
            child: _primaryButton(
              onPressed: _submit,
              icon: _isEditing
                  ? Icons.check_rounded
                  : Icons.person_add_rounded,
              label: _isEditing ? 'حفظ التعديل' : 'إضافة للطابور',
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        waitingChip,
        SizedBox(width: 6.w),
        Expanded(
          flex: 2,
          child: _primaryButton(
            onPressed: _confirmClearQueue,
            icon: Icons.delete_sweep_rounded,
            label: 'تصفير',
            color: AppColors.error,
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          flex: 2,
          child: _secondaryButton(
            onPressed: _openDisplayScreen,
            icon: Icons.tv_rounded,
            label: 'شاشة العرض',
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          flex: 2,
          child: _primaryButton(
            onPressed: _callNextSurgery,
            icon: Icons.local_hospital_rounded,
            label: 'استدعاء عملية',
            color: AppColors.success,
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          flex: 2,
          child: _primaryButton(
            onPressed: _callNextAnesthesia,
            icon: Icons.vaccines_rounded,
            label: 'استدعاء البنچ',
            color: AppColors.warning,
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          flex: 2,
          child: _primaryButton(
            onPressed: _submit,
            icon: _isEditing
                ? Icons.check_rounded
                : Icons.person_add_rounded,
            label: _isEditing ? 'حفظ التعديل' : 'إضافة للطابور',
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  double get _fieldHeight => 36.h;

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'اسم المريض',
          style: _labelStyle,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 3.h),
        Container(
          height: _fieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.divider),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            textAlignVertical: TextAlignVertical.center,
            style: GoogleFonts.cairo(fontSize: 13.sp, height: 1.2),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'اكتب اسم المريض',
              hintStyle: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: AppColors.textHint,
                height: 1.2,
              ),
              hintTextDirection: TextDirection.rtl,
              alignLabelWithHint: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('رقم الدور', style: _labelStyle),
        SizedBox(height: 3.h),
        Container(
          width: 56.w,
          height: _fieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '$_previewNumber',
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: _fieldHeight,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14.sp, color: Colors.white),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: _fieldHeight,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14.sp, color: AppColors.primary),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool expanded = false,
  }) {
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          if (expanded) Expanded(child: textColumn) else textColumn,
        ],
      ),
    );
  }

  Widget _buildTable() {
    final list = _queueController?.sortedEntries ?? const <QueueEntry>[];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: const Color(0xFFD6E4EE),
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                _headerCell('الرقم', flex: 1),
                _headerCell('اسم المريض', flex: 3),
                _headerCell('إجراءات', flex: 4, align: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty ? _buildEmptyState() : _buildTableList(list),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 32.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'لا يوجد مرضى في الطابور',
            style: _titleStyle.copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            'أضف أول مريض من الحقل أعلاه',
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList(List<QueueEntry> list) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final entry = list[index];
        return _buildTableRow(entry, index);
      },
    );
  }

  Color _statusAccent(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.anesthesia:
        return const Color(0xFFD35400); // برتقالي أغمق
      case QueueEntryStatus.surgery:
        return const Color(0xFF1E8449); // أخضر أغمق
      case QueueEntryStatus.postponed:
        return const Color(0xFF8B0000); // أحمر غامق
      case QueueEntryStatus.waiting:
        return const Color(0xFF2471A3); // أزرق أغمق
    }
  }

  Widget _buildTableRow(QueueEntry entry, int index) {
    final isEditingRow = _editingId == entry.id;
    final status = entry.status;
    final accent = _statusAccent(status);
    final nextEntry = _queueController?.nextEntry;
    final isNext = nextEntry != null &&
        entry.id == nextEntry.id &&
        status == QueueEntryStatus.waiting;
    final canCallAnesthesia = status == QueueEntryStatus.waiting ||
        status == QueueEntryStatus.anesthesia;
    final canCallSurgery = status == QueueEntryStatus.anesthesia ||
        status == QueueEntryStatus.surgery;
    final canPostpone = status == QueueEntryStatus.waiting ||
        status == QueueEntryStatus.anesthesia;

    Color? rowColor;
    if (isEditingRow) {
      rowColor = AppColors.primary.withValues(alpha: 0.18);
    } else if (status == QueueEntryStatus.anesthesia) {
      rowColor = accent.withValues(alpha: 0.28);
    } else if (status == QueueEntryStatus.surgery) {
      rowColor = accent.withValues(alpha: 0.26);
    } else if (status == QueueEntryStatus.postponed) {
      rowColor = accent.withValues(alpha: 0.24);
    } else if (index.isEven) {
      rowColor = const Color(0xFFE8EEF2);
    }

    return Material(
      color: rowColor ?? AppColors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _numberBadge(entry.number, accent: accent),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (status != QueueEntryStatus.waiting) ...[
                    _statusBadge(status.labelAr, accent),
                    SizedBox(width: 8.w),
                  ] else if (isNext) ...[
                    _statusBadge('التالي', const Color(0xFF2471A3)),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Text(
                      entry.name,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        fontWeight: status == QueueEntryStatus.waiting
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canCallAnesthesia)
                    _iconAction(
                      icon: Icons.vaccines_rounded,
                      color: const Color(0xFFD35400),
                      tooltip: status == QueueEntryStatus.anesthesia
                          ? 'إعادة استدعاء البنچ'
                          : 'استدعاء البنچ',
                      onTap: () => _callAnesthesiaEntry(entry),
                    ),
                  if (canCallAnesthesia) SizedBox(width: 4.w),
                  if (canCallSurgery)
                    _iconAction(
                      icon: Icons.local_hospital_rounded,
                      color: const Color(0xFF1E8449),
                      tooltip: status == QueueEntryStatus.surgery
                          ? 'إعادة نداء العملية'
                          : 'استدعاء عملية',
                      onTap: () => _callSurgeryEntry(entry),
                    ),
                  if (canCallSurgery) SizedBox(width: 4.w),
                  _iconAction(
                    icon: Icons.print_rounded,
                    color: const Color(0xFF145A32),
                    tooltip: 'طباعة الرقم',
                    onTap: () => _printEntryTicket(entry),
                  ),
                  SizedBox(width: 4.w),
                  _iconAction(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF2471A3),
                    tooltip: 'تعديل',
                    onTap: () => _startEdit(entry),
                  ),
                  SizedBox(width: 4.w),
                  if (canPostpone)
                    _iconAction(
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF8B0000),
                      tooltip: 'تأجيل',
                      onTap: () => _confirmPostpone(entry),
                    ),
                  if (canPostpone) SizedBox(width: 4.w),
                  _iconAction(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFF8B0000),
                    tooltip: 'حذف',
                    onTap: () => _confirmDelete(entry),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberBadge(int number, {required Color accent}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 36.w,
        height: 36.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.28),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Text(
          '$number',
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _headerCell(
    String text, {
    required int flex,
    TextAlign align = TextAlign.right,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.cairo(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Icon(icon, size: 18.sp, color: color),
        ),
      ),
    );
  }
}
