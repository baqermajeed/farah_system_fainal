import {
  BarChartOutlined,
  DashboardOutlined,
  MedicineBoxOutlined,
  LogoutOutlined,
  MoonOutlined,
  SunOutlined,
  TeamOutlined,
} from '@ant-design/icons';
import { Button, Layout, Menu, Space, Typography } from 'antd';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useThemeMode } from '../state/ThemeContext';
import { useAuth } from '../state/AuthContext';

const { Header, Sider, Content } = Layout;

export function DashboardLayout() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { mode, toggleTheme } = useThemeMode();
  const { logout, role } = useAuth();

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider width={280} theme={mode}>
        <div className="logo-wrap">
          <Typography.Title level={4} style={{ margin: 0 }}>
            Farah CRM
          </Typography.Title>
          <Typography.Text type="secondary">لوحة التحكم الإدارية</Typography.Text>
        </div>

        <Menu
          mode="inline"
          selectedKeys={[pathname]}
          theme={mode}
          items={[
            {
              key: '/overview',
              icon: <DashboardOutlined />,
              label: <Link to="/overview">نظرة عامة</Link>,
            },
            {
              key: '/system-analytics',
              icon: <BarChartOutlined />,
              label: <Link to="/system-analytics">إحصائيات النظام</Link>,
            },
            {
              key: '/doctors',
              icon: <MedicineBoxOutlined />,
              label: <Link to="/doctors">قائمة الأطباء</Link>,
            },
            {
              key: '/doctors-comparison',
              icon: <TeamOutlined />,
              label: <Link to="/doctors-comparison">مقارنة الأطباء</Link>,
            },
          ]}
        />
      </Sider>

      <Layout>
        <Header className="top-header">
          <Space>
            <Button
              icon={mode === 'dark' ? <SunOutlined /> : <MoonOutlined />}
              onClick={toggleTheme}
            >
              {mode === 'dark' ? 'الوضع الفاتح' : 'الوضع الداكن'}
            </Button>
            <Button
              danger
              icon={<LogoutOutlined />}
              onClick={() => {
                logout();
                navigate('/login');
              }}
            >
              تسجيل الخروج
            </Button>
          </Space>
          <Typography.Text>
            الدور الحالي: <b>{role ?? 'غير معروف'}</b>
          </Typography.Text>
        </Header>

        <Content style={{ padding: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
