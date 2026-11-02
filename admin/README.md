# DrugTime Admin

Ứng dụng Next.js dùng Backend API thật; không có chế độ dữ liệu mẫu.

## Chạy local

Tạo `.env.local` trong thư mục `admin`:

```dotenv
DRUGTIME_API_BASE_URL=https://<your-service>.onrender.com
```

Không thêm `/docs`, `/health/live` hoặc `/admin` vào URL gốc. Không dùng tiền tố NEXT_PUBLIC_ cho biến này. Khởi động lại `npm run dev` sau khi đổi cấu hình.

Trình duyệt gọi `/api/session/medications`, `/api/session/drug-interactions`, `/api/session/drug-food-interactions`, `/api/session/active-ingredients`, `/api/session/catalog-sync-runs`. Next.js đọc cookie httpOnly và gửi token tới backend; browser không nhận token hoặc truy cập Supabase trực tiếp.

## Kiểm tra

```bash
npm run test:unit
npx --no-install tsc --noEmit
npm run lint
npm run build
```

Unit tests dùng TypeScript và Node test runner, không thêm dependency. `.test-build` là output tạm. Build dùng next/font/google nên cần kết nối tới dịch vụ font. Kiểm thử tích hợp Next/backend/database thật thuộc `tests/e2e/admin_live_api` của superproject ở stage test; unit tests không thay thế nó.

## Hành vi dữ liệu

- Thuốc: phân trang/tìm theo tên; thêm/sửa/xóa mềm qua API. Không có bước duyệt/hoàn tác xóa. Source/source_ref đi cùng nhau; đây không mặc định là số đăng ký thuốc.
- Tương tác: chọn một loại trước khi quản lý; chọn hoạt chất từ danh mục thật. Cặp hoạt chất không đổi khi sửa. Quy tắc có version, phản hồi 409 cần đối chiếu bản mới trước khi thử lại.
- Thuốc chưa có version chống ghi đè; PATCH chỉ gửi trường thay đổi. POST tạo thuốc chưa có idempotency: nếu mất response, tải lại danh sách kiểm tra trước khi gửi lại.
- Không có số liệu thì hiển thị rỗng/lỗi/chưa có số liệu, không tự thay bằng 0 hoặc fixture. Tổng lấy từ `total` của API; xuất dữ liệu chỉ xuất trang hiện tại.
- Tổng quan và nhật ký dùng lịch sử sync đã ghi, không phải trạng thái realtime của mọi Worker. Giờ hiển thị Asia/Ho_Chi_Minh. Thao tác chạy quét/restart và đối soát OCR chưa khả dụng.
- Sau mutation đã được xác nhận, lỗi tải lại danh sách không có nghĩa thao tác lưu thất bại. Không gửi lại POST chỉ để làm mới bảng.

## Xác minh kết nối Render

Mở `/health/live` của backend để kiểm tra tiến trình. Đăng nhập và mở danh mục trong Admin; Network có GET `/api/session/medications`, Render có GET `/admin/medications`. Không ghi bản thử vào dữ liệu đang dùng chỉ để smoke test; kiểm CRUD trên môi trường test được phép và tải lại bằng request mới để chứng minh lưu bền vững.

Không đưa password, cookie, token hoặc Firebase credentials vào screenshot/log. Logout xóa cookie phía Admin; cơ chế thu hồi phiên backend giữ nguyên hiện trạng.
