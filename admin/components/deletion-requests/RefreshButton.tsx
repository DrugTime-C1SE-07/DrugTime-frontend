"use client";

import { RefreshCw } from "lucide-react";
import { useRouter } from "next/navigation";
import { useTransition } from "react";

/** Tải lại trang từ server (no-store); dùng cho cả "Làm mới" và "Thử lại". */
export default function RefreshButton({ label }: { label: string }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <button
      type="button"
      className="dashboard-action dashboard-action--secondary deletion-queue__refresh"
      onClick={() => startTransition(() => router.refresh())}
      disabled={pending}
      aria-busy={pending}
    >
      <RefreshCw size={16} strokeWidth={2.2} aria-hidden="true" />
      <span>{pending ? "Đang tải…" : label}</span>
    </button>
  );
}
