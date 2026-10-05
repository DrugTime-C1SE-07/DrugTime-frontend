"use client";

import React, { createContext, useContext, useState, useCallback, useEffect, ReactNode } from "react";
import { CheckCircle2, AlertCircle, Info, AlertTriangle, X } from "lucide-react";

export type ToastType = "success" | "error" | "info" | "warning";

export interface ToastItem {
  id: string;
  type: ToastType;
  title: string;
  message?: string;
  duration?: number;
  action?: {
    label: string;
    onClick: () => void;
  };
}

interface ToastContextValue {
  toasts: ToastItem[];
  showToast: (toast: Omit<ToastItem, "id">) => void;
  removeToast: (id: string) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

export function useToast(): ToastContextValue {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return context;
}

const ToastIcon = ({ type }: { type: ToastType }) => {
  switch (type) {
    case "success":
      return <CheckCircle2 className="toast-icon toast-icon--success" size={20} strokeWidth={2.2} />;
    case "error":
      return <AlertCircle className="toast-icon toast-icon--error" size={20} strokeWidth={2.2} />;
    case "warning":
      return <AlertTriangle className="toast-icon toast-icon--warning" size={20} strokeWidth={2.2} />;
    case "info":
    default:
      return <Info className="toast-icon toast-icon--info" size={20} strokeWidth={2.2} />;
  }
};

function ToastMessageItem({
  toast,
  onClose,
}: {
  toast: ToastItem;
  onClose: (id: string) => void;
}) {
  useEffect(() => {
    const duration = toast.duration ?? 4000;
    if (duration > 0) {
      const timer = setTimeout(() => {
        onClose(toast.id);
      }, duration);
      return () => clearTimeout(timer);
    }
  }, [toast, onClose]);

  return (
    <div
      className={`toast-item toast-item--${toast.type}`}
      role="alert"
      aria-live="polite"
    >
      <div className="toast-item__indicator" />
      <div className="toast-item__icon-wrapper">
        <ToastIcon type={toast.type} />
      </div>
      <div className="toast-item__content">
        <strong className="toast-item__title">{toast.title}</strong>
        {toast.message ? <p className="toast-item__message">{toast.message}</p> : null}
      </div>
      {toast.action ? (
        <button
          type="button"
          className="toast-item__action-btn"
          onClick={() => {
            toast.action?.onClick();
            onClose(toast.id);
          }}
        >
          {toast.action.label}
        </button>
      ) : null}
      <button
        type="button"
        className="toast-item__close-btn"
        aria-label="Đóng thông báo"
        onClick={() => onClose(toast.id)}
      >
        <X size={16} strokeWidth={2.2} />
      </button>
    </div>
  );
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const showToast = useCallback((toast: Omit<ToastItem, "id">) => {
    const id = `toast-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    setToasts((prev) => [...prev, { ...toast, id }]);
  }, []);

  return (
    <ToastContext.Provider value={{ toasts, showToast, removeToast }}>
      {children}
      <div className="toast-container" aria-label="Khu vực thông báo hệ thống">
        {toasts.map((toast) => (
          <ToastMessageItem key={toast.id} toast={toast} onClose={removeToast} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}
