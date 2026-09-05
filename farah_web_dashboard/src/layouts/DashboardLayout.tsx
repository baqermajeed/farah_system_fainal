import {
  CustomerServiceOutlined,
  DashboardOutlined,
  MedicineBoxOutlined,
  LogoutOutlined,
  MoonOutlined,
  SunOutlined,
  TeamOutlined,
  MenuOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { Avatar, Button, Drawer, Grid, Layout, Menu, Space, Typography } from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useThemeMode } from '../state/ThemeContext';
import { useAuth } from '../state/AuthContext';

const { Header, Sider, Content } = Layout;
const { useBreakpoint } = Grid;

function readStaffDisplayName(accessToken: string | null) {
  try {
    if (!accessToken) return 'موظف الكول سنتر';
    const payload = JSON.parse(atob(accessToken.split('.')[1] ?? ''));
    return (
      payload.name ||
      payload.username ||
      payload.preferred_username ||
      payload.sub ||
      'موظف الكول سنتر'
    );
  } catch {
    return 'موظف الكول سنتر';
  }
}

export function DashboardLayout() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { mode, toggleTheme } = useThemeMode();
  const { logout, role, accessToken } = useAuth();
  const screens = useBreakpoint();
  const isMobile = !screens.md;
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const selectedMenuKey =
    pathname.startsWith('/call-center/') && pathname !== '/call-center/workspace' ? '/call-center' : pathname;
  const isCallCenterMobileWorkspace = isMobile && pathname.startsWith('/call-center/workspace');
  const staffDisplayName = useMemo(() => readStaffDisplayName(accessToken), [accessToken]);

  useEffect(() => {
    if (!isMobile) {
      setMobileMenuOpen(false);
    }
  }, [isMobile]);

  const menuItems =
    role === 'call_center'
      ? [
          {
            key: '/call-center/workspace',
            icon: <CustomerServiceOutlined />,
            label: <Link to="/call-center/workspace">منصة الكول سنتر</Link>,
          },
        ]
      : [
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

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const sidebarContent = (
    <>
      <div className="logo-wrap">
        <Typography.Title level={4} style={{ margin: 0 }}>
          Farah CRM
        </Typography.Title>
        <Typography.Text type="secondary">
          {role === 'call_center' ? 'بوابة موظف الكول سنتر' : 'لوحة التحكم الإدارية'}
        </Typography.Text>
      </div>

      <Menu
        mode="inline"
        selectedKeys={[selectedMenuKey]}
        theme={mode}
        onClick={() => {
          if (isMobile) {
            setMobileMenuOpen(false);
          }
        }}
        items={menuItems}
      />
      {isMobile && (
        <div className="mobile-drawer-actions">
          <Button
            block
            icon={mode === 'dark' ? <SunOutlined /> : <MoonOutlined />}
            onClick={toggleTheme}
          >
            {mode === 'dark' ? 'الوضع الفاتح' : 'الوضع الداكن'}
          </Button>
          <Button danger block icon={<LogoutOutlined />} onClick={handleLogout}>
            تسجيل الخروج
          </Button>
        </div>
      )}
    </>
  );

  return (
    <Layout style={{ minHeight: '100vh' }}>
      {isMobile ? (
        <Drawer
          placement="right"
          width={300}
          title="القائمة"
          className="mobile-nav-drawer"
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
        <Header className={`top-header ${isCallCenterMobileWorkspace ? 'cc-app-top-header' : ''}`}>
          {isCallCenterMobileWorkspace ? (
            <div className="cc-app-header">
              <div className="cc-app-header-user">
                <Avatar size={48} className="cc-app-header-avatar" icon={<UserOutlined />} />
                <div className="cc-app-header-copy">
                  <div className="cc-app-header-hello">
                    <span className="cc-mobile-online-dot" />
                    <span>مرحباً</span>
                    <span className="cc-app-header-name">{staffDisplayName}</span>
                  </div>
                  <div className="cc-app-header-sub">أهلاً بك في لوحة تحكم مركز الاتصالات</div>
                </div>
              </div>
              <Button
                className="cc-app-header-menu"
                type="text"
                icon={<MenuOutlined />}
                onClick={() => setMobileMenuOpen(true)}
                aria-label="فتح القائمة"
              />
            </div>
          ) : (
            <div className="top-header-inner">
              {isMobile && (
                <Button
                  icon={<MenuOutlined />}
                  onClick={() => setMobileMenuOpen(true)}
                  aria-label="فتح القائمة"
                />
              )}
              {isMobile ? (
                <Typography.Text className="mobile-header-title">Farah CRM</Typography.Text>
              ) : (
                <Space wrap>
                  <Button
                    icon={mode === 'dark' ? <SunOutlined /> : <MoonOutlined />}
                    onClick={toggleTheme}
                  >
                    {mode === 'dark' ? 'الوضع الفاتح' : 'الوضع الداكن'}
                  </Button>
                  <Button danger icon={<LogoutOutlined />} onClick={handleLogout}>
                    تسجيل الخروج
                  </Button>
                </Space>
              )}
            </div>
          )}
        </Header>

        <Content className="dashboard-content">
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
