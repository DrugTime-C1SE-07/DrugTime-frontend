import { cookies } from "next/headers";

import { SESSION_COOKIE } from "../auth/session";

/**
 * Client gọi Backend API từ phía server (route handler, server component).
 * Không gọi từ trình duyệt: token nằm trong cookie httpOnly và địa chỉ backend là biến môi trường
 * server (`DRUGTIME_API_BASE_URL`, không có tiền tố NEXT_PUBLIC_).
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | null,
  ) {
    super(`Backend API ${status}${code ? ` ${code}` : ""}`);
  }
}

type ApiRequest = {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
  token?: string;
};

function baseUrl(): string {
  const url = process.env.DRUGTIME_API_BASE_URL;
  if (!url) {
    throw new ApiError(503, "api_base_url_missing");
  }
  return url.replace(/\/$/, "");
}

export async function apiFetch<T>(path: string, request: ApiRequest = {}): Promise<T> {
  const { method = "POST", body, token } = request;
  let response: Response;
  try {
    response = await fetch(`${baseUrl()}${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      cache: "no-store",
    });
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(503, "auth_provider_unavailable");
  }

  if (!response.ok) {
    let code: string | null = null;
    try {
      const data = await response.json();
      code = typeof data?.detail === "string" ? data.detail : null;
    } catch {
      code = null;
    }
    throw new ApiError(response.status, code);
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

/** Gọi Backend API bằng phiên admin đang lưu trong cookie (cho các màn dashboard). */
export async function apiFetchWithSession<T>(
  path: string,
  request: Omit<ApiRequest, "token"> = {},
): Promise<T> {
  const token = cookies().get(SESSION_COOKIE)?.value;
  if (!token) {
    throw new ApiError(401, null);
  }
  return apiFetch<T>(path, { ...request, token });
}

/** Mã lỗi trả về trình duyệt; không chuyển tiếp `detail` của backend. */
export type BrowserErrorCode =
  | "invalid_credentials"
  | "session_expired"
  | "admin_required"
  | "invalid_input"
  | "rate_limited"
  | "unavailable";

export function toBrowserError(
  error: unknown,
  context: "login" | "session",
): { status: number; code: BrowserErrorCode } {
  const status = error instanceof ApiError ? error.status : 503;
  switch (status) {
    case 401:
      return { status, code: context === "login" ? "invalid_credentials" : "session_expired" };
    case 403:
      return { status, code: "admin_required" };
    case 422:
      return { status, code: "invalid_input" };
    case 429:
      return { status, code: "rate_limited" };
    default:
      return { status: 503, code: "unavailable" };
  }
}
