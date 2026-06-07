/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useMemo, useState } from 'react';

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
    const payload = JSON.parse(atob(parts[1]));
    return payload;
  } catch {
    return {};
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [accessToken, setAccessToken] = useState<string | null>(() => localStorage.getItem(ACCESS_KEY));
  const [refreshToken, setRefreshToken] = useState<string | null>(() => localStorage.getItem(REFRESH_KEY));

  const claims = useMemo(() => (accessToken ? parseJwt(accessToken) : {}), [accessToken]);

  const value = useMemo<AuthContextType>(
    () => ({
      accessToken,
      refreshToken,
      role: claims.role ?? null,
      userId: claims.sub ?? null,
      login: (tokens) => {
        setAccessToken(tokens.access_token);
        setRefreshToken(tokens.refresh_token);
        localStorage.setItem(ACCESS_KEY, tokens.access_token);
        localStorage.setItem(REFRESH_KEY, tokens.refresh_token);
      },
      logout: () => {
        setAccessToken(null);
        setRefreshToken(null);
        localStorage.removeItem(ACCESS_KEY);
        localStorage.removeItem(REFRESH_KEY);
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
