import Link from "next/link";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";

import DeletionQueueTable from "../../../components/deletion-requests/DeletionQueueTable";
import QueueStatus from "../../../components/deletion-requests/QueueStatus";
import RefreshButton from "../../../components/deletion-requests/RefreshButton";
import { ApiError } from "../../../lib/api/client";
import { fetchDeletionQueue } from "../../../lib/api/deletion-requests";
import {
  overflowTarget,
  pageCount,
  parsePage,
  queueErrorView,
  type DeletionQueuePage,
} from "../../../lib/deletion-requests/queue";

// Quyền admin do backend quyết ở mỗi lượt tải; không cache trang.
export const dynamic = "force-dynamic";

type PageProps = {
  searchParams: { page?: string | string[] };
};

export default async function DeletionRequestsPage({ searchParams }: PageProps) {
  const page = parsePage(searchParams.page);

  let queue: DeletionQueuePage;
  try {
    queue = await fetchDeletionQueue(page);
  } catch (error) {
    if (!(error instanceof ApiError)) throw error;
    return (
      <QueuePage>
        <QueueStatus view={queueErrorView(error.status)} />
      </QueuePage>
    );
  }

  const target = overflowTarget(page, queue.total, queue.items.length);
  if (target !== null) {
    redirect(`/dashboard/deletion-requests?page=${target}`);
  }

  const pages = pageCount(queue.total);

  return (
    <QueuePage>
      <div className="deletion-queue__toolbar">
        <p className="deletion-queue__total">
          Tổng số yêu cầu chờ duyệt: <strong>{queue.total}</strong>
        </p>
        <RefreshButton label="Làm mới" />
      </div>
      {queue.items.length === 0 ? (
        <QueueStatus view="empty" />
      ) : (
        <>
          <DeletionQueueTable items={queue.items} />
          <nav className="deletion-queue__pagination" aria-label="Phân trang hàng chờ">
            {page > 1 ? (
              <Link className="dashboard-action dashboard-action--secondary" href={`?page=${page - 1}`}>
                Trang trước
              </Link>
            ) : null}
            <span aria-current="page">
              Trang {page} / {pages}
            </span>
            {page < pages ? (
              <Link className="dashboard-action dashboard-action--secondary" href={`?page=${page + 1}`}>
                Trang sau
              </Link>
            ) : null}
          </nav>
        </>
      )}
    </QueuePage>
  );
}

function QueuePage({ children }: { children: ReactNode }) {
  return (
    <section className="deletion-queue">
      <header className="medications-header">
        <div>
          <h1>Yêu cầu xóa dữ liệu</h1>
          <p>Các yêu cầu đang chờ duyệt, yêu cầu cũ nhất ở trên cùng.</p>
        </div>
      </header>
      {children}
    </section>
  );
}
