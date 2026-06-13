import { LockOutlined, UserOutlined } from '@ant-design/icons';
import { Alert, Button, Card, Form, Input, Space, Typography, message } from 'antd';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginStaff } from '../services/statsApi';
import { useAuth } from '../state/AuthContext';

type LoginFormValues = {
  username: string;
  password: string;
};

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
      navigate('/overview');
    } catch (err) {
      console.error(err);
      setError('فشل تسجيل الدخول، تأكد من اسم المستخدم وكلمة المرور وصلاحيات الحساب.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <Card className="login-card">
        <Space direction="vertical" size={6} style={{ width: '100%' }}>
          <Typography.Title level={3} style={{ marginBottom: 0 }}>
            لوحة تحكم مركز فرح
          </Typography.Title>
          <Typography.Text type="secondary">
            تسجيل دخول الطاقم الإداري والطبي
          </Typography.Text>
        </Space>

        {error && <Alert type="error" message={error} showIcon style={{ marginTop: 16 }} />}

        <Form<LoginFormValues> layout="vertical" onFinish={onFinish} style={{ marginTop: 20 }}>
          <Form.Item name="username" label="اسم المستخدم" rules={[{ required: true }]}>
            <Input prefix={<UserOutlined />} size="large" />
          </Form.Item>
          <Form.Item name="password" label="كلمة المرور" rules={[{ required: true }]}>
            <Input.Password prefix={<LockOutlined />} size="large" />
          </Form.Item>
          <Button type="primary" htmlType="submit" loading={loading} block size="large">
            دخول
          </Button>
        </Form>
      </Card>
    </div>
  );
}
