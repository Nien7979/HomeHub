# Mock DSM — NAS giả để build app HomeHub

Hoai chưa mua NAS thật nên app HomeHub phát triển với server giả này.
Mô phỏng đúng DSM API Guide chính thức của Synology (DSM 7).

## Chạy

```bash
python3 mock_dsm.py
# Nghe tại http://127.0.0.1:15001/webapi/entry.cgi
```

## Tài khoản test

| Tài khoản | Mật khẩu | Ghi chú |
|---|---|---|
| admin | homehub123 | Đăng nhập thường |
| admin2fa | homehub123 | Bật 2FA: lần đầu trả lỗi 403, gửi lại kèm `otp_code=123456` |

## API đã mô phỏng

- `SYNO.API.Info` — liệt kê API + phiên bản
- `SYNO.API.Auth` — login (trả `sid` + `synotoken`, hỗ trợ `device_token`), logout
- `SYNO.FileStation.List` — duyệt cây thư mục giả (`/photo`, `/video`, `/music`, `/documents`)
- `SYNO.FileStation.Download` / `Upload` — tải file giả / nhận upload giả
- `SYNO.Core.System` — thông tin máy giả (DS124, DSM 7.2.2, CPU, RAM, nhiệt độ)
- `SYNO.Storage.Volume` — 1 volume giả 1TB

## Test nhanh

```bash
# 1. Khám phá API
curl 'http://127.0.0.1:15001/webapi/entry.cgi?api=SYNO.API.Info&method=query&version=1'
# 2. Đăng nhập (lấy sid)
curl 'http://127.0.0.1:15001/webapi/auth.cgi?api=SYNO.API.Auth&method=login&version=6&account=admin&passwd=homehub123&format=sid'
# 3. Liệt kê thư mục gốc (thay SID)
curl 'http://127.0.0.1:15001/webapi/entry.cgi?api=SYNO.FileStation.List&method=list&version=2&folder_path=/&_sid=SID'
# 4. Thông tin hệ thống
curl 'http://127.0.0.1:15001/webapi/entry.cgi?api=SYNO.Core.System&method=info&version=3&_sid=SID'
```

## Lưu ý

- Chỉ chạy trên localhost, không có dữ liệu thật, không lưu mật khẩu.
- Khi Hoai có NAS thật: đổi base URL trong app từ `http://127.0.0.1:15001` sang `https://<nas>:5001` là chạy, không sửa logic gọi API.
