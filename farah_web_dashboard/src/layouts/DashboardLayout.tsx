import {
  CustomerServiceOutlined,
  DashboardOutlined,
  MedicineBoxOutlined,
  LogoutOutlined,
  MoonOutlined,
  SunOutlined,
  TeamOutlined,
  MenuOutlined,
} from '@ant-design/icons';
import { Button, Drawer, Grid, Layout, Menu, Space, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useThemeMode } from '../state/ThemeContext';
import { useAuth } from '../state/AuthContext';

const { Header, Sider, Content } = Layout;
const { useBreakpoint } = Grid;

export function DashboardLayout() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { mode, toggleTheme } = useThemeMode();
  const { logout } = useAuth();
  const screens = useBreakpoint();
  const isMobile = !screens.lg;
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    if (!isMobile) {
      setMobileMenuOpen(false);
    }
  }, [isMobile]);

  const menuItems = [
    {
      key: '/overview',
      icon: <DashboardOutlined />,
      label: <Link to="/overview">نظرة عامة</Link>,
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
    {
      key: '/call-center',
      icon: <CustomerServiceOutlined />,
      label: <Link to="/call-center">موظفي الكول سنتر</Link>,
    },
  ];

  const sidebarContent = (
    <>
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
        onClick={() => {
          if (isMobile) {
            setMobileMenuOpen(false);
          }
        }}
        items={menuItems}
      />
    </>
  );

  return (
    <Layout style={{ minHeight: '100vh' }}>
      {isMobile ? (
        <Drawer
          placement="right"
          width={280}
          title="القائمة"
          open={mobileMenuOpen}
          onClose={() => setMobileMenuOpen(false)}
          styles={{ body: { padding: 0 } }}
        >
          {sidebarContent}
        </Drawer>
      ) : (
        <Sider width={280} theme={mode}>
          {sidebarContent}
        </Sider>
      )}

      <Layout>
        <Header className="top-header">
          <div className="top-header-inner">
            {isMobile && (
              <Button
                icon={<MenuOutlined />}
                onClick={() => setMobileMenuOpen(true)}
                aria-label="فتح القائمة"
              />
            )}
            <Space wrap>
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
          </div>
        </Header>

        <Content className="dashboard-content">
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
