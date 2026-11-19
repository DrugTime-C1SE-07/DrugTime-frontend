export default function DeletionRequestsLoading() {
  return (
    <section className="deletion-queue" aria-busy="true">
      <p className="deletion-queue__status" role="status">
        Đang tải hàng chờ…
      </p>
    </section>
  );
}
