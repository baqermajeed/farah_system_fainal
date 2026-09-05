import { LockOutlined, UserOutlined } from '@ant-design/icons';
import { Alert, Button, Form, Input, message } from 'antd';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginStaff } from '../services/statsApi';
import { useAuth } from '../state/AuthContext';

type LoginFormValues = {
  username: string;
  password: string;
};

function readRoleFromToken(token: string) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1] ?? ''));
    return typeof payload?.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
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
      const tokens = await loginStaff(values.username, values.password);
      login(tokens);
      message.success('تم تسجيل الدخول بنجاح');
      const role = readRoleFromToken(tokens.access_token);
      navigate(role === 'call_center' ? '/call-center/workspace' : '/overview');
    } catch (err) {
      console.error(err);
      setError('فشل تسجيل الدخول، تأكد من اسم المستخدم وكلمة المرور وصلاحيات الحساب.');
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
            <Input prefix={<UserOutlined />} size="large" autoComplete="username" placeholder="اسم المستخدم" />
          </Form.Item>
          <Form.Item name="password" label="كلمة المرور" rules={[{ required: true, message: 'أدخل كلمة المرور' }]}>
            <Input.Password prefix={<LockOutlined />} size="large" autoComplete="current-password" placeholder="كلمة المرور" />
          </Form.Item>
          <Button className="login-submit" type="primary" htmlType="submit" loading={loading} block size="large">
            دخول
          </Button>
        </Form>
      </div>
    </div>
  );
}
