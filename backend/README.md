# FastAPI Dental Clinic Backend

هيكلة نظيفة وخفيفة (Router + Service + Schemas + Utils) مع RBAC، OTP عبر SMS، WebSocket Chat، إشعارات Firebase، وباركود/QR لكل مريض. قاعدة البيانات الآن MongoDB عبر Beanie/Motor.

## تشغيل محليًا (Dev)
1) أنشئ virtualenv وثبّت الاعتمادات:
   - Windows PowerShell:
     ```powershell
     python -m venv .venv
     . .venv\Scripts\Activate.ps1
     pip install -r requirements.txt
     ```

2) أنشئ ملف .env (أو عدّل الموجود) وحدّد اتصال MongoDB والقيم الأخرى:
   ```dotenv
   # MongoDB
   MONGODB_URI=mongodb://localhost:27017/clinic
   # إن كانت لديك مصادقة:
   # MONGODB_URI=mongodb://USER:PASS@localhost:27017/clinic?authSource=admin

   # JWT
   JWT_SECRET=change_me_super_secret
   JWT_ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=1440

   # CORS (اختياري)
   CORS_ORIGINS=

   # مسار ملفات الميديا
   MEDIA_DIR=media

   # SMS / OTP
   SMS_PROVIDER=dummy # أو twilio
   TWILIO_ACCOUNT_SID=
   TWILIO_AUTH_TOKEN=
   TWILIO_FROM_NUMBER=

   # Firebase (اختياري للإشعارات)
   FIREBASE_CREDENTIALS_FILE=
   ```

3) تأكد من تشغيل MongoDB ثم شغّل الخادم:
   ```powershell
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

- Swagger: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## بنية المجلدات
app/
  main.py
  config.py
  database.py
  security.py
  constants.py
  deps.py
  models/
  routers/
  services/
  schemas/
  utils/
  media/ (تُنشأ تلقائيًا)

## ملاحظات
- قاعدة البيانات: MongoDB عبر Beanie/Motor ويتم ضبطها عبر `MONGODB_URI` في `.env` (لا يوجد SQLite في هذا الإصدار).
- OTP: مزوّد SMS افتراضي `dummy` (يُستخدم للتطوير). لتفعيل Twilio استخدم `SMS_PROVIDER=twilio` وأضف مفاتيح Twilio.
- Firebase: ضع مسار ملف الخدمة في `FIREBASE_CREDENTIALS_FILE` لإرسال إشعارات Push.
- يدعم RBAC عبر `security.require_roles([...])`.
- توجد خدمة تذكير بالمواعيد تعمل في الخلفية (3 أيام / يوم / 4 ساعات قبل الموعد).
