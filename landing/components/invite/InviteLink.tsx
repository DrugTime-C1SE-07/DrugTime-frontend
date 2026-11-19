'use client';

import { useEffect, useState } from 'react';
import { androidIntentUrl, groupCode, parseInviteHash } from '@/lib/invite/linkCode';
import '@/app/styles/invite.css';

type State =
  | { kind: 'loading' }
  | { kind: 'invalid' }
  | { kind: 'valid'; code: string; isAndroid: boolean; intentUrl: string };

/**
 * Đọc mã từ `location.hash` ngay trên trình duyệt. Không gọi backend, không gửi mã đi đâu.
 */
export default function InviteLink() {
  const [state, setState] = useState<State>({ kind: 'loading' });
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    const read = () => {
      const code = parseInviteHash(window.location.hash);
      if (code === null) {
        setState({ kind: 'invalid' });
        return;
      }
      setState({
        kind: 'valid',
        code,
        isAndroid: /Android/i.test(navigator.userAgent),
        intentUrl: androidIntentUrl(code, window.location.host, `${window.location.origin}/download`),
      });
    };
    read();
    window.addEventListener('hashchange', read);
    return () => window.removeEventListener('hashchange', read);
  }, []);

  const copy = async (code: string) => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
    } catch {
      // Trình duyệt chặn clipboard: mã vẫn chọn được bằng tay (user-select: all).
      setCopied(false);
    }
  };

  return (
    <section className="section invite">
      <div className="container invite__card">
        <h1 className="section__title">Lời mời theo dõi trên DrugTime</h1>

        {state.kind === 'loading' && <p className="section__lead">Đang đọc lời mời…</p>}

        {state.kind === 'invalid' && (
          <p className="section__lead" role="alert">
            Link mời không hợp lệ hoặc đã bị cắt mất một phần. Hãy nhờ người thân gửi lại link,
            hoặc mở app DrugTime và nhập mã liên kết họ đưa cho bạn.
          </p>
        )}

        {state.kind === 'valid' && (
          <>
            <p className="section__lead">
              Người thân mời bạn theo dõi việc uống thuốc của họ. Mở DrugTime, nhập mã dưới đây và
              gửi yêu cầu. Bạn chỉ xem được thông tin sau khi người thân chấp thuận.
            </p>

            <div className="invite__code-box">
              <span className="invite__label">Mã liên kết</span>
              <output className="invite__code" aria-label="Mã liên kết">
                {groupCode(state.code)}
              </output>
              <button type="button" className="btn invite__copy" onClick={() => copy(state.code)}>
                {copied ? 'Đã sao chép' : 'Sao chép mã'}
              </button>
            </div>

            <div className="invite__actions">
              {state.isAndroid && (
                <a className="btn btn--primary" href={state.intentUrl}>
                  Mở bằng ứng dụng DrugTime
                </a>
              )}
              <a className="btn invite__secondary" href="/download">
                Tải ứng dụng
              </a>
            </div>

            <div className="invite__help">
              <h2>Trên iPhone</h2>
              <p>
                Mở app DrugTime → tab Người thân → Theo dõi người thân → Nhập mã, rồi dán mã ở
                trên.
              </p>
              <h2>Link mở trình duyệt thay vì app?</h2>
              <p>
                Bấm &quot;Mở bằng ứng dụng DrugTime&quot;, hoặc sao chép mã rồi tự mở app và nhập
                mã.
              </p>
            </div>
          </>
        )}
      </div>
    </section>
  );
}
