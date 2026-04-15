const TOKEN_KEY = "pm_admin_token";

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setToken(token: string): void {
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    return;
  }
}

export function clearToken(): void {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    return;
  }
}

interface JwtPayload {
  exp?: number;
  email?: string;
  sub?: string;
  is_admin?: boolean;
}

function base64UrlDecode(input: string): string {
  const pad = input.length % 4;
  const padded = pad ? input + "=".repeat(4 - pad) : input;
  const normalized = padded.replace(/-/g, "+").replace(/_/g, "/");
  if (typeof atob === "function") {
    return atob(normalized);
  }
  return "";
}

export function decodeToken(token: string): JwtPayload | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const json = base64UrlDecode(parts[1]);
    const parsed: unknown = JSON.parse(json);
    if (parsed && typeof parsed === "object") {
      return parsed as JwtPayload;
    }
    return null;
  } catch {
    return null;
  }
}

export function isAuthed(): boolean {
  const token = getToken();
  if (!token) return false;
  const payload = decodeToken(token);
  if (!payload) return false;
  if (typeof payload.exp === "number") {
    const nowSec = Math.floor(Date.now() / 1000);
    if (payload.exp <= nowSec) {
      clearToken();
      return false;
    }
  }
  return true;
}

export function getAdminEmail(): string | null {
  const token = getToken();
  if (!token) return null;
  const payload = decodeToken(token);
  if (!payload) return null;
  return payload.email ?? payload.sub ?? null;
}
