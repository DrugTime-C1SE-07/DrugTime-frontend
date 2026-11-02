import Link from "next/link";
import type { ReactNode } from "react";

type DashboardCardProps = {
  title: string;
  subtitle?: string;
  aside?: ReactNode;
  /** Câu báo lỗi khi API của thẻ không tải được; thay toàn bộ nội dung thẻ. */
  error?: string;
  /** Câu hiển thị khi chưa đủ dữ liệu để vẽ; `false`/bỏ trống = có dữ liệu. */
  empty?: string | false;
  dark?: boolean;
  className?: string;
  children?: ReactNode;
};

export default function DashboardCard({ title, subtitle, aside, error, empty, dark, className = "", children }: DashboardCardProps) {
  return (
    <article className={`bento-card${dark ? " bento-card--dark" : ""} ${className}`.trim()}>
      <header className="bento-card__head">
        <div>
          <h2>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        {aside && !error ? <div className="bento-card__aside">{aside}</div> : null}
      </header>
      {error ? (
        <p className="bento-card__state bento-card__state--error" role="alert">
          {error} <Link href="/dashboard">Tải lại</Link>
        </p>
      ) : empty ? (
        <p className="bento-card__state">{empty}</p>
      ) : (
        <div className="bento-card__body">{children}</div>
      )}
    </article>
  );
}
