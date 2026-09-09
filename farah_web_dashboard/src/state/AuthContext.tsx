/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useMemo, useState } from 'react';

type AuthContextType = {
  accessToken: string | null;
  refreshToken: string | null;
  role: string | null;
  userId: string | null;
  login: (tokens: { access_token: string; refresh_token: string }) => void;
  logout: () => void;
};

const ACCESS_KEY = 'farah-access-token';
const REFRESH_KEY = 'farah-refresh-token';

const AuthContext = createContext<AuthContextType | null>(null);

function parseJwt(token: string): { role?: string; sub?: string } {
  try {
    const parts = token.split('.');
    if (parts.length < 2) return {};
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
    return JSON.parse(atob(padded));
  } catch {
    return {};
  }
}

function readAuthStorage(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeAuthStorage(accessToken: string | null, refreshToken: string | null) {
  try {
    if (accessToken && refreshToken) {
      localStorage.setItem(ACCESS_KEY, accessToken);
      localStorage.setItem(REFRESH_KEY, refreshToken);
      return;
    }
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  } catch {
    throw new Error('localStorage is blocked on this device');
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [accessToken, setAccessToken] = useState<string | null>(() => readAuthStorage(ACCESS_KEY));
  const [refreshToken, setRefreshToken] = useState<string | null>(() => readAuthStorage(REFRESH_KEY));

  useEffect(() => {
    const syncFromStorage = () => {
      setAccessToken(readAuthStorage(ACCESS_KEY));
      setRefreshToken(readAuthStorage(REFRESH_KEY));
    };

    const onStorage = (event: StorageEvent) => {
      if (!event.key || event.key === ACCESS_KEY || event.key === REFRESH_KEY) {
        syncFromStorage();
      }
    };

    window.addEventListener('storage', onStorage);
    window.addEventListener('farah-auth-changed', syncFromStorage);
    return () => {
      window.removeEventListener('storage', onStorage);
      window.removeEventListener('farah-auth-changed', syncFromStorage);
    };
  }, []);

  const claims = useMemo(() => (accessToken ? parseJwt(accessToken) : {}), [accessToken]);

  const value = useMemo<AuthContextType>(
    () => ({
      accessToken,
      refreshToken,
      role: claims.role ?? null,
      userId: claims.sub ?? null,
      login: (tokens) => {
        writeAuthStorage(tokens.access_token, tokens.refresh_token);
        setAccessToken(tokens.access_token);
        setRefreshToken(tokens.refresh_token);
      },
      logout: () => {
        writeAuthStorage(null, null);
        setAccessToken(null);
        setRefreshToken(null);
      },
    }),
    [accessToken, refreshToken, claims.role, claims.sub],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
