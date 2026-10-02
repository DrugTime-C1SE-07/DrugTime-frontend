"use client";

import { useEffect, useRef } from "react";

/** Phiên admin 20 phút; khi người dùng thao tác và còn dưới 15 phút thì gia hạn. */
const REFRESH_WHEN_REMAINING_MS = 15 * 60 * 1000;
const ACTIVITY_THROTTLE_MS = 15 * 1000;

function goToLogin() {
  window.location.assign("/auth/login");
}

/**
 * Gia hạn phiên khi người dùng còn thao tác; không thao tác quá 20 phút thì phiên hết hạn
 * và lần thao tác kế tiếp đưa về trang đăng nhập.
 */
export default function SessionKeepAlive({ expiresAt }: { expiresAt: number | null }) {
  const expiry = useRef(expiresAt);
  const lastCheck = useRef(0);
  const refreshing = useRef(false);

  useEffect(() => {
    async function refresh() {
      refreshing.current = true;
      try {
        const response = await fetch("/api/session/refresh", { method: "POST" });
        if (!response.ok) {
          goToLogin();
          return;
        }
        const data = await response.json();
        expiry.current = Date.parse(data.expires_at);
      } catch {
        // Mất mạng tạm thời: thử lại ở lần thao tác sau; hết hạn thật thì nhánh dưới chuyển trang.
      } finally {
        refreshing.current = false;
      }
    }

    function onActivity() {
      const now = Date.now();
      if (now - lastCheck.current < ACTIVITY_THROTTLE_MS || refreshing.current) return;
      lastCheck.current = now;
      if (expiry.current === null || now >= expiry.current) {
        goToLogin();
        return;
      }
      if (expiry.current - now < REFRESH_WHEN_REMAINING_MS) {
        void refresh();
      }
    }

    function onVisibility() {
      if (document.visibilityState === "visible") {
        lastCheck.current = 0;
        onActivity();
      }
    }

    window.addEventListener("pointerdown", onActivity);
    window.addEventListener("keydown", onActivity);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.removeEventListener("pointerdown", onActivity);
      window.removeEventListener("keydown", onActivity);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  return null;
}
