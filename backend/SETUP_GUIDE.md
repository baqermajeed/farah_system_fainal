# دليل إعداد MongoDB وإضافة البيانات التجريبية

## الخطوة 1: تثبيت MongoDB

### Windows:
1. حمل MongoDB Community Server من: https://www.mongodb.com/try/download/community
2. قم بالتثبيت
3. شغّل MongoDB كخدمة في Windows أو يدوياً:
   ```powershell
   mongod --dbpath C:\data\db
   ```

### أو استخدم Docker:
```powershell
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

## الخطوة 2: إنشاء ملف .env

أنشئ ملف `.env` في مجلد `backend/` مع المحتوى التالي:

```dotenv
# MongoDB
MONGODB_URI=mongodb://localhost:27017/clinic

# JWT
JWT_SECRET=change_me_super_secret_key_please_change_in_production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# CORS
CORS_ORIGINS=

# SMS Provider (للاختبار المحلي)
SMS_PROVIDER=dummy

# Media Directory
MEDIA_DIR=media
```

## الخطوة 3: إنشاء المستخدمين الأساسيين

شغّل السكريبت لإنشاء المستخدمين الأساسيين (Admin, Doctor, Receptionist):

```powershell
cd backend
python -m app.scripts.create_default_users
```

**بيانات تسجيل الدخول:**
- **المدير**: username=`admin`, password=`admin123`
- **الطبيب**: username=`baqer121`, password=`12345`
- **الاستقبال**: username=`reception1`, password=`12345`

## الخطوة 4: إضافة البيانات التجريبية الشاملة

شغّل السكريبت لإضافة بيانات تجريبية كاملة (مرضى، مواعيد، سجلات علاجية):

```powershell
cd backend
python -m app.scripts.seed_demo_data
```

**هذا السكريبت سينشئ:**
- ✅ 5 مرضى تجريبيين
- ✅ ربط المرضى بالطبيب
- ✅ أنواع علاج مختلفة
- ✅ 6 مواعيد (ماضية ومستقبلية)
- ✅ 5 سجلات علاجية

**أرقام المرضى (لاختبار OTP):**
- 07701234567 - أحمد محمد
- 07701234568 - فاطمة علي
- 07701234569 - حسن كريم
- 07701234570 - زينب أحمد
- 07701234571 - علي محمود

## الخطوة 5: تشغيل الـ Backend

```powershell
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## ملاحظات مهمة

1. **MongoDB يجب أن يكون قيد التشغيل** قبل تشغيل السكريبتات
2. السكريبتات **آمنة** - إذا كانت البيانات موجودة مسبقاً، سيتخطاها
3. لـ **OTP في وضع التطوير**: الرمز يظهر في console logs للـ backend
4. يمكنك تشغيل السكريبتات **مرات متعددة** - لن ينشئ بيانات مكررة

## حل المشاكل

### خطأ: "Connection refused"
- تأكد من أن MongoDB يعمل
- تحقق من `MONGODB_URI` في ملف `.env`

### خطأ: "Module not found"
- تأكد من تفعيل virtualenv
- تأكد من تثبيت جميع المكتبات: `pip install -r requirements.txt`

### خطأ: "Database name not found"
- MongoDB ينشئ قاعدة البيانات تلقائياً عند أول استخدام
- تأكد من الصلاحيات إذا كنت تستخدم MongoDB مع مصادقة

