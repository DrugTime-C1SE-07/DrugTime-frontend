# DrugTime Frontend

- `mobile/`: Flutter App
- `admin/`: Next.js Dashboard

## Landing page theo prototype

`admin/src/app/page.js` dựng landing page DrugTime theo `docs/prototype.html` và `docs/prototype.png`: responsive cho mobile/desktop, giới thiệu tính năng, quy trình 3 bước, nguyên tắc an toàn y khoa, FAQ accordion và CTA tải ứng dụng. Mockup điện thoại có nút xác nhận liều để xem trạng thái đã uống; FAQ mở/đóng trực tiếp.

### Chạy nhanh

```bash
cd admin
npm install
npm run dev
```

Mở `http://localhost:3000`. Nội dung và giao diện nằm trong `src/app/page.js`, `src/app/globals.css`; metadata và khung HTML ở `src/app/layout.js`.
