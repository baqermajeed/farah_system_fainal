# ضبط JWT على سيرفر الكندي (حتى يقبل توكن فرح)

حتى يعمل «إضافة موعد → عيادة الكندي بغداد» من فرونت فرح، سيرفر الكندي **يجب** أن يستخدم نفس **JWT_SECRET** المستخدم في backend فرح.

## القيمة المطلوبة (بدون أخطاء إملائية)

```
JWT_SECRET=farah_sys_final_project
```

(كلمة **project** كاملة بحرف **t** في الآخر، وليس `farah_sys_final_projec`)

---

## الطريقة 1: عبر systemd (موصى بها)

1. افتح ملف الخدمة:
   ```bash
   sudo nano /etc/systemd/system/alkendy_system.service
   ```

2. في قسم `[Service]` أضف سطر البيئة (أو عدّله إن وُجد):
   ```ini
   [Service]
   Environment="JWT_SECRET=farah_sys_final_project"
   # ... باقي الإعدادات (WorkingDirectory, ExecStart, إلخ)
   ```

3. إعادة تحميل systemd وإعادة تشغيل الخدمة:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart alkendy_system.service
   ```

---

## الطريقة 2: عبر ملف .env على السيرفر

1. انتقل لمجلد تشغيل التطبيق (مثلاً حيث يُشغَّل uvicorn)، مثلاً:
   ```bash
   cd /home/alkendy_system/backend
   # أو أينما يوجد فيه app (مثلاً حيث config.py)
   ```

2. أنشئ أو عدّل ملف `.env`:
   ```bash
   nano .env
   ```
   وأضف أو عدّل السطر:
   ```
   JWT_SECRET=farah_sys_final_project
   ```

3. أعد تشغيل الخدمة:
   ```bash
   sudo systemctl restart alkendy_system.service
   ```

---

## التحقق من أن الكود محدّث على السيرفر

تأكد أن التعديلات التالية موجودة في الكود الموجود على السيرفر:

1. **JWT في الإعدادات**
   ```bash
   grep -n "farah_sys_final_project" /home/alkendy_system/backend/app/config.py
   ```
   يجب أن يظهر سطر يحتوي على `JWT_SECRET` و `farah_sys_final_project`.

2. **المستخدم المؤقت من التوكن**
   ```bash
   grep -n "object.__setattr__" /home/alkendy_system/backend/app/security.py
   ```
   يجب أن يظهر سطر فيه `object.__setattr__(user, "id", OID(user_id))`.

إذا لم يظهر شيء، فالمشروع على السيرفر لم يُحدَّث من المستودع الذي فيه هذه التعديلات (مثلاً تحتاج دفع التعديلات إلى GitHub ثم سحبها على السيرفر).

---

## بعد التعديل

بعد ضبط `JWT_SECRET` وإعادة التشغيل، جرّب من التطبيق:
- تسجيل الدخول كـ call center.
- إضافة موعد جديد → اختيار **عيادة الكندي بغداد** → حفظ.

إذا استمر 401، راجع سجلات الخدمة:
```bash
sudo journalctl -u alkendy_system.service -n 100 --no-pager
```
وابحث عن أي رسالة خطأ عند استقبال طلب POST لـ `/call-center/appointments`.

---

## إضافة النقطة لموظف النجف عند القبول من استقبال الكندي

عندما يقبل موظف الاستقبال في **تطبيق الكندي** موعداً أضافه موظف **عيادة النجف** (من تطبيق فرح)، يُفترض أن تُضاف النقطة (عداد المقبولة) إلى حساب ذلك الموظف في **backend فرح**.

1. **Backend فرح (النجف)**  
   ضع في `.env` أو بيئة التشغيل:
   ```
   INTERNAL_API_SECRET=كلمة_سر_مشتركة_قوية
   ```
   (نفس القيمة يجب أن تُستخدم في الكندي أدناه.)

2. **Backend الكندي**  
   ضع في `.env` أو بيئة التشغيل:
   ```
   FARAH_API_BASE_URL=https://sys-api.farahdent.com
   FARAH_INTERNAL_SECRET=كلمة_سر_مشتركة_قوية
   ```
   إذا لم تُضف `FARAH_INTERNAL_SECRET` فلن يُرسل طلب زيادة العداد لفرح (والقبول في الكندي يبقى يعمل بشكل طبيعي).
