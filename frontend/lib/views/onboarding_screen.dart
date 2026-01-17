import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<_SlideData> get _slides => [
    _SlideData(
      imagePath: 'assets/splash/smile_1.png',
      title: AppStrings.onboardingSlide1Title,
      description: AppStrings.onboardingSlide1Description,
    ),
    _SlideData(
      imagePath: 'assets/splash/happy_2.png',
      title: AppStrings.onboardingSlide2Title,
      description: AppStrings.onboardingSlide2Description,
    ),
    _SlideData(
      imagePath: 'assets/splash/phon.png',
      title: AppStrings.onboardingSlide3Title,
      description: AppStrings.onboardingSlide3Description,
    ),
  ];

  void _goNext() {
    if (_currentIndex == _slides.length - 1) {
      Get.offAllNamed(AppRoutes.userSelection);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 8.h),
            // Top Row (Skip button)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: TextButton(
                    onPressed: () => Get.offAllNamed(AppRoutes.userSelection),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      AppStrings.skip,
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        color: AppColors.textSecondary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _OnboardingSlide(
                    index: index,
                    imagePath: slide.imagePath,
                    title: slide.title,
                    description: slide.description,
                  );
                },
              ),
            ),

            SizedBox(height: 10.h),

            // Bottom navigation (Back / Next / Page Indicator)
            SmoothPageIndicator(
              controller: _pageController,
              count: _slides.length,
              effect: ExpandingDotsEffect(
                dotHeight: 8.h,
                dotWidth: 8.w,
                spacing: 8.w,
                expansionFactor: 2.5,
                activeDotColor: AppColors.textPrimary,
                dotColor: AppColors.textHint,
              ),
            ),

            SizedBox(height: 16.h),

            // Bottom navigation (Back / Next)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (يسار)
                  TextButton.icon(
                    onPressed: _currentIndex == 0 ? null : _goBack,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onboardingButton,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                    icon: Icon(
                      Icons.chevron_left,
                      size: 22.sp,
                      color: _currentIndex == 0
                          ? AppColors.textHint
                          : AppColors.onboardingButton,
                    ),
                    label: Text(
                      AppStrings.back,
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: _currentIndex == 0
                            ? AppColors.textHint
                            : AppColors.onboardingButton,
                      ),
                    ),
                  ),
                  // Next button (يمين)
                  _currentIndex == _slides.length - 1
                      ? TextButton(
                          onPressed: _goNext,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.onboardingButton,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.flip(
                                  flipX: true,
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: 22.sp,
                                    color: AppColors.onboardingButton,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  AppStrings.start,
                                  style: TextStyle(
                                    fontFamily: 'Expo Arabic',
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onboardingButton,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _goNext,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.onboardingButton,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.next,
                                
                                style: TextStyle(
                                  fontFamily: 'Expo Arabic',
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onboardingButton,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.chevron_right,
                                size: 22.sp,
                                color: AppColors.onboardingButton,
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),

            SizedBox(height: 14.h),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final int index;
  final String imagePath;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.index,
    required this.imagePath,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40.h),
              // Illustration
              SizedBox(
                height: 300.h,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Background rectangle (dark blue)
                    // First slide (index == 0): starts from left edge and ends before icon
                    // Second slide (index == 1): extends full screen width
                    // Third slide (index == 2): starts after icon and extends to right edge
                    if (index == 0)
                      // First slide: from left edge to 80% of screen width
                      Positioned(
                        top: 90.h,
                        left: -(screenWidth / 2.6), // Start from left edge
                        child: SizedBox(
                          width: screenWidth / 0.95, // 80% of screen width
                          height: 140.h,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.onboardingDarkBlue,
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                          ),
                        ),
                      )
                    else if (index == 1)
                      // Second slide: full screen width
                      Positioned(
                        top: 90.h,
                        left: -(screenWidth / 2), // Start from left edge
                        right: -(screenWidth / 2), // End at right edge
                        child: Container(
                          height: 140.h,
                          decoration: BoxDecoration(
                            color: AppColors.onboardingDarkBlue,
                            borderRadius: BorderRadius.circular(32.r),
                          ),
                        ),
                      )
                    else
                      // Third slide: from after icon to right edge
                      Positioned(
                        top: 90.h,
                        right: -(screenWidth / 2.6), // End at right edge
                        child: SizedBox(
                          width: screenWidth / 0.95,
                          height: 140.h,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.onboardingDarkBlue,
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                          ),
                        ),
                      ),
                    // Image
                    Image.asset(
                      imagePath,
                      width: 220.w,
                      height: 220.h,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 70.h),
              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onboardingTitle,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Expo Arabic',
                    fontSize: 18.sp,
                    height: 1.6,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlideData {
  final String imagePath;
  final String title;
  final String description;

  const _SlideData({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}
