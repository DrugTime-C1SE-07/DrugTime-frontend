import Link from "next/link";

export default function LoginPage() {
  return (
    <main className="auth-page">
      <section className="auth-card">
        <span className="auth-card__eyebrow">DrugTime Admin</span>
        <h1>Đăng nhập quản trị</h1>
        <p>Trang đăng nhập sẽ được nối với hệ thống xác thực ở bước tiếp theo.</p>
        <Link className="auth-card__link" href="/dashboard">
          Vào dashboard mẫu
        </Link>
      </section>
    </main>
  );
}
