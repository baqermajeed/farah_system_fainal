/* eslint-disable react-refresh/only-export-components */
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { ConfigProvider, theme } from 'antd';
import arEG from 'antd/locale/ar_EG';
import dayjs from 'dayjs';
import 'dayjs/locale/ar';
import './index.css';
import App from './App';
import { ThemeProvider, useThemeMode } from './state/ThemeContext';
import { AuthProvider } from './state/AuthContext';

dayjs.locale('ar');

function ProvidersContent() {
  const { mode } = useThemeMode();
  return (
    <ConfigProvider
      direction="rtl"
      locale={arEG}
      theme={{
        algorithm: mode === 'dark' ? theme.darkAlgorithm : theme.defaultAlgorithm,
        token: {
          borderRadius: 12,
          colorPrimary: '#00A79D',
          fontFamily: "'Lama Sans', 'IBM Plex Sans Arabic', Tajawal, Segoe UI, sans-serif",
          fontWeightStrong: 600,
        },
      }}
    >
      <BrowserRouter>
        <AuthProvider>
          <App />
        </AuthProvider>
      </BrowserRouter>
    </ConfigProvider>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ThemeProvider>
      <ProvidersContent />
    </ThemeProvider>
  </StrictMode>,
);
