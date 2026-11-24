// HomeHub — DSM API client (Flutter/Dart).
// Gọi đúng DSM API Guide chính thức của Synology (DSM 7):
//   SYNO.API.Info  -> khám phá API
//   SYNO.API.Auth  -> login/logout (sid + SynoToken, hỗ trợ OTP 2FA, device_token)
//   SYNO.FileStation.List / Download / Upload
//   SYNO.Core.System, SYNO.Storage.Volume
// Mọi gọi đều qua entry.cgi/auth.cgi, kèm _sid sau khi đăng nhập.
// Test với mock DSM: baseUrl = 'http://127.0.0.1:15001' (xem ../mock-dsm/).
// NAS thật: baseUrl = 'https://<dia-chi-nas>:5001'.
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lỗi DSM trả về (mã theo tài liệu Synology).
class DsmException implements Exception {
  final int code;
  final String message;
  DsmException(this.code, this.message);
  @override
  String toString() => 'DSM lỗi $code: $message';
}

/// Tài khoản bật 2FA: login lần đầu trả 403, cần gửi lại kèm mã OTP.
class OtpRequiredException extends DsmException {
  OtpRequiredException() : super(403, 'Tài khoản bật 2FA, cần mã OTP 6 số');
}

class DsmFile {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  DsmFile({required this.name, required this.path, required this.isDir, this.size = 0});
  factory DsmFile.fromJson(Map<String, dynamic> j) => DsmFile(
        name: j['name'] as String? ?? '',
        path: j['path'] as String? ?? '',
        isDir: j['isdir'] as bool? ?? false,
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

class DsmSystemInfo {
  final String model;
  final String firmwareVer;
  final String cpu;
  final int ramSizeMb;
  final int uptimeSec;
  final int temperatureC;
  DsmSystemInfo({
    required this.model,
    required this.firmwareVer,
    required this.cpu,
    required this.ramSizeMb,
    required this.uptimeSec,
    required this.temperatureC,
  });
  factory DsmSystemInfo.fromJson(Map<String, dynamic> j) => DsmSystemInfo(
        model: j['model'] as String? ?? '',
        firmwareVer: j['firmware_ver'] as String? ?? '',
        cpu: j['cpu'] as String? ?? '',
        ramSizeMb: (j['ram_size'] as num?)?.toInt() ?? 0,
        uptimeSec: (j['uptime'] as num?)?.toInt() ?? 0,
        temperatureC: (j['temperature'] as num?)?.toInt() ?? 0,
      );
}

class DsmVolume {
  final String id;
  final int sizeTotal;
  final int sizeFree;
  final String status;
  DsmVolume({required this.id, required this.sizeTotal, required this.sizeFree, required this.status});
  factory DsmVolume.fromJson(Map<String, dynamic> j) => DsmVolume(
        id: j['id'] as String? ?? '',
        sizeTotal: (j['size_total'] as num?)?.toInt() ?? 0,
        sizeFree: (j['size_free'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

class DsmApi {
  final String baseUrl; // VD: http://127.0.0.1:15001 (mock) hoặc https://nas:5001
  final http.Client _client;
  String? _sid;
  String? _synoToken;

  DsmApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  bool get isLoggedIn => _sid != null;

  Uri _entry(Map<String, String> q) =>
      Uri.parse('$baseUrl/webapi/entry.cgi').replace(queryParameters: q);
  Uri _auth(Map<String, String> q) =>
      Uri.parse('$baseUrl/webapi/auth.cgi').replace(queryParameters: q);

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      final code = (body['error']?['code'] as num?)?.toInt() ?? 100;
      throw DsmException(code, _errorText(code));
    }
    return body['data'] as Map<String, dynamic>;
  }

  static String _errorText(int code) => switch (code) {
        400 => 'Sai tài khoản hoặc mật khẩu',
        401 => 'Tài khoản đã bị vô hiệu',
        402 => 'Tài khoản bị từ chối đăng nhập',
        403 => 'Cần mã OTP (2FA)',
        404 => 'Mã OTP không đúng',
        105 => 'Phiên đăng nhập đã hết hạn',
        408 => 'Không tìm thấy thư mục',
        _ => 'Lỗi không xác định',
      };

  /// Bước 1: hỏi NAS hỗ trợ API nào (không cần đăng nhập).
  Future<Map<String, dynamic>> getApiInfo() async {
    final res = await _client.get(_entry({
      'api': 'SYNO.API.Info',
      'method': 'query',
      'version': '1',
    }));
    return _decode(res);
  }

  /// Bước 2: đăng nhập. Trả về sid; nếu tài khoản bật 2FA mà chưa có
  /// otpCode thì ném OtpRequiredException để UI hỏi mã OTP rồi gọi lại.
  Future<void> login(String account, String passwd, {String? otpCode}) async {
    final q = <String, String>{
      'api': 'SYNO.API.Auth',
      'method': 'login',
      'version': '6',
      'account': account,
      'passwd': passwd,
      'format': 'sid',
      'enable_syno_token': 'true',
      'enable_device_token': 'true',
    };
    if (otpCode != null) q['otp_code'] = otpCode;
    http.Response res;
    try {
      res = await _client.get(_auth(q));
    } on DsmException {
      rethrow;
    }
    Map<String, dynamic> data;
    try {
      data = _decode(res);
    } on DsmException catch (e) {
      if (e.code == 403) throw OtpRequiredException();
      rethrow;
    }
    _sid = data['sid'] as String?;
    _synoToken = data['synotoken'] as String?;
  }

  Future<void> logout() async {
    if (_sid == null) return;
    try {
      await _client.get(_auth({
        'api': 'SYNO.API.Auth',
        'method': 'logout',
        'version': '6',
        'session': 'FileStation',
        '_sid': _sid!,
      }));
    } finally {
      _sid = null;
      _synoToken = null;
    }
  }

  Map<String, String> get _headers =>
      _synoToken == null ? {} : {'X-SYNO-TOKEN': _synoToken!};

  Map<String, String> _authed(Map<String, String> q) {
    if (_sid == null) throw DsmException(105, 'Chưa đăng nhập');
    return {...q, '_sid': _sid!};
  }

  Future<List<DsmFile>> listFiles(String folderPath) async {
    final res = await _client.get(_entry(_authed({
      'api': 'SYNO.FileStation.List',
      'method': 'list',
      'version': '2',
      'folder_path': folderPath,
    })), headers: _headers);
    final data = _decode(res);
    final files = (data['files'] as List?) ?? [];
    return files.map((f) => DsmFile.fromJson(f as Map<String, dynamic>)).toList();
  }

  Future<DsmSystemInfo> getSystemInfo() async {
    final res = await _client.get(_entry(_authed({
      'api': 'SYNO.Core.System',
      'method': 'info',
      'version': '3',
    })), headers: _headers);
    return DsmSystemInfo.fromJson(_decode(res));
  }

  Future<List<DsmVolume>> getVolumes() async {
    final res = await _client.get(_entry(_authed({
      'api': 'SYNO.Storage.Volume',
      'method': 'list',
      'version': '1',
    })), headers: _headers);
    final data = _decode(res);
    final vols = (data['volumes'] as List?) ?? [];
    return vols.map((v) => DsmVolume.fromJson(v as Map<String, dynamic>)).toList();
  }

  void dispose() => _client.close();
}
