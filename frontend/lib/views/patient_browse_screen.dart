import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientBrowseScreen extends StatelessWidget {
  const PatientBrowseScreen({super.key});

  static const List<Map<String, String>> _facts = [
    {
      "text": "تنظيف الأسنان مرتين يومياً يحمي من التسوس",
      "image": "assets/images/IMG_9520 1.png"
    },
    {
      "text": "استخدام الخيط الطبي يزيل 40% من الجير",
      "image": "assets/images/IMG_9521 1.png"
    },
    {
      "text": "أن ان معظم مشاكل الأسنان لا تؤلم في المراحل المبكرة",
      "image": "assets/images/IMG_20260111_172641_363 1.png"
    },
    {
      "text": "زيارة الطبيب كل 6 أشهر تحافظ على ابتسامتك",
      "image": "assets/images/IMG_2026011.png"
    },
    {
      "text": "شرب الماء بكثرة يساعد في تنظيف الفم طبيعياً",
      "image": "assets/images/dfgjhkjgfd.png"
    },
    {
      "text": "التقليل من السكريات يحمي طبقة المينا",
      "image": "assets/images/sfgdgsfsd.png"
    },
    {
      "text": "استبدل فرشاة الأسنان كل 3 أشهر",
      "image": "assets/images/dgsfdSDA.png"
    },
    {
      "text": "مضغ العلكة الخالية من السكر يحفز اللعاب",
      "image": "assets/images/sgdfzsFD.png"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: const Color.fromARGB(0, 45, 44, 44),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'معلومات طبية',
          style: GoogleFonts.cairo(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: const Color.fromARGB(255, 48, 53, 58),
          ),
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/arrow-square-up.png',
              width: 40.w,
              height: 40.h,
            ),
            onPressed: () => Get.back(),
          ),
          SizedBox(width: 16.w),
        ],
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 1.h),
        children: [
          // Header Image
          Center(
            child: Image.asset(
              'assets/images/f1.png',
              width: 270.w,
              height: 221.h,
              fit: BoxFit.contain,
            ),
          ),
          
          // List of Cards
          ..._facts.asMap().entries.map((entry) {
            int idx = entry.key;
            var item = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: idx == _facts.length - 1 ? 0 : 24.h),
              child: _buildCard(item),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, String> item) {
    return Container(
      height: 352.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCEE1EA).withOpacity(0.5),
            blurRadius: 20,
            
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: 16.h),
          // Badge
          Image.asset(
            'assets/images/Group 33411.png',
            height: 36.h, 
            fit: BoxFit.contain,
          ),
          SizedBox(height: 20.h),
          // Text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              item['text']!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF58A0C9),
                height: 1.5,
              ),
            ),
          ),
          
          // Image
          SizedBox(height: 30,),
          Padding(
            padding: EdgeInsets.only(bottom: 2.h),
            child: Image.asset(
              item['image']!,
              height: 150.h,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
