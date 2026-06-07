import axios from 'axios';
import { appConfig } from '../config/appConfig';

declare module 'axios' {
  export interface InternalAxiosRequestConfig {
    _retry?: boolean;
  }
}

const ACCESS_KEY = 'farah-access-token';
const REFRESH_KEY = 'farah-refresh-token';

export const http = axios.create({
  baseURL: appConfig.apiBaseUrl,
  timeout: 20000,
});

http.interceptors.request.use((config) => {
  const token = localStorage.getItem(ACCESS_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem(REFRESH_KEY);
  if (!refreshToken) return null;
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
    return accessToken;
  } catch {
    return null;
  }
}

http.interceptors.response.use(
  (response) => response,
  async (error) => {
    const status = error?.response?.status;
    const originalRequest = error?.config;
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

      localStorage.removeItem(ACCESS_KEY);
      localStorage.removeItem(REFRESH_KEY);
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }

    return Promise.reject(error);
  },
);
