import { getToken } from "./auth";

const BASE_URL = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "/api";

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  query?: Record<string, string | number | undefined>;
}

async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  let url = `${BASE_URL}${path}`;
  if (opts.query) {
    const params = new URLSearchParams();
    for (const [k, v] of Object.entries(opts.query)) {
      if (v !== undefined && v !== "") {
        params.set(k, String(v));
      }
    }
    const qs = params.toString();
    if (qs) url += `?${qs}`;
  }

  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });

  if (!res.ok) {
    let message = `Request failed: ${res.status}`;
    try {
      const data: unknown = await res.json();
      if (
        data &&
        typeof data === "object" &&
        "error" in data &&
        typeof (data as { error: unknown }).error === "string"
      ) {
        message = (data as { error: string }).error;
      }
    } catch {
      // ignore
    }
    throw new ApiError(message, res.status);
  }

  if (res.status === 204) {
    return undefined as T;
  }

  const data = (await res.json()) as T;
  return data;
}

export interface AdminStats {
  total_users: number;
  matches_today: number;
  battles_today: number;
  avg_battle_duration: number;
}

export interface UserListItem {
  id: string;
  display_name: string;
  email_masked: string;
  level: number;
  league: string;
  created_at: string;
}

export interface UserListResponse {
  users: UserListItem[];
  next_cursor: string | null;
}

export interface UserBattleSummary {
  id: string;
  opponent_display_name: string;
  result: string;
  duration_seconds: number;
  ended_at: string;
}

export interface UserDetail {
  id: string;
  display_name: string;
  email: string;
  level: number;
  xp: number;
  league: string;
  created_at: string;
  last_active_at: string | null;
  total_matches: number;
  total_battles: number;
  recent_battles: UserBattleSummary[];
}

export interface BattleListItem {
  id: string;
  p1_display_name: string;
  p2_display_name: string;
  winner_display_name: string | null;
  duration_seconds: number;
  started_at: string;
  ended_at: string | null;
}

export interface BattleListResponse {
  battles: BattleListItem[];
  next_cursor: string | null;
}

export interface LoginResponse {
  token: string;
}

export function login(email: string, password: string): Promise<LoginResponse> {
  return request<LoginResponse>("/auth/admin-login", {
    method: "POST",
    body: { email, password },
  });
}

export function getStats(): Promise<AdminStats> {
  return request<AdminStats>("/admin/stats");
}

export function listUsers(params: {
  cursor?: string;
  limit?: number;
  q?: string;
}): Promise<UserListResponse> {
  return request<UserListResponse>("/admin/users", {
    query: {
      cursor: params.cursor,
      limit: params.limit,
      q: params.q,
    },
  });
}

export function getUser(uid: string): Promise<UserDetail> {
  return request<UserDetail>(`/admin/users/${encodeURIComponent(uid)}`);
}

export function listBattles(params: {
  cursor?: string;
  limit?: number;
}): Promise<BattleListResponse> {
  return request<BattleListResponse>("/admin/battles", {
    query: {
      cursor: params.cursor,
      limit: params.limit,
    },
  });
}
