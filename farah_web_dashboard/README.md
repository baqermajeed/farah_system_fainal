# Farah Web Dashboard

لوحة تحكم ويب احترافية لنظام CRM مركز فرح، مبنية بـ React + TypeScript مع RTL عربي وثيمين داكن/فاتح.

## المزايا

- تصميم حديث RTL عربي بالكامل.
- نظام ثيم (Dark / Light) قابل للتبديل مباشرة.
- تسجيل دخول الطاقم عبر `auth/staff-login`.
- لوحة رئيسية تنفيذية (KPIs + Charts).
- إحصائيات نظام شاملة:
  - المستخدمون حسب الأدوار
  - المواعيد
  - التحويلات
  - المحادثات
  - الإشعارات
- مقارنة الأطباء.
- صفحة تفاصيل الطبيب:
  - إحصائيات عامة
  - تفصيل المرضى (النوع، الجنس، المدن، النشاط)
  - تفصيل المواعيد اليومي/الشهري/الفترة
  - التحويلات والنشاط

## API Base URL

الافتراضي:

`https://sys-api.farahdent.com`

يمكن تغييره عبر ملف `.env`:

```bash
VITE_API_BASE_URL=https://sys-api.farahdent.com
```

## تشغيل المشروع

```bash
npm install
npm run dev
```

## بناء إنتاجي

```bash
npm run build
npm run preview
```

## الهيكل

- `src/layouts/` - هيكل لوحة التحكم
- `src/pages/` - صفحات النظام
- `src/services/` - API client + requests
- `src/state/` - إدارة الثيم والمصادقة
- `src/types/` - أنواع الاستجابات
