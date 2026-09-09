import axios from 'axios';
import { appConfig } from '../config/appConfig';

declare module 'axios' {
  export interface InternalAxiosRequestConfig {
    _retry?: boolean;
    _retryNetworkCount?: number;
  }
}

const ACCESS_KEY = 'farah-access-token';
const REFRESH_KEY = 'farah-refresh-token';

export const http = axios.create({
  baseURL: appConfig.apiBaseUrl,
  timeout: 45000,
});

http.interceptors.request.use((config) => {
  const token = localStorage.getItem(ACCESS_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

let refreshPromise: Promise<string | null> | null = null;
let refreshHardFailed = false;

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem(REFRESH_KEY);
  if (!refreshToken) {
    refreshHardFailed = true;
    return null;
  }
  try {
    const response = await axios.post(
      `${appConfig.apiBaseUrl}/auth/refresh`,
      { refresh_token: refreshToken },
      { headers: { 'Content-Type': 'application/json' } },
    );
    const accessToken = response.data?.access_token as string | undefined;
    const newRefreshToken = response.data?.refresh_token as string | undefined;
    if (!accessToken || !newRefreshToken) return null;
    localStorage.setItem(ACCESS_KEY, accessToken);
    localStorage.setItem(REFRESH_KEY, newRefreshToken);
    window.dispatchEvent(new Event('farah-auth-changed'));
    refreshHardFailed = false;
    return accessToken;
  } catch (error) {
    // نسجل الخروج فقط إذا كان refresh token فعلاً غير صالح.
    if (axios.isAxiosError(error)) {
      const status = error.response?.status;
      refreshHardFailed = status === 400 || status === 401 || status === 403;
    } else {
      refreshHardFailed = false;
    }
    return null;
  }
}

http.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error?.config;
    const method = (originalRequest?.method ?? 'get').toLowerCase();
    const isGet = method === 'get';
    const isTimeout = error?.code === 'ECONNABORTED';
    const isNetworkError = axios.isAxiosError(error) && !error.response;
    const statusCode = error?.response?.status as number | undefined;
    const isServerTransient = typeof statusCode === 'number' && statusCode >= 500;

    if (originalRequest && isGet && (isTimeout || isNetworkError || isServerTransient)) {
      const retryCount = originalRequest._retryNetworkCount ?? 0;
      if (retryCount < 1) {
        originalRequest._retryNetworkCount = retryCount + 1;
        await new Promise((resolve) => setTimeout(resolve, 500));
        return http(originalRequest);
      }
    }

    const status = error?.response?.status;
    const url = originalRequest?.url ?? '';
    const isAuthEndpoint = url.includes('/auth/staff-login') || url.includes('/auth/refresh');

    if (status === 401 && originalRequest && !originalRequest._retry && !isAuthEndpoint) {
      originalRequest._retry = true;
      if (!refreshPromise) {
        refreshPromise = refreshAccessToken().finally(() => {
          refreshPromise = null;
        });
      }
      const newToken = await refreshPromise;
      if (newToken) {
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return http(originalRequest);
      }

      if (refreshHardFailed) {
        localStorage.removeItem(ACCESS_KEY);
        localStorage.removeItem(REFRESH_KEY);
        window.dispatchEvent(new Event('farah-auth-changed'));
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
      }
    }

    return Promise.reject(error);
  },
);
