import { Navigate, Route, Routes } from 'react-router-dom';
import { useMemo } from 'react';
import { DashboardLayout } from './layouts/DashboardLayout';
import { LoginPage } from './pages/LoginPage';
import { OverviewPage } from './pages/OverviewPage';
import { DoctorsComparisonPage } from './pages/DoctorsComparisonPage';
import { DoctorDetailsPage } from './pages/DoctorDetailsPage';
import { DoctorsGalleryPage } from './pages/DoctorsGalleryPage';
import { CallCenterStaffPage } from './pages/CallCenterStaffPage';
import { CallCenterStaffDetailsPage } from './pages/CallCenterStaffDetailsPage';
import { CallCenterWorkspacePage } from './pages/CallCenterWorkspacePage';
import { useAuth } from './state/AuthContext';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { accessToken } = useAuth();
  const isLoggedIn = useMemo(() => Boolean(accessToken), [accessToken]);
  if (!isLoggedIn) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

function RoleRoute({
  children,
  allowedRoles,
}: {
  children: React.ReactNode;
  allowedRoles: string[];
}) {
  const { role } = useAuth();
  if (!role || !allowedRoles.includes(role)) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

function HomeRedirect() {
  const { role } = useAuth();
  if (role === 'call_center') {
    return <Navigate to="/call-center/workspace" replace />;
  }
  return <Navigate to="/overview" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<HomeRedirect />} />
        <Route path="overview" element={<OverviewPage />} />
        <Route path="doctors" element={<DoctorsGalleryPage />} />
        <Route path="doctors-comparison" element={<DoctorsComparisonPage />} />
        <Route
          path="call-center"
          element={
            <RoleRoute allowedRoles={['admin']}>
              <CallCenterStaffPage />
            </RoleRoute>
          }
        />
        <Route
          path="call-center/:staffId"
          element={
            <RoleRoute allowedRoles={['admin']}>
              <CallCenterStaffDetailsPage />
            </RoleRoute>
          }
        />
        <Route
          path="call-center/workspace"
          element={
            <RoleRoute allowedRoles={['call_center', 'admin']}>
              <CallCenterWorkspacePage />
            </RoleRoute>
          }
        />
        <Route path="doctor-details" element={<DoctorDetailsPage />} />
      </Route>
      <Route path="*" element={<HomeRedirect />} />
    </Routes>
  );
}
