"use client";

import { useEffect, useState } from "react";

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: "pharmacist" | "admin" | "reviewer";
  roleName: string;
  title: string;
  department: string;
  avatarInitials: string;
  licenseNumber?: string;
  lastLogin?: string;
}

export const MOCK_ADMIN_ACCOUNTS: AdminUser[] = [
  {
    id: "usr-tri-le",
    name: "DS. Lê Minh Trí",
    email: "tri.le@drugtime.vn",
    role: "pharmacist",
    roleName: "Dược sĩ Lâm sàng",
    title: "Quản trị Dữ liệu Dược",
    department: "Ban Dược Lâm sàng & Thẩm định tương tác",
    avatarInitials: "LT",
    licenseNumber: "CCHN-01824/BYT-HN",
    lastLogin: "2026-03-24 08:30:00",
  },
  {
    id: "usr-admin-quan",
    name: "Nguyễn Hoàng Quân",
    email: "admin@drugtime.vn",
    role: "admin",
    roleName: "Quản trị viên Hệ thống",
    title: "Quản trị viên Hệ thống",
    department: "Bộ phận Công nghệ & Vận hành Dữ liệu",
    avatarInitials: "HQ",
    licenseNumber: "SYS-ADMIN-01",
    lastLogin: "2026-03-24 09:15:00",
  },
  {
    id: "usr-reviewer-huong",
    name: "ThS. DS. Phạm Thu Hương",
    email: "reviewer@drugtime.vn",
    role: "reviewer",
    roleName: "Thẩm định viên Cao cấp",
    title: "Chuyên viên Thẩm định Dược lý",
    department: "Hội đồng Thẩm định Dược thư & Cảnh báo",
    avatarInitials: "TH",
    licenseNumber: "CCHN-00912/BYT-HN",
    lastLogin: "2026-03-23 16:45:00",
  },
];

const DEFAULT_PASSWORD = "Admin@123";
const AUTH_STORAGE_KEY = "drugtime_admin_session";
const AUTH_EVENT_NAME = "drugtime_auth_change";

export interface SessionState {
  user: AdminUser | null;
  isAuthenticated: boolean;
  token?: string;
}

// Safely get stored user
export function getStoredUser(): AdminUser | null {
  if (typeof window === "undefined") {
    // Default fallback on SSR
    return MOCK_ADMIN_ACCOUNTS[0];
  }

  try {
    const raw = localStorage.getItem(AUTH_STORAGE_KEY) || sessionStorage.getItem(AUTH_STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as AdminUser;
  } catch {
    return null;
  }
}

// Save user session
export function setStoredSession(user: AdminUser | null, remember: boolean = true): void {
  if (typeof window === "undefined") return;

  try {
    if (user) {
      const data = JSON.stringify(user);
      if (remember) {
        localStorage.setItem(AUTH_STORAGE_KEY, data);
        sessionStorage.removeItem(AUTH_STORAGE_KEY);
      } else {
        sessionStorage.setItem(AUTH_STORAGE_KEY, data);
        localStorage.removeItem(AUTH_STORAGE_KEY);
      }
    } else {
      localStorage.removeItem(AUTH_STORAGE_KEY);
      sessionStorage.removeItem(AUTH_STORAGE_KEY);
    }

    // Dispatch event to notify components
    window.dispatchEvent(new CustomEvent(AUTH_EVENT_NAME, { detail: user }));
  } catch (err) {
    console.error("Lỗi lưu phiên đăng nhập:", err);
  }
}

// Mock login API simulation
export async function authenticateAdmin(
  email: string,
  password: string,
  remember: boolean = true
): Promise<{ success: boolean; user?: AdminUser; error?: string }> {
  // Simulate realistic network roundtrip
  await new Promise((resolve) => setTimeout(resolve, 600));

  const trimmedEmail = email.trim().toLowerCase();
  const matchedUser = MOCK_ADMIN_ACCOUNTS.find(
    (u) => u.email.toLowerCase() === trimmedEmail
  );

  if (!matchedUser || password !== DEFAULT_PASSWORD) {
    return {
      success: false,
      error: "Địa chỉ email hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.",
    };
  }

  // Set updated login time
  const loggedInUser: AdminUser = {
    ...matchedUser,
    lastLogin: new Date().toISOString().replace("T", " ").substring(0, 19),
  };

  setStoredSession(loggedInUser, remember);

  return {
    success: true,
    user: loggedInUser,
  };
}

// Logout
export function logoutAdmin(): void {
  setStoredSession(null);
}

// React Hook for Auth State
export function useAuthSession() {
  const [currentUser, setCurrentUser] = useState<AdminUser | null>(() => {
    return getStoredUser();
  });

  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Read from storage on client mount
    const saved = getStoredUser();
    setCurrentUser(saved);
    setIsLoading(false);

    const handleAuthChange = (e: Event) => {
      const customEvent = e as CustomEvent<AdminUser | null>;
      setCurrentUser(customEvent.detail || null);
    };

    window.addEventListener(AUTH_EVENT_NAME, handleAuthChange);
    window.addEventListener("storage", (e) => {
      if (e.key === AUTH_STORAGE_KEY) {
        setCurrentUser(getStoredUser());
      }
    });

    return () => {
      window.removeEventListener(AUTH_EVENT_NAME, handleAuthChange);
    };
  }, []);

  const login = async (email: string, pass: string, remember: boolean = true) => {
    const res = await authenticateAdmin(email, pass, remember);
    if (res.success && res.user) {
      setCurrentUser(res.user);
    }
    return res;
  };

  const logout = () => {
    logoutAdmin();
    setCurrentUser(null);
  };

  return {
    user: currentUser,
    isAuthenticated: Boolean(currentUser),
    isLoading,
    login,
    logout,
  };
}
