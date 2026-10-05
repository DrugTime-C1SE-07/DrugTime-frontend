import LoginForm from "../../../components/auth/LoginForm";

export default function LoginPage() {
  return (
    <main className="auth-page">
      <section className="auth-card">
        <span className="auth-card__eyebrow">DrugTime Admin</span>
        <h1>Đăng nhập quản trị</h1>
        <p>Dùng tài khoản quản trị viên để vào trang quản trị.</p>
        <LoginForm />
      </section>
    </main>
  );
}
