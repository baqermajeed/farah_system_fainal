import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/dental_chart_controller.dart';
import 'package:farah_sys_final/models/dental_note_entry.dart';
import 'package:farah_sys_final/widgets/dental_chart/dental_chart_constants.dart';

Future<void> showDentalStatusPickerSheet({
  required BuildContext context,
  required DentalChartController controller,
  required String toothNo,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(const Duration(milliseconds: 80));

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DentalStatusPickerSheet(
        controller: controller,
        toothNo: toothNo,
      );
    },
  );
}

class DentalStatusPickerSheet extends StatefulWidget {
  const DentalStatusPickerSheet({
    super.key,
    required this.controller,
    required this.toothNo,
  });

  final DentalChartController controller;
  final String toothNo;

  @override
  State<DentalStatusPickerSheet> createState() =>
      _DentalStatusPickerSheetState();
}

class _DentalStatusPickerSheetState extends State<DentalStatusPickerSheet> {
  late final Set<String> _temp;
  late final List<DentalNoteEntry> _notes;
  late final Set<String> _initialStatuses;

  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  bool _showNoteComposer = false;
  int? _editingNoteIndex;
  DateTime? _editingCreatedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialStatuses = Set<String>.from(
      widget.controller.chart[widget.toothNo] ?? const <String>{},
    );
    _temp = Set<String>.from(_initialStatuses);
    _notes = List<DentalNoteEntry>.from(
      widget.controller.notesByTooth[widget.toothNo] ??
          const <DentalNoteEntry>[],
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _openNoteComposer({int? index}) {
    setState(() {
      _showNoteComposer = true;
      _editingNoteIndex = index;
      if (index != null) {
        final entry = _notes[index];
        _noteController.text = entry.text;
        _editingCreatedAt = entry.createdAt;
      } else {
        _noteController.clear();
        _editingCreatedAt = null;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noteFocusNode.requestFocus();
    });
  }

  void _cancelNoteComposer() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showNoteComposer = false;
      _editingNoteIndex = null;
      _editingCreatedAt = null;
      _noteController.clear();
    });
  }

  void _commitNoteComposer() {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      Get.snackbar('تنبيه', 'الرجاء كتابة الملاحظة');
      return;
    }

    final entry = DentalNoteEntry(
      text: text,
      createdAt: _editingCreatedAt ?? DateTime.now(),
    );

    setState(() {
      if (_editingNoteIndex != null) {
        _notes[_editingNoteIndex!] = entry;
      } else {
        _notes.insert(0, entry);
      }
      _showNoteComposer = false;
      _editingNoteIndex = null;
      _editingCreatedAt = null;
      _noteController.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveTooth(
        toothNo: widget.toothNo,
        previous: _initialStatuses,
        selected: _temp,
        notes: _notes,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    final selectedParentWithSubs = DentalChartConstants.dentalStatuses
        .where(
          (status) =>
              DentalChartConstants.hasStatus(_temp, status) &&
              (DentalChartConstants.dentalSubStatuses[status]?.isNotEmpty ??
                  false),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: const Color(0xFFDCE7FA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6DBE3),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 12.h),
                      _buildStatusSection(selectedParentWithSubs),
                      SizedBox(height: 10.h),
                      _buildNotesSection(),
                      if (_showNoteComposer) ...[
                        SizedBox(height: 10.h),
                        _buildNoteComposer(),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFB7CDF6)),
                          padding: EdgeInsets.symmetric(vertical: 11.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: _showNoteComposer
                            ? null
                            : () => _openNoteComposer(),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: const Text('إضافة ملاحظة'),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 11.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
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
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.medical_services_outlined,
              color: Colors.white,
              size: 19.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'إعدادات السن ${widget.toothNo}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(999.r),
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(List<String> selectedParentWithSubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFDDE7F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF2563EB),
                    size: 16,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'الحالات الرئيسية',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${_temp.length} محدد',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 7.w,
                runSpacing: 7.h,
                alignment: WrapAlignment.end,
                children: DentalChartConstants.dentalStatuses.map((status) {
                  final selected = DentalChartConstants.hasStatus(_temp, status);
                  final hasSubs =
                      DentalChartConstants.dentalSubStatuses[status]
                              ?.isNotEmpty ??
                          false;
                  final color = DentalChartConstants.statusColor(status);
                  return FilterChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: selected,
                    label: Text(
                      hasSubs ? '$status ▼' : status,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                    backgroundColor: color.withValues(alpha: 0.08),
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: color.withValues(alpha: 0.45)),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _temp.add(DentalChartConstants.statusToken(status));
                        } else {
                          DentalChartConstants.removeStatusWithSubs(
                            _temp,
                            status,
                          );
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (selectedParentWithSubs.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFD9E4F7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: selectedParentWithSubs.map((parentStatus) {
                final subOptions =
                    DentalChartConstants.dentalSubStatuses[parentStatus] ??
                    const <String>[];
                final parentColor =
                    DentalChartConstants.statusColor(parentStatus);
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'خيارات $parentStatus',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: parentColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Wrap(
                        spacing: 7.w,
                        runSpacing: 7.h,
                        alignment: WrapAlignment.end,
                        children: subOptions.map((sub) {
                          final token = DentalChartConstants.statusToken(
                            parentStatus,
                            sub,
                          );
                          final subSelected = _temp.contains(token);
                          return FilterChip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: subSelected,
                            label: Text(
                              sub,
                              style: TextStyle(
                                color: subSelected ? Colors.white : parentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.sp,
                              ),
                            ),
                            backgroundColor:
                                parentColor.withValues(alpha: 0.12),
                            selectedColor: parentColor,
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                              color: parentColor.withValues(alpha: 0.55),
                            ),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _temp.add(
                                    DentalChartConstants.statusToken(
                                      parentStatus,
                                    ),
                                  );
                                  _temp.add(token);
                                } else {
                                  _temp.remove(token);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: _notes.isEmpty
          ? Text(
              'لا توجد ملاحظات بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            )
          : Column(
              children: List.generate(_notes.length, (index) {
                final noteEntry = _notes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _notes.length - 1 ? 8.h : 0,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          noteEntry.text,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _notes.removeAt(index));
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: const Color(0xFFC0392B),
                                    size: 15.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'حذف',
                                    style: TextStyle(
                                      color: const Color(0xFFC0392B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InkWell(
                              onTap: () => _openNoteComposer(index: index),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    color: const Color(0xFF2563EB),
                                    size: 15.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'تعديل',
                                    style: TextStyle(
                                      color: const Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(noteEntry.createdAt),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildNoteComposer() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFDDE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingNoteIndex != null
                ? 'تعديل ملاحظة السن ${widget.toothNo}'
                : 'ملاحظة جديدة للسن ${widget.toothNo}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            minLines: 2,
            maxLines: 4,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'اكتب الملاحظة...',
              fillColor: const Color(0xFFF8FAFF),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelNoteComposer,
                  child: const Text('إلغاء'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _commitNoteComposer,
                  child: const Text('إضافة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
