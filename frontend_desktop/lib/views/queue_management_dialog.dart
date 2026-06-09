import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_desktop/controllers/queue_controller.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/views/queue_display_screen.dart';

Future<void> showQueueManagementDialog(BuildContext context) {
  const double dialogWidth = 780;
  const double dialogHeight = 680;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: dialogWidth.w,
          height: dialogHeight.h,
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
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  TextStyle get _labelStyle => GoogleFonts.cairo(
        fontSize: 12.sp,
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

  QueueEntry? get _currentEntry => _queueController?.currentEntry;

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
    });
  }

  void _refresh() => setState(() {});

  void _callNext() {
    if (_queueController?.callNext() == true) {
      _refresh();
    }
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

  void _submit() {
    final controller = _queueController;
    if (controller == null) return;

    final name = _nameController.text;
    if (_isEditing) {
      if (controller.updatePatient(_editingId!, name)) {
        _resetForm();
      }
      return;
    }

    if (controller.addPatient(name)) {
      _nameController.clear();
      _refresh();
    }
  }

  void _startEdit(QueueEntry entry) {
    setState(() {
      _editingId = entry.id;
      _nameController.text = entry.name;
    });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormCard(),
                SizedBox(height: 14.h),
                _buildStatsRow(),
                SizedBox(height: 12.h),
                Expanded(child: _buildTable()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 18.h),
      decoration: const BoxDecoration(gradient: _headerGradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إدارة الطابور',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'إضافة المرضى واستدعاء الأدوار',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.format_list_numbered_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(widget.dialogContext).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              icon: Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEditing)
            Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16.sp, color: AppColors.primary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'وضع التعديل — رقم $_previewNumber',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetForm,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اسم المريض', style: _labelStyle),
                    SizedBox(height: 6.h),
                    TextField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'اكتب اسم المريض',
                        hintStyle: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          color: AppColors.textHint,
                        ),
                        hintTextDirection: TextDirection.rtl,
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 13.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: GoogleFonts.cairo(fontSize: 14.sp),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('رقم الدور', style: _labelStyle),
                  SizedBox(height: 6.h),
                  Container(
                    width: 72.w,
                    height: 48.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '$_previewNumber',
                      style: GoogleFonts.cairo(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _primaryButton(
                  onPressed: _submit,
                  icon: _isEditing ? Icons.check_rounded : Icons.person_add_rounded,
                  label: _isEditing ? 'حفظ التعديل' : 'إضافة للطابور',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 2,
                child: _primaryButton(
                  onPressed: _callNext,
                  icon: Icons.campaign_rounded,
                  label: 'استدعاء التالي',
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 2,
                child: _secondaryButton(
                  onPressed: _openDisplayScreen,
                  icon: Icons.tv_rounded,
                  label: 'شاشة العرض',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17.sp, color: Colors.white),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17.sp, color: AppColors.primary),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final current = _currentEntry;
    return Row(
      children: [
        _statChip(
          icon: Icons.people_outline_rounded,
          label: 'بالانتظار',
          value: '$_waitingCount',
          color: AppColors.info,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statChip(
            icon: Icons.record_voice_over_rounded,
            label: 'الآن يُستدعى',
            value: current?.name ?? '—',
            color: AppColors.success,
            expanded: true,
          ),
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool expanded = false,
  }) {
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _labelStyle),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );

    if (expanded) return child;
    return child;
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
              color: AppColors.primary.withValues(alpha: 0.07),
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                _headerCell('الرقم', flex: 1),
                _headerCell('اسم المريض', flex: 5),
                _headerCell('إجراءات', flex: 2, align: TextAlign.center),
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

  Widget _buildTableRow(QueueEntry entry, int index) {
    final isEditingRow = _editingId == entry.id;
    final isCalled = entry.status == QueueEntryStatus.called;
    final nextEntry = _queueController?.nextEntry;
    final isNext = nextEntry != null && entry.id == nextEntry.id;

    Color? rowColor;
    if (isEditingRow) {
      rowColor = AppColors.primary.withValues(alpha: 0.08);
    } else if (isCalled) {
      rowColor = AppColors.success.withValues(alpha: 0.07);
    } else if (index.isEven) {
      rowColor = AppColors.cardBackground;
    }

    return Material(
      color: rowColor ?? AppColors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _numberBadge(entry.number, isCalled: isCalled),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  if (isCalled) ...[
                    _statusBadge('الآن', AppColors.success),
                    SizedBox(width: 8.w),
                  ] else if (isNext) ...[
                    _statusBadge('التالي', AppColors.info),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Text(
                      entry.name,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        fontWeight:
                            isCalled ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconAction(
                    icon: Icons.edit_rounded,
                    color: AppColors.primary,
                    tooltip: 'تعديل',
                    onTap: () => _startEdit(entry),
                  ),
                  SizedBox(width: 6.w),
                  _iconAction(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
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

  Widget _numberBadge(int number, {required bool isCalled}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 36.w,
        height: 36.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCalled
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: isCalled ? AppColors.success : AppColors.primary,
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
          fontWeight: FontWeight.w700,
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
