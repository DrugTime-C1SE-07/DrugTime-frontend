"use client";

import React, { useEffect, useRef, useState, ReactNode } from "react";
import { X } from "lucide-react";

// Thời lượng hiệu ứng đóng; khớp modalFadeOut/modalScaleOut/drawerSlideOut trong globals.css.
const CLOSE_ANIMATION_MS = 160;

export interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: "sm" | "md" | "lg" | "xl";
  /** "drawer": tấm trượt từ cạnh phải, cao hết màn hình. */
  variant?: "center" | "drawer";
  closeOnBackdropClick?: boolean;
}

export function Modal({ isOpen, onClose, title, subtitle, children, footer, size = "md", variant = "center", closeOnBackdropClick = true }: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);
  // Giữ modal thêm CLOSE_ANIMATION_MS sau khi isOpen = false để chạy hiệu ứng đóng rồi mới gỡ.
  const [rendered, setRendered] = useState(isOpen);
  const [closing, setClosing] = useState(false);
  // Nội dung của lần render cuối khi còn mở: trang thường xóa dữ liệu đang chọn cùng lúc đóng,
  // nên trong lúc chạy hiệu ứng đóng vẫn hiện nội dung cũ thay vì ô trống.
  const lastOpenContent = useRef({ title, subtitle, children, footer });
  if (isOpen) lastOpenContent.current = { title, subtitle, children, footer };
  const content = isOpen ? { title, subtitle, children, footer } : lastOpenContent.current;

  useEffect(() => {
    if (isOpen) {
      setRendered(true);
      setClosing(false);
      return;
    }
    if (!rendered) return;
    setClosing(true);
    const timer = window.setTimeout(() => {
      setRendered(false);
      setClosing(false);
    }, CLOSE_ANIMATION_MS);
    return () => window.clearTimeout(timer);
  }, [isOpen, rendered]);

  useEffect(() => {
    if (!isOpen) return;
    previousFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    modalRef.current?.focus();
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = originalOverflow;
      previousFocusRef.current?.focus();
    };
  }, [isOpen]);

  const trapFocus = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") { onClose(); return; }
    if (event.key !== "Tab") return;
    const focusable = modalRef.current?.querySelectorAll<HTMLElement>('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])');
    if (!focusable?.length) { event.preventDefault(); return; }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  };

  if (!rendered) return null;
  const backdropClass = `modal-backdrop modal-backdrop--${variant}${closing ? " is-closing" : ""}`;
  return (
    <div className={backdropClass} role="presentation" onMouseDown={(event) => { if (!closing && closeOnBackdropClick && event.target === event.currentTarget) onClose(); }}>
      <div className={`modal-dialog modal-dialog--${size} modal-dialog--${variant}`} role="dialog" aria-modal="true" aria-labelledby="modal-title" ref={modalRef} tabIndex={-1} onKeyDown={trapFocus}>
        <header className="modal-header"><div className="modal-header__text"><h2 id="modal-title" className="modal-title">{content.title}</h2>{content.subtitle ? <p className="modal-subtitle">{content.subtitle}</p> : null}</div><button type="button" className="modal-close-btn" onClick={onClose} aria-label="Đóng cửa sổ"><X size={20} strokeWidth={2.2} /></button></header>
        <div className="modal-body">{content.children}</div>
        {content.footer ? <footer className="modal-footer">{content.footer}</footer> : null}
      </div>
    </div>
  );
}
