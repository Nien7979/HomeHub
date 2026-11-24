# HomeHub — App quản lý máy chủ tại nhà

App Flutter quản lý mọi máy chủ tại nhà trong một app: **Synology NAS (DSM API)
trước, rồi TrueNAS / Linux / Windows sau.** Một code chạy iOS + Android.

## Có gì trong repo này

| Thư mục | Nội dung |
|---|---|
| `project/` | App Flutter HomeHub (v0.1): đăng nhập DSM (kèm OTP 2FA), dashboard, duyệt tệp |
| `mock-dsm/` | NAS giả (Python stdlib) mô phỏng DSM API — để build + test khi chưa có NAS thật |
| `app/` | Bản lưu mã nguồn `lib/` + test (trùng với `project/lib/`, để đọc nhanh) |
| `cai-flutter.sh` | Script cài Flutter SDK stable mới nhất trên Linux |

## Trạng thái (24/11/2026)

- v0.1: đăng nhập + dashboard + duyệt tệp, gọi được mock DSM.
- `flutter analyze` 0 lỗi; `flutter test` 3/3 pass; `flutter build web` thành công.
- Chưa chạy trên điện thoại thật (cần build APK/iOS; iOS cần máy Mac hoặc build cloud).
- Chưa làm: Docker, người dùng, truy cập từ xa, sao lưu ảnh.
- Kế hoạch đầy đủ: `ke-hoach-app-nas-native.md` (xem ghi chú dự án).

## Chạy thử với NAS giả

```bash
# 1. Chạy mock DSM (terminal khác)
python3 mock-dsm/mock_dsm.py   # nghe tại http://127.0.0.1:15001

# 2. Cài Flutter rồi chạy app
bash cai-flutter.sh
export PATH="$HOME/workspace/homehub/flutter-sdk/bin:$PATH"
cd project
flutter pub get
flutter run -d chrome   # chạy thử trên trình duyệt, gọi mock DSM
```

Tài khoản test: `admin` / `homehub123` (2FA: `admin2fa` / `homehub123` + mã OTP `123456`).

## Khi có NAS thật

Đổi địa chỉ trong app từ `http://127.0.0.1:15001` sang `https://<địa-chỉ-nas>:5001`.
Không sửa logic gọi API — client DSM viết đúng DSM API Guide chính thức của Synology.

## Bảo mật

- Mật khẩu NAS chỉ lưu bằng `flutter_secure_storage` (Keychain iOS / Keystore Android).
- NAS thật bắt buộc HTTPS + ghim chứng chỉ (chưa làm ở v0.1).
