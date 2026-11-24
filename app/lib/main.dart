// HomeHub — app quản lý máy chủ tại nhà (Flutter).
// v0.1: đăng nhập DSM + dashboard + duyệt tệp, gọi mock DSM ở
// http://127.0.0.1:15001. Đổi _kMockBaseUrl sang https://<nas>:5001 khi có NAS thật.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dsm_api.dart';

const String _kMockBaseUrl = 'http://127.0.0.1:15001';

void main() => runApp(const HomeHubApp());

class HomeHubApp extends StatelessWidget {
  const HomeHubApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeHub',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _baseCtrl = TextEditingController(text: _kMockBaseUrl);
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'homehub123');
  final _otpCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _needOtp = false;
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = DsmApi(_baseCtrl.text.trim());
    try {
      await api.login(_userCtrl.text.trim(), _passCtrl.text,
          otpCode: _needOtp ? _otpCtrl.text.trim() : null);
      // Lưu mật khẩu vào Keychain/Keystore, không lưu vào code hay file thường.
      await _storage.write(
          key: 'nas:${_baseCtrl.text.trim()}:passwd', value: _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen(api: api)));
    } on OtpRequiredException {
      setState(() => _needOtp = true);
    } on DsmException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'Không kết nối được tới máy chủ: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HomeHub — Đăng nhập NAS')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _baseCtrl,
                decoration: const InputDecoration(
                    labelText: 'Địa chỉ NAS (VD: https://nas-nha:5001)')),
            TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'Tài khoản DSM')),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            if (_needOtp)
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Mã OTP 6 số (tài khoản bật 2FA)'),
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: Text(_busy ? 'Đang đăng nhập...' : 'Đăng nhập'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bản test: dùng NAS giả trên máy ảo (admin / homehub123). '
              'Mật khẩu chỉ lưu trong Keychain/Keystore của máy.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final DsmApi api;
  const DashboardScreen({super.key, required this.api});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DsmSystemInfo? _info;
  List<DsmVolume> _volumes = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await widget.api.getSystemInfo();
      final vols = await widget.api.getVolumes();
      if (mounted) {
        setState(() {
          _info = info;
          _volumes = vols;
          _loading = false;
        });
      }
    } on DsmException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _gb(int bytes) => '${(bytes / 1073741824).toStringAsFixed(0)} GB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeHub — Tổng quan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Duyệt tệp',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FilesScreen(api: widget.api))),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await widget.api.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Model: ${_info!.model}',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('DSM: ${_info!.firmwareVer}'),
                      Text('CPU: ${_info!.cpu}'),
                      Text('RAM: ${_info!.ramSizeMb} MB'),
                      Text('Nhiệt độ: ${_info!.temperatureC}°C'),
                      Text(
                          'Uptime: ${(_info!.uptimeSec / 3600).toStringAsFixed(0)} giờ'),
                      const SizedBox(height: 16),
                      const Text('Ổ đĩa:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final v in _volumes)
                        ListTile(
                          leading: const Icon(Icons.storage),
                          title: Text(v.id),
                          subtitle: Text(
                              'Trống ${_gb(v.sizeFree)} / ${_gb(v.sizeTotal)} — ${v.status}'),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class FilesScreen extends StatefulWidget {
  final DsmApi api;
  const FilesScreen({super.key, required this.api});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _path = '/';
  List<DsmFile> _files = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(_path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.api.listFiles(path);
      if (mounted) {
        setState(() {
          _path = path;
          _files = files;
          _loading = false;
        });
      }
    } on DsmException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _parent(String p) {
    if (p == '/') return '/';
    final idx = p.lastIndexOf('/');
    return idx <= 0 ? '/' : p.substring(0, idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tệp: $_path'),
        leading: _path == '/'
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _load(_parent(_path)),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    return ListTile(
                      leading: Icon(
                          f.isDir ? Icons.folder : Icons.insert_drive_file),
                      title: Text(f.name),
                      subtitle: f.isDir
                          ? null
                          : Text('${(f.size / 1048576).toStringAsFixed(1)} MB'),
                      onTap: f.isDir ? () => _load(f.path) : null,
                    );
                  },
                ),
    );
  }
}
