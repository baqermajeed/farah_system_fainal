# farah_dashboard

تطبيق Flutter جديد **للوحة تحكم المدير (Admin Dashboard)**.

يرتبط مباشرة مع `backend` عبر:
- `POST /auth/staff-login` لتسجيل الدخول (username/password)
- `GET /auth/me` للتحقق من الهوية والدور
- `GET /stats/dashboard` لجلب إحصائيات اللوحة

## Getting Started

### تشغيل الـ Backend أولاً

- شغّل الـ API على المنفذ 8000 (افتراضيًا): `http://localhost:8000`

### تشغيل الـ Dashboard

من داخل مجلد `dashboard/`:

```bash
flutter pub get
flutter run
```

### تغيير عنوان الـ API (Base URL)

القيمة الافتراضية في `lib/core/config/app_config.dart` هي:
- `http://localhost:8000`

يمكنك تغييرها وقت التشغيل:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

> - على **Android Emulator** استخدم `http://10.0.2.2:8000`
> - على الهاتف الحقيقي استخدم IP الجهاز الذي يشغّل الـ backend على نفس الشبكة.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
