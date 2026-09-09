import { LockOutlined, UserOutlined } from '@ant-design/icons';
import { Alert, Button, Form, Input, message } from 'antd';
import axios from 'axios';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginStaff } from '../services/statsApi';
import { useAuth } from '../state/AuthContext';

type LoginFormValues = {
  username: string;
  password: string;
};

function normalizeUsername(value: string) {
  return value
    .replace(/[\u061C\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]/g, '')
    .trim()
    .replace(/[٠-٩]/g, (digit) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)))
    .replace(/[۰-۹]/g, (digit) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(digit)));
}

function readRoleFromToken(token: string) {
  try {
    const segment = token.split('.')[1] ?? '';
    const base64 = segment.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
    const payload = JSON.parse(atob(padded));
    return typeof payload?.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
}

function loginErrorMessage(err: unknown) {
  if (axios.isAxiosError(err)) {
    if (!err.response) {
      if (err.code === 'ECONNABORTED') {
        return 'انتهت مهلة الاتصال بالخادم. جرّب شبكة أخرى (واي فاي أو بيانات الجوال).';
      }
      return 'تعذر الاتصال بالخادم من هذا الجهاز. افتح الموقع من Chrome مباشرة، وتأكد من وقت الهاتف والإنترنت.';
    }
    if (err.response.status === 400 || err.response.status === 401) {
      return 'فشل تسجيل الدخول، تأكد من اسم المستخدم وكلمة المرور وصلاحيات الحساب.';
    }
    return 'حدث خطأ في الخادم أثناء تسجيل الدخول. حاول مرة أخرى.';
  }
  if (err instanceof Error && /quota|storage|localStorage/i.test(err.message)) {
    return 'المتصفح منع حفظ الجلسة على هذا الهاتف. أوقف التصفح الخاص ثم أعد المحاولة.';
  }
  return 'فشل تسجيل الدخول، تأكد من اسم المستخدم وكلمة المرور وصلاحيات الحساب.';
}

export function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onFinish = async (values: LoginFormValues) => {
    try {
      setLoading(true);
      setError(null);
      const tokens = await loginStaff(normalizeUsername(values.username), values.password);
      login(tokens);
      message.success('تم تسجيل الدخول بنجاح');
      const role = readRoleFromToken(tokens.access_token);
      navigate(role === 'call_center' ? '/call-center/workspace' : '/overview');
    } catch (err) {
      console.error(err);
      setError(loginErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-atmosphere" aria-hidden>
        <span className="login-orb login-orb-a" />
        <span className="login-orb login-orb-b" />
        <span className="login-orb login-orb-c" />
        <span className="login-sheen" />
        <span className="login-mesh" />
      </div>

      <div className="login-shell">
        <header className="login-brand-wrap">
          <p className="login-brand">مركز فرح التخصصي لطب الاسنان</p>
        </header>

        {error ? <Alert className="login-alert" type="error" message={error} showIcon /> : null}

        <Form<LoginFormValues> className="login-form" layout="vertical" onFinish={onFinish} requiredMark={false}>
          <Form.Item name="username" label="اسم المستخدم" rules={[{ required: true, message: 'أدخل اسم المستخدم' }]}>
            <Input
              prefix={<UserOutlined />}
              size="large"
              autoComplete="username"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              inputMode="text"
              dir="ltr"
              placeholder="اسم المستخدم"
            />
          </Form.Item>
          <Form.Item name="password" label="كلمة المرور" rules={[{ required: true, message: 'أدخل كلمة المرور' }]}>
            <Input.Password
              prefix={<LockOutlined />}
              size="large"
              autoComplete="current-password"
              dir="ltr"
              placeholder="كلمة المرور"
            />
          </Form.Item>
          <Button className="login-submit" type="primary" htmlType="submit" loading={loading} block size="large">
            دخول
          </Button>
        </Form>
      </div>
    </div>
  );
}
