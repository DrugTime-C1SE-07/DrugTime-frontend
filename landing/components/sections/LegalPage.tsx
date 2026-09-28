/** Shared shell for legal pages. Content is pending from the legal/product team. */
export default function LegalPage({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <section className="section">
      <div className="container legal">
        <h1 className="section__title">{title}</h1>
        {children ?? <p className="section__lead">Nội dung đang được cập nhật.</p>}
      </div>
    </section>
  );
}
