import { Navigate, Route, Routes } from 'react-router-dom';
import { useMemo } from 'react';
import { DashboardLayout } from './layouts/DashboardLayout';
import { LoginPage } from './pages/LoginPage';
import { OverviewPage } from './pages/OverviewPage';
import { SystemAnalyticsPage } from './pages/SystemAnalyticsPage';
import { DoctorsComparisonPage } from './pages/DoctorsComparisonPage';
import { DoctorDetailsPage } from './pages/DoctorDetailsPage';
import { DoctorsGalleryPage } from './pages/DoctorsGalleryPage';
import { useAuth } from './state/AuthContext';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { accessToken } = useAuth();
  const isLoggedIn = useMemo(() => Boolean(accessToken), [accessToken]);
  if (!isLoggedIn) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
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
        <Route index element={<Navigate to="/overview" replace />} />
        <Route path="overview" element={<OverviewPage />} />
        <Route path="doctors" element={<DoctorsGalleryPage />} />
        <Route path="system-analytics" element={<SystemAnalyticsPage />} />
        <Route path="doctors-comparison" element={<DoctorsComparisonPage />} />
        <Route path="doctor-details" element={<DoctorDetailsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/overview" replace />} />
    </Routes>
  );
}
