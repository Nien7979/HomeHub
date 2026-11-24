// Test client DSM của HomeHub bằng mock HTTP (không cần NAS thật).
// Chạy sau khi cài Flutter:  flutter test
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homehub/dsm_api.dart';

http.Client fakeClient() {
  return MockClient((req) async {
    final q = req.url.queryParameters;
    final api = q['api'];
    if (api == 'SYNO.API.Info') {
      return http.Response(
          jsonEncode({'success': true, 'data': {'SYNO.API.Auth': {}}}), 200);
    }
    if (api == 'SYNO.API.Auth' && q['method'] == 'login') {
      if (q['account'] == 'admin' && q['passwd'] == 'homehub123') {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': {'sid': 'TEST-SID', 'synotoken': 'TEST-TOKEN'}
            }),
            200);
      }
      if (q['account'] == 'admin2fa' && q['otp_code'] == null) {
        return http.Response(
            jsonEncode({'success': false, 'error': {'code': 403}}), 200);
      }
      return http.Response(
          jsonEncode({'success': false, 'error': {'code': 400}}), 200);
    }
    if (api == 'SYNO.FileStation.List') {
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'files': [
                {'name': 'photo', 'path': '/photo', 'isdir': true},
                {'name': 'a.jpg', 'path': '/a.jpg', 'isdir': false, 'size': 100}
              ]
            }
          }),
          200);
    }
    if (api == 'SYNO.Core.System') {
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'model': 'DS124',
              'firmware_ver': '7.2.2',
              'cpu': 'RTD1619B',
              'ram_size': 1024,
              'uptime': 3600,
              'temperature': 38
            }
          }),
          200);
    }
    return http.Response(jsonEncode({'success': false, 'error': {'code': 105}}), 200);
  });
}

void main() {
  test('login đúng trả sid, list file và system info đọc được', () async {
    final api = DsmApi('http://mock', client: fakeClient());
    await api.login('admin', 'homehub123');
    expect(api.isLoggedIn, true);
    final files = await api.listFiles('/');
    expect(files.length, 2);
    expect(files.first.name, 'photo');
    final info = await api.getSystemInfo();
    expect(info.model, 'DS124');
    expect(info.temperatureC, 38);
  });

  test('sai mật khẩu báo lỗi 400', () async {
    final api = DsmApi('http://mock', client: fakeClient());
    expect(
        () => api.login('admin', 'sai'),
        throwsA(isA<DsmException>().having((e) => e.code, 'code', 400)));
  });

  test('tài khoản 2FA không có OTP thì báo cần OTP', () async {
    final api = DsmApi('http://mock', client: fakeClient());
    expect(() => api.login('admin2fa', 'homehub123'),
        throwsA(isA<OtpRequiredException>()));
  });
}
