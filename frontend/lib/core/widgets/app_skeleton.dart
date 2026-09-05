import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const Color _base = Color(0xFFE8EEF5);
  static const Color _highlight = Color(0xFFF8FBFF);

  @override
  Widget build(BuildContext context) {
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: _base,
        highlightColor: _highlight,
      ),
      child: content,
    );
  }
}

class SkeletonChatList extends StatelessWidget {
  const SkeletonChatList({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24.h),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.6,
          indent: 78.w,
          color: const Color(0xFFE9EDEF),
        ),
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: Row(
            children: [
              Bone.circle(size: 52.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 15.sp),
                    SizedBox(height: 8.h),
                    Bone.text(words: 4, fontSize: 12.sp),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Bone.text(width: 42.w, fontSize: 11.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonPatientList extends StatelessWidget {
  const SkeletonPatientList({
    super.key,
    this.itemCount = 7,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: shrinkWrap
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Bone.square(size: 52.w, uniRadius: 14.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 3, fontSize: 15.sp),
                    SizedBox(height: 8.h),
                    Bone.text(words: 5, fontSize: 12.sp),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonAppointmentList extends StatelessWidget {
  const SkeletonAppointmentList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (_, __) => const _SkeletonAppointmentCard(),
      ),
    );
  }
}

class _SkeletonAppointmentCard extends StatelessWidget {
  const _SkeletonAppointmentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Bone(
            width: 56.w,
            height: 56.w,
            borderRadius: BorderRadius.circular(16.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 3, fontSize: 15.sp),
                SizedBox(height: 8.h),
                Bone.text(words: 4, fontSize: 12.sp),
                SizedBox(height: 8.h),
                Bone.text(words: 2, fontSize: 11.sp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonNotificationList extends StatelessWidget {
  const SkeletonNotificationList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (_, __) => Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE8ECF0)),
          ),
          child: Row(
            children: [
              Bone.circle(size: 42.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 3, fontSize: 14.sp),
                    SizedBox(height: 8.h),
                    Bone.multiText(lines: 2, fontSize: 12.sp),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone.text(words: 3, fontSize: 16.sp),
              SizedBox(height: 10.h),
              Bone.text(words: 5, fontSize: 13.sp),
              SizedBox(height: 10.h),
              Bone.text(words: 2, fontSize: 12.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonChatMessages extends StatelessWidget {
  const SkeletonChatMessages({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            _bubble(alignEnd: false, width: 180.w),
            _bubble(alignEnd: true, width: 140.w),
            _bubble(alignEnd: false, width: 210.w),
            _bubble(alignEnd: true, width: 160.w),
            _bubble(alignEnd: false, width: 120.w),
            _bubble(alignEnd: true, width: 190.w),
          ],
        ),
      ),
    );
  }

  Widget _bubble({required bool alignEnd, required double width}) {
    return Align(
      alignment: alignEnd ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Bone(
          width: width,
          height: 44.h,
          borderRadius: BorderRadius.circular(18.r),
        ),
      ),
    );
  }
}

class SkeletonPatientHome extends StatelessWidget {
  const SkeletonPatientHome({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 18.h),
            Bone(
              height: 150.h,
              borderRadius: BorderRadius.circular(24.r),
            ),
            SizedBox(height: 16.h),
            Bone.text(words: 2, fontSize: 16.sp),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(child: _squareCard()),
                SizedBox(width: 10.w),
                Expanded(child: _squareCard()),
              ],
            ),
            SizedBox(height: 16.h),
            Bone(
              height: 90.h,
              borderRadius: BorderRadius.circular(20.r),
            ),
            SizedBox(height: 16.h),
            const _SkeletonAppointmentCard(),
            SizedBox(height: 10.h),
            const _SkeletonAppointmentCard(),
          ],
        ),
      ),
    );
  }

  Widget _squareCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Bone(
          height: 110.h,
          borderRadius: BorderRadius.circular(18.r),
        ),
        SizedBox(height: 8.h),
        Bone.text(words: 2, fontSize: 13.sp),
        SizedBox(height: 6.h),
        Bone.text(words: 3, fontSize: 11.sp),
      ],
    );
  }
}

class SkeletonProfilePage extends StatelessWidget {
  const SkeletonProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24.h),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Bone.circle(size: 96.w),
            SizedBox(height: 16.h),
            Bone.text(words: 2, fontSize: 20.sp),
            SizedBox(height: 8.h),
            Bone.text(words: 4, fontSize: 12.sp),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  Bone(
                    height: 120.h,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: Bone(
                          height: 80.h,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Bone(
                          height: 80.h,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Bone(
                    height: 52.h,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonTimeline extends StatelessWidget {
  const SkeletonTimeline({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone.circle(size: 44.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Bone(
                  height: 84.h,
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonScheduleCards extends StatelessWidget {
  const SkeletonScheduleCards({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: List.generate(
          itemCount,
          (_) => Container(
            margin: EdgeInsets.only(bottom: 16.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Row(
              children: [
                Bone(
                  width: 64.w,
                  height: 48.h,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone.text(words: 3, fontSize: 16.sp),
                      SizedBox(height: 8.h),
                      Bone.text(words: 4, fontSize: 12.sp),
                    ],
                  ),
                ),
                Bone.circle(size: 38.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonStatsPage extends StatelessWidget {
  const SkeletonStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _statCard()),
                SizedBox(width: 12.w),
                Expanded(child: _statCard()),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(child: _statCard()),
                SizedBox(width: 12.w),
                Expanded(child: _statCard()),
              ],
            ),
            SizedBox(height: 16.h),
            Bone(
              height: 180.h,
              borderRadius: BorderRadius.circular(20.r),
            ),
            SizedBox(height: 12.h),
            Bone(
              height: 120.h,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard() {
    return Bone(
      height: 90.h,
      borderRadius: BorderRadius.circular(18.r),
    );
  }
}

class SkeletonPatientFile extends StatelessWidget {
  const SkeletonPatientFile({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: AppSkeleton(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Bone.circle(size: 44.w),
                  const Spacer(),
                  Bone.circle(size: 44.w),
                  SizedBox(width: 8.w),
                  Bone.circle(size: 44.w),
                  SizedBox(width: 8.w),
                  Bone.circle(size: 44.w),
                ],
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Bone.circle(size: 56.w),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Bone.text(words: 1, fontSize: 11.sp),
                              SizedBox(height: 8.h),
                              Bone.text(words: 3, fontSize: 15.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: const Divider(height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(child: _infoCol()),
                        Expanded(child: _infoCol()),
                        Expanded(child: _infoCol()),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: Bone(
                      height: 120.h,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Bone(
                      height: 120.h,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Bone.text(words: 3, fontSize: 12.sp),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Bone.square(size: 64.w, uniRadius: 12.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone.text(words: 3, fontSize: 14.sp),
                        SizedBox(height: 8.h),
                        Bone.text(words: 4, fontSize: 12.sp),
                        SizedBox(height: 8.h),
                        Bone.text(words: 2, fontSize: 11.sp),
                      ],
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

  Widget _infoCol() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Bone.text(words: 1, fontSize: 11.sp),
          SizedBox(height: 8.h),
          Bone.text(words: 2, fontSize: 13.sp),
        ],
      ),
    );
  }
}

class SkeletonGalleryGrid extends StatelessWidget {
  const SkeletonGalleryGrid({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      padding: EdgeInsets.all(16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8.w,
          mainAxisSpacing: 8.h,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => Bone(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }
}
