#!/usr/bin/env python3
"""Mock DSM API server cho app HomeHub — mô phỏng NAS Synology DSM 7.

Chạy:  python3 mock_dsm.py            (nghe tại 127.0.0.1:15001, HTTP)
Dừng:  Ctrl+C (hoặc kill tiến trình).

Mục đích: Hoai chưa mua NAS thật nên app HomeHub gọi vào server giả này
để phát triển + test. Mọi API đều theo đúng DSM API Guide chính thức:
  - Khám phá API:  SYNO.API.Info (query.cgi / entry.cgi)
  - Đăng nhập:     SYNO.API.Auth login/logout (auth.cgi / entry.cgi)
  - Tệp:           SYNO.FileStation.List / Download / Upload
  - Hệ thống:      SYNO.Core.System info, SYNO.Storage.Volume list
Mã lỗi mô phỏng theo tài liệu Synology (400 sai mật khẩu, 403 cần OTP...).

Tài khoản test:
  - admin / homehub123        (đăng nhập thường)
  - admin2fa / homehub123     (bật 2FA: lần đầu trả 403, gửi lại kèm otp_code=123456)
  - tài khoản khác / sai pass  -> lỗi 400

CHỈ DÙNG ĐỂ TEST. Không có dữ liệu thật, không lưu mật khẩu, không chạy ngoài localhost.
"""
import json
import secrets
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 15001

USERS = {
    "admin": {"passwd": "homehub123", "otp": False},
    "admin2fa": {"passwd": "homehub123", "otp": True},
}
SESSIONS = {}  # sid -> {"account": str, "synotoken": str}


def ok(data):
    return {"success": True, "data": data}


def err(code):
    return {"success": False, "error": {"code": code}}


API_INFO = {
    "SYNO.API.Auth": {"maxVersion": 7, "minVersion": 1, "path": "auth.cgi"},
    "SYNO.API.Info": {"maxVersion": 1, "minVersion": 1, "path": "query.cgi"},
    "SYNO.FileStation.List": {"maxVersion": 2, "minVersion": 1, "path": "entry.cgi"},
    "SYNO.FileStation.Download": {"maxVersion": 2, "minVersion": 1, "path": "entry.cgi"},
    "SYNO.FileStation.Upload": {"maxVersion": 2, "minVersion": 1, "path": "entry.cgi"},
    "SYNO.Core.System": {"maxVersion": 3, "minVersion": 1, "path": "entry.cgi"},
    "SYNO.Storage.Volume": {"maxVersion": 1, "minVersion": 1, "path": "entry.cgi"},
}

# Cây thư mục giả (giống NAS nhà: ảnh, video, nhạc, tài liệu)
FAKE_TREE = {
    "/": [
        {"name": "photo", "path": "/photo", "isdir": True},
        {"name": "video", "path": "/video", "isdir": True},
        {"name": "music", "path": "/music", "isdir": True},
        {"name": "documents", "path": "/documents", "isdir": True},
        {"name": "README.txt", "path": "/README.txt", "isdir": False, "size": 128},
    ],
    "/photo": [
        {"name": "2026-11-24", "path": "/photo/2026-11-24", "isdir": True},
        {"name": "gia-dinh.jpg", "path": "/photo/gia-dinh.jpg", "isdir": False, "size": 2457600},
    ],
    "/photo/2026-11-24": [
        {"name": "be-mit.jpg", "path": "/photo/2026-11-24/be-mit.jpg", "isdir": False, "size": 1835008},
    ],
    "/video": [
        {"name": "sinh-nhat.mp4", "path": "/video/sinh-nhat.mp4", "isdir": False, "size": 52428800},
    ],
    "/music": [
        {"name": "thien-duong.mp3", "path": "/music/thien-duong.mp3", "isdir": False, "size": 4194304},
    ],
    "/documents": [
        {"name": "hop-dong.pdf", "path": "/documents/hop-dong.pdf", "isdir": False, "size": 262144},
    ],
}


def handle_auth(params):
    method = params.get("method", [""])[0]
    if method == "login":
        account = params.get("account", [""])[0]
        passwd = params.get("passwd", [""])[0]
        user = USERS.get(account)
        if not user or user["passwd"] != passwd:
            return err(400)  # sai tài khoản hoặc mật khẩu
        if user["otp"] and params.get("otp_code", [""])[0] != "123456":
            return err(403)  # cần mã OTP 6 số
        sid = "MOCK-" + secrets.token_hex(8)
        synotoken = secrets.token_hex(16)
        SESSIONS[sid] = {"account": account, "synotoken": synotoken}
        data = {"sid": sid, "synotoken": synotoken}
        if params.get("enable_device_token", [""])[0] == "true":
            data["device_token"] = "MOCK-DEV-" + secrets.token_hex(8)
        return ok(data)
    if method == "logout":
        sid = params.get("_sid", [""])[0]
        SESSIONS.pop(sid, None)
        return ok({})
    return err(105)


def handle_filestation(params):
    sid = params.get("_sid", [""])[0]
    if sid not in SESSIONS:
        return err(105)  # hết phiên đăng nhập
    method = params.get("method", [""])[0]
    if method == "list":
        folder = params.get("folder_path", ["/"])[0]
        files = FAKE_TREE.get(folder)
        if files is None:
            return err(408)  # không tìm thấy thư mục
        return ok({"files": files, "total": len(files), "offset": 0})
    if method == "download":
        return {"__download__": True}
    if method == "upload":
        return ok({"blSkip": False})
    return err(105)


def handle_system(params):
    sid = params.get("_sid", [""])[0]
    if sid not in SESSIONS:
        return err(105)
    return ok({
        "model": "DS124 (MOCK)",
        "serial": "MOCK1234567",
        "firmware_ver": "7.2.2-72806",
        "cpu": "Realtek RTD1619B",
        "ram_size": 1024,
        "uptime": 86400,
        "temperature": 38,
        "hostname": "HomeHub-MockNAS",
    })


def handle_storage(params):
    sid = params.get("_sid", [""])[0]
    if sid not in SESSIONS:
        return err(105)
    return ok({"volumes": [
        {"id": "volume_1", "size_total": 1000204886016, "size_free": 750153364224,
         "status": "normal", "desc": "Volume 1 (MOCK 1TB)"},
    ]})


DISPATCH = {
    "SYNO.API.Info": lambda p: ok(API_INFO),
    "SYNO.API.Auth": handle_auth,
    "SYNO.FileStation.List": handle_filestation,
    "SYNO.FileStation.Download": handle_filestation,
    "SYNO.FileStation.Upload": handle_filestation,
    "SYNO.Core.System": handle_system,
    "SYNO.Storage.Volume": handle_storage,
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # log gọn vào stdout
        print(f"[{self.command}] {self.path}")

    def _send_json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle(self, params):
        api = params.get("api", [""])[0]
        fn = DISPATCH.get(api)
        if not fn:
            return self._send_json(err(105))
        result = fn(params)
        if isinstance(result, dict) and result.get("__download__"):
            body = b"Day la file gia lap tu Mock DSM (HomeHub test).\n"
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._send_json(result)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        self._handle(params)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b""
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        try:
            body = urllib.parse.parse_qs(raw.decode())
            params.update(body)
        except Exception:
            pass
        self._handle(params)


if __name__ == "__main__":
    print(f"Mock DSM dang chay: http://{HOST}:{PORT}/webapi/entry.cgi")
    print("Tai khoan test: admin / homehub123   (2FA: admin2fa / homehub123 + otp 123456)")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
