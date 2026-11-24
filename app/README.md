# HomeHub — app quản lý máy chủ tại nhà (Flutter)

Tên app: HomeHub. Framework: Flutter (1 code chạy iOS + Android).
Định vị: quản lý nhiều loại máy chủ — Synology DSM trước, TrueNAS/Linux/Windows sau.

## Cấu trúc

- `lib/dsm_api.dart` — client gọi DSM API đúng tài liệu chính thức Synology
  (SYNO.API.Info / Auth / FileStation / Core.System / Storage.Volume).
- `lib/main.dart` — màn hình đăng nhập (kèm OTP 2FA), dashboard, duyệt tệp.
- `../mock-dsm/` — NAS giả để test khi chưa có NAS thật.
- `pubspec.yaml` — sẽ do `flutter create` sinh ra; cần thêm 2 package:
  `http` (gọi API) và `flutter_secure_storage` (lưu mật khẩu vào
  Keychain/Keystore, không lưu file thường).

## Chạy thử với NAS giả

```bash
# 1. Chạy mock DSM (terminal khác)
python3 ../mock-dsm/mock_dsm.py
# 2. Cài Flutter xong thì tạo project rồi chép code vào
export PATH="$HOME/workspace/homehub/flutter-sdk/bin:$PATH"
flutter create --org com.lenien.homehub --project-name homehub .
cp lib/dsm_api.dart lib/main.dart <project>/lib/   # (code đã viết sẵn ở đây)
flutter pub add http flutter_secure_storage
flutter analyze        # kiểm tra lỗi
flutter build web      # build thử (không cần Android SDK / máy Mac)
flutter run -d chrome  # chạy thử trên trình duyệt (gọi mock DSM)
```

Tài khoản test: admin / homehub123 (2FA: admin2fa / homehub123 + otp 123456).

## Khi có NAS thật

Đổi địa chỉ trong app từ `http://127.0.0.1:15001` sang `https://<nas>:5001`.
Không sửa logic gọi API.

## Trạng thái (24/11/2026, đã kiểm chứng)

- v0.1: đăng nhập (kèm OTP 2FA) + dashboard + duyệt tệp, gọi được mock DSM.
  `flutter analyze` 0 lỗi; `flutter test` 3/3 pass; `flutter build web` thành công.
  Flutter 3.50.1 stable. Ghi chú học Flutter: `~/workspace/knowledge/hoc-ai-agent/flutter-cho-homehub-phan-1.md`.
- Chưa làm: Docker, người dùng, truy cập từ xa, sao lưu ảnh (theo kế hoạch
  `~/workspace/knowledge/ke-hoach-app-nas-native.md`). Chưa chạy trên điện thoại
  thật (cần build APK/iOS; iOS cần máy Mac hoặc build cloud).
