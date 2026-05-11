import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/music_track.dart';
import '../../services/emby_service.dart';
import '../../services/jellyfin_service.dart';
import '../../services/navidrome_service.dart';
import '../../services/webdav_music_service.dart';

Future<void> showWebDavDialog({
  required BuildContext context,
  required ValueChanged<List<MusicTrack>> onTracksLoaded,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WebDavDialog(onTracksLoaded: onTracksLoaded),
  );
}

Future<void> showEmbyDialog({
  required BuildContext context,
  required ValueChanged<List<MusicTrack>> onTracksLoaded,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EmbyDialog(onTracksLoaded: onTracksLoaded),
  );
}

Future<void> showJellyfinDialog({
  required BuildContext context,
  required ValueChanged<List<MusicTrack>> onTracksLoaded,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _JellyfinDialog(onTracksLoaded: onTracksLoaded),
  );
}

Future<void> showNavidromeDialog({
  required BuildContext context,
  required ValueChanged<List<MusicTrack>> onTracksLoaded,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _NavidromeDialog(onTracksLoaded: onTracksLoaded),
  );
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key, required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 120),
      children: [
        Text(
          'source.title'.tr,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'source.subtitle'.tr,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 20),
        SourcesSection(onTracksLoaded: onTracksLoaded),
      ],
    );
  }
}

class SourcesSection extends StatelessWidget {
  const SourcesSection({super.key, required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SourceActionCard(
          icon: Icons.storage_rounded,
          title: 'WebDAV / NAS',
          subtitle: 'source.webdavSubtitle'.tr,
          onTap: () => showWebDavDialog(
            context: context,
            onTracksLoaded: onTracksLoaded,
          ),
        ),
        SourceActionCard(
          icon: Icons.live_tv_rounded,
          title: 'Emby',
          subtitle: 'source.embySubtitle'.tr,
          onTap: () => showEmbyDialog(
            context: context,
            onTracksLoaded: onTracksLoaded,
          ),
        ),
        SourceActionCard(
          icon: Icons.cast_connected_rounded,
          title: 'Jellyfin',
          subtitle: 'source.jellyfinSubtitle'.tr,
          onTap: () => showJellyfinDialog(
            context: context,
            onTracksLoaded: onTracksLoaded,
          ),
        ),
        SourceActionCard(
          icon: Icons.cloud_queue_rounded,
          title: 'Navidrome',
          subtitle: 'source.navidromeSubtitle'.tr,
          onTap: () => showNavidromeDialog(
            context: context,
            onTracksLoaded: onTracksLoaded,
          ),
        ),
      ],
    );
  }
}

class SourceActionCard extends StatelessWidget {
  const SourceActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _HostPortFields extends StatelessWidget {
  const _HostPortFields({
    required this.hostController,
    required this.portController,
    required this.enabled,
    required this.hostLabel,
    required this.hostHint,
    required this.portHint,
  });

  final TextEditingController hostController;
  final TextEditingController portController;
  final bool enabled;
  final String hostLabel;
  final String hostHint;
  final String portHint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: hostController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: hostLabel,
              hintText: hostHint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            controller: portController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'common.port'.tr,
              hintText: portHint,
            ),
          ),
        ),
      ],
    );
  }
}

String _normalizedPortValue(TextEditingController portController, String defaultPort) {
  final value = portController.text.trim();
  return value.isEmpty ? defaultPort : value;
}

_ServerParts _parseServerInput(
  String value, {
  required String defaultHost,
  required String defaultPort,
}) {
  final raw = value.trim();
  if (raw.isEmpty) return _ServerParts(defaultHost, defaultPort);

  final hasScheme = raw.startsWith('http://') || raw.startsWith('https://');
  final rawForParse = hasScheme ? raw : 'http://$raw';
  final uri = Uri.tryParse(rawForParse);
  if (uri == null || uri.host.isEmpty) {
    return _ServerParts(raw, defaultPort);
  }

  final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).join('/');
  final path = segments.isEmpty ? '' : '/$segments';
  final prefix = hasScheme ? '${uri.scheme}://' : '';
  final hostText = '$prefix${uri.host}$path';
  return _ServerParts(
    hostText.isEmpty ? defaultHost : hostText,
    uri.hasPort ? uri.port.toString() : defaultPort,
  );
}

String _composeServerUrlFromControllers({
  required TextEditingController hostController,
  required TextEditingController portController,
  required String defaultPort,
}) {
  var rawHost = hostController.text.trim();
  if (rawHost.isEmpty) return '';

  var portValue = _normalizedPortValue(portController, defaultPort);
  final hasScheme = rawHost.startsWith('http://') || rawHost.startsWith('https://');

  if (hasScheme || rawHost.contains('/')) {
    final rawForParse = hasScheme ? rawHost : 'http://$rawHost';
    final uri = Uri.tryParse(rawForParse);
    if (uri != null && uri.host.isNotEmpty) {
      if (uri.hasPort &&
          (portController.text.trim().isEmpty ||
              portController.text.trim() == defaultPort)) {
        portController.text = uri.port.toString();
        portValue = uri.port.toString();
      }

      final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).join('/');
      final path = segments.isEmpty ? '' : '/$segments';
      final prefix = hasScheme ? '${uri.scheme}://' : '';
      final hostText = '$prefix${uri.host}$path';
      if (hostController.text.trim() != hostText) {
        hostController.text = hostText;
      }
      return '$prefix${uri.host}:$portValue$path';
    }

    if (hasScheme) return rawHost;
  }

  // 用户如果仍然在 IP 输入框里写了 “192.168.1.2:8096”，自动拆分，避免重复端口。
  final match = RegExp(r'^(.+):(\d+)$').firstMatch(rawHost);
  if (match != null && !rawHost.contains(']')) {
    rawHost = match.group(1) ?? rawHost;
    final parsedPort = match.group(2);
    if (parsedPort != null &&
        (portController.text.trim().isEmpty ||
            portController.text.trim() == defaultPort)) {
      portController.text = parsedPort;
      portValue = parsedPort;
    }
    if (hostController.text.trim() != rawHost) {
      hostController.text = rawHost;
    }
  }

  return '$rawHost:$portValue';
}

class _WebDavDialog extends StatefulWidget {
  const _WebDavDialog({required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  State<_WebDavDialog> createState() => _WebDavDialogState();
}

class _WebDavDialogState extends State<_WebDavDialog> {
  static const _urlKey = 'webdav.base_url';
  static const _userKey = 'webdav.username';
  static const _passKey = 'webdav.password';
  static const _pathKey = 'webdav.path';
  static const _recursiveKey = 'webdav.recursive';

  final url = TextEditingController(text: 'http://192.168.1.10:5244/dav');
  final user = TextEditingController();
  final pass = TextEditingController();
  final path = TextEditingController(text: '/');
  bool loading = false;
  bool loadingCache = true;
  bool recursive = true;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    url.text = prefs.getString(_urlKey) ?? url.text;
    user.text = prefs.getString(_userKey) ?? '';
    pass.text = prefs.getString(_passKey) ?? '';
    path.text = prefs.getString(_pathKey) ?? '/';
    recursive = prefs.getBool(_recursiveKey) ?? true;
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.text.trim());
    await prefs.setString(_userKey, user.text.trim());
    await prefs.setString(_passKey, pass.text);
    await prefs.setString(_pathKey, path.text.trim().isEmpty ? '/' : path.text.trim());
    await prefs.setBool(_recursiveKey, recursive);
  }

  @override
  void dispose() {
    url.dispose();
    user.dispose();
    pass.dispose();
    path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('source.webdav.connect'.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: url, enabled: !loading && !loadingCache, decoration: InputDecoration(labelText: 'source.webdav.address'.tr)),
            TextField(controller: user, enabled: !loading && !loadingCache, decoration: InputDecoration(labelText: 'source.webdav.account'.tr)),
            TextField(controller: pass, enabled: !loading && !loadingCache, decoration: InputDecoration(labelText: 'common.password'.tr), obscureText: true),
            TextField(controller: path, enabled: !loading && !loadingCache, decoration: InputDecoration(labelText: 'source.webdav.path'.tr)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: recursive,
              onChanged: loading || loadingCache ? null : (value) => setState(() => recursive = value),
              title: Text('source.webdav.recursive'.tr),
              subtitle: Text('source.webdav.recursiveDesc'.tr),
            ),
            if (loadingCache) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Get.back(), child: Text('common.cancel'.tr)),
        FilledButton(
          onPressed: loading || loadingCache
              ? null
              : () async {
                  setState(() => loading = true);
                  try {
                    final tracks = await WebDavMusicService().listAudio(
                      baseUrl: url.text.trim(),
                      username: user.text.trim(),
                      password: pass.text,
                      path: path.text.trim().isEmpty ? '/' : path.text.trim(),
                      recursive: recursive,
                    );
                    await _saveCache();
                    widget.onTracksLoaded(tracks);
                    if (!context.mounted) return;
                    Get.back();
                    Get.snackbar(
                      'source.webdav.success'.tr,
                      'source.webdav.successMessage'.trParams({'count': '${tracks.length}', 'recursive': recursive ? '' : 'source.webdav.nonRecursive'.tr}),
                      snackPosition: SnackPosition.TOP,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('source.webdav.failed'.tr),
                        content: Text(e.toString().replaceFirst('Exception: ', '')),
                        actions: [
                          TextButton(onPressed: () => Get.back(), child: Text('common.ok'.tr)),
                        ],
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => loading = false);
                  }
                },
          child: Text(loading ? 'common.loading'.tr : 'common.load'.tr),
        ),
      ],
    );
  }
}

class _EmbyDialog extends StatefulWidget {
  const _EmbyDialog({required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  State<_EmbyDialog> createState() => _EmbyDialogState();
}

class _EmbyDialogState extends State<_EmbyDialog> {
  static const _serverKey = 'emby.server_url'; // 旧版本兼容
  static const _hostKey = 'emby.host';
  static const _portKey = 'emby.port';
  static const _apiKeyKey = 'emby.api_key';
  static const _userKey = 'emby.username';
  static const _passKey = 'emby.password';

  final host = TextEditingController(text: '192.168.137.177');
  final port = TextEditingController(text: '8096');
  final apiKey = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool loadingCache = true;
  bool hideApiKey = true;
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHost = prefs.getString(_hostKey);
    final cachedPort = prefs.getString(_portKey);

    if (cachedHost != null && cachedHost.trim().isNotEmpty) {
      host.text = cachedHost;
      port.text = (cachedPort == null || cachedPort.trim().isEmpty) ? '8096' : cachedPort;
    } else {
      final legacy = prefs.getString(_serverKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        final parsed = _parseServerInput(
          legacy,
          defaultHost: '192.168.137.177',
          defaultPort: '8096',
        );
        host.text = parsed.host;
        port.text = parsed.port;
      }
    }

    apiKey.text = prefs.getString(_apiKeyKey) ?? '';
    username.text = prefs.getString(_userKey) ?? '';
    password.text = prefs.getString(_passKey) ?? '';
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = _composeServerUrl();
    await prefs.setString(_hostKey, host.text.trim());
    await prefs.setString(_portKey, _normalizedPort());
    await prefs.setString(_serverKey, serverUrl);
    await prefs.setString(_apiKeyKey, apiKey.text.trim());
    await prefs.setString(_userKey, username.text.trim());
    await prefs.setString(_passKey, password.text);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    apiKey.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  String _normalizedPort() => _normalizedPortValue(port, '8096');

  String _composeServerUrl() => _composeServerUrlFromControllers(
        hostController: host,
        portController: port,
        defaultPort: '8096',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return AlertDialog(
      title: Text('source.emby.connect'.tr),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * (isLandscape ? 0.72 : 0.78)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'source.emby.desc'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _HostPortFields(
                hostController: host,
                portController: port,
                enabled: !loadingCache && !loading,
                hostLabel: 'source.emby.host'.tr,
                hostHint: 'source.emby.example'.tr,
                portHint: 'source.emby.port'.tr,
              ),
              TextField(
                controller: apiKey,
                enabled: !loadingCache && !loading,
                obscureText: hideApiKey,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'source.apiKeyOptional'.tr,
                  hintText: 'source.apiKeyHint'.tr,
                  suffixIcon: IconButton(
                    tooltip: hideApiKey ? 'common.show'.tr : 'common.hide'.tr,
                    icon: Icon(hideApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hideApiKey = !hideApiKey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'source.noApiKeyLogin'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextField(
                controller: username,
                enabled: !loadingCache && !loading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'source.usernameWithApiHint'.tr,
                ),
              ),
              TextField(
                controller: password,
                enabled: !loadingCache && !loading,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'source.passwordWithApiHint'.tr,
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'common.show'.tr : 'common.hide'.tr,
                    icon: Icon(hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
              ),
              if (loadingCache || loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Get.back(), child: Text('common.cancel'.tr)),
        FilledButton(
          onPressed: loading || loadingCache ? null : _connect,
          child: Text(loading ? 'common.loading'.tr : 'common.connectAndScan'.tr),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final tracks = await EmbyService(
        serverUrl: _composeServerUrl(),
        apiKey: apiKey.text.trim(),
        username: username.text.trim(),
        password: password.text,
      ).listAudio();

      await _saveCache();
      widget.onTracksLoaded(tracks);

      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'source.emby.success'.tr,
        'source.successCount'.trParams({'count': '${tracks.length}'}),
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('source.emby.failed'.tr),
          content: Text(_formatEmbyError(e)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('common.ok'.tr)),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatEmbyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');

    if (message.contains('连接超时')) {
      return 'source.emby.timeout'.tr;
    }
    return message;
  }
}

class _ServerParts {
  const _ServerParts(this.host, this.port);
  final String host;
  final String port;
}

class _JellyfinDialog extends StatefulWidget {
  const _JellyfinDialog({required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  State<_JellyfinDialog> createState() => _JellyfinDialogState();
}

class _JellyfinDialogState extends State<_JellyfinDialog> {
  static const _serverKey = 'jellyfin.server_url'; // 旧版本兼容
  static const _hostKey = 'jellyfin.host';
  static const _portKey = 'jellyfin.port';
  static const _apiKeyKey = 'jellyfin.api_key';
  static const _scanLyricsKey = 'jellyfin.scan_lyrics';
  static const _userKey = 'jellyfin.username';
  static const _passKey = 'jellyfin.password';

  final host = TextEditingController(text: '192.168.1.20');
  final port = TextEditingController(text: '8888');
  final apiKey = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool loadingCache = true;
  bool hideApiKey = true;
  bool hidePassword = true;
  bool scanLyrics = false;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHost = prefs.getString(_hostKey);
    final cachedPort = prefs.getString(_portKey);

    if (cachedHost != null && cachedHost.trim().isNotEmpty) {
      host.text = cachedHost;
      port.text = (cachedPort == null || cachedPort.trim().isEmpty) ? '8888' : cachedPort;
    } else {
      final legacy = prefs.getString(_serverKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        final parsed = _parseServerInput(
          legacy,
          defaultHost: '192.168.1.20',
          defaultPort: '8888',
        );
        host.text = parsed.host;
        port.text = parsed.port;
      }
    }

    apiKey.text = prefs.getString(_apiKeyKey) ?? '';
    username.text = prefs.getString(_userKey) ?? '';
    password.text = prefs.getString(_passKey) ?? '';
    scanLyrics = prefs.getBool(_scanLyricsKey) ?? false;
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = _composeServerUrl();
    await prefs.setString(_hostKey, host.text.trim());
    await prefs.setString(_portKey, _normalizedPort());
    await prefs.setString(_serverKey, serverUrl);
    await prefs.setString(_apiKeyKey, apiKey.text.trim());
    await prefs.setBool(_scanLyricsKey, scanLyrics);
    await prefs.setString(_userKey, username.text.trim());
    await prefs.setString(_passKey, password.text);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    apiKey.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  String _normalizedPort() => _normalizedPortValue(port, '8888');

  String _composeServerUrl() => _composeServerUrlFromControllers(
        hostController: host,
        portController: port,
        defaultPort: '8888',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return AlertDialog(
      title: Text('source.jellyfin.connect'.tr),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * (isLandscape ? 0.72 : 0.78)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'source.jellyfin.desc'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _HostPortFields(
                hostController: host,
                portController: port,
                enabled: !loadingCache && !loading,
                hostLabel: 'source.jellyfin.host'.tr,
                hostHint: 'source.jellyfin.example'.tr,
                portHint: 'source.jellyfin.port'.tr,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: scanLyrics,
                onChanged: loadingCache || loading
                    ? null
                    : (value) => setState(() => scanLyrics = value),
                title: Text('source.jellyfin.scanLyrics'.tr),
                subtitle: Text('source.jellyfin.scanLyricsDesc'.tr),
              ),
              TextField(
                controller: apiKey,
                enabled: !loadingCache && !loading,
                obscureText: hideApiKey,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'source.apiKeyOptional'.tr,
                  hintText: 'source.apiKeyHint'.tr,
                  suffixIcon: IconButton(
                    tooltip: hideApiKey ? 'common.show'.tr : 'common.hide'.tr,
                    icon: Icon(hideApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hideApiKey = !hideApiKey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'source.noApiKeyLogin'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextField(
                controller: username,
                enabled: !loadingCache && !loading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'source.usernameWithApiHint'.tr,
                ),
              ),
              TextField(
                controller: password,
                enabled: !loadingCache && !loading,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'source.passwordWithApiHint'.tr,
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'common.show'.tr : 'common.hide'.tr,
                    icon: Icon(hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
              ),
              if (loadingCache || loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Get.back(), child: Text('common.cancel'.tr)),
        FilledButton(
          onPressed: loading || loadingCache ? null : _connect,
          child: Text(loading ? 'common.loading'.tr : 'common.connectAndScan'.tr),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final service = JellyfinService(
        serverUrl: _composeServerUrl(),
        apiKey: apiKey.text.trim(),
        username: username.text.trim(),
        password: password.text,
        prefetchLyrics: scanLyrics,
      );

      await service.testConnection();
      final tracks = await service.listAudio();

      await _saveCache();
      widget.onTracksLoaded(tracks);

      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'source.jellyfin.success'.tr,
        'source.successCount'.trParams({'count': '${tracks.length}'}),
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('source.jellyfin.failed'.tr),
          content: Text(_formatJellyfinError(e)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('common.ok'.tr)),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatJellyfinError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');

    if (message.contains('localhost') || message.contains('127.0.0.1')) {
      return 'source.jellyfin.localhost'.tr;
    }
    if (message.contains('连接超时')) {
      return 'source.jellyfin.timeout'.tr;
    }
    return message;
  }
}



class _NavidromeDialog extends StatefulWidget {
  const _NavidromeDialog({required this.onTracksLoaded});
  final ValueChanged<List<MusicTrack>> onTracksLoaded;

  @override
  State<_NavidromeDialog> createState() => _NavidromeDialogState();
}

class _NavidromeDialogState extends State<_NavidromeDialog> {
  static const _serverKey = 'navidrome.server_url'; // 旧版本兼容
  static const _hostKey = 'navidrome.host';
  static const _portKey = 'navidrome.port';
  static const _userKey = 'navidrome.username';
  static const _passKey = 'navidrome.password';

  final host = TextEditingController(text: '192.168.1.20');
  final port = TextEditingController(text: '4533');
  final username = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool loadingCache = true;
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHost = prefs.getString(_hostKey);
    final cachedPort = prefs.getString(_portKey);

    if (cachedHost != null && cachedHost.trim().isNotEmpty) {
      host.text = cachedHost;
      port.text = (cachedPort == null || cachedPort.trim().isEmpty) ? '4533' : cachedPort;
    } else {
      final legacy = prefs.getString(_serverKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        final parsed = _parseServerInput(
          legacy,
          defaultHost: '192.168.1.20',
          defaultPort: '4533',
        );
        host.text = parsed.host;
        port.text = parsed.port;
      }
    }

    username.text = prefs.getString(_userKey) ?? '';
    password.text = prefs.getString(_passKey) ?? '';
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = _composeServerUrl();
    await prefs.setString(_hostKey, host.text.trim());
    await prefs.setString(_portKey, _normalizedPort());
    await prefs.setString(_serverKey, serverUrl);
    await prefs.setString(_userKey, username.text.trim());
    await prefs.setString(_passKey, password.text);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  String _normalizedPort() => _normalizedPortValue(port, '4533');

  String _composeServerUrl() => _composeServerUrlFromControllers(
        hostController: host,
        portController: port,
        defaultPort: '4533',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return AlertDialog(
      title: Text('source.navidrome.connect'.tr),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * (isLandscape ? 0.72 : 0.78)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'source.navidrome.desc'.tr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _HostPortFields(
                hostController: host,
                portController: port,
                enabled: !loadingCache && !loading,
                hostLabel: 'source.navidrome.host'.tr,
                hostHint: 'source.navidrome.example'.tr,
                portHint: 'source.navidrome.port'.tr,
              ),
              TextField(
                controller: username,
                enabled: !loadingCache && !loading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'common.username'.tr),
              ),
              TextField(
                controller: password,
                enabled: !loadingCache && !loading,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'common.password'.tr,
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'common.show'.tr : 'common.hide'.tr,
                    icon: Icon(hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
              ),
              if (loadingCache || loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Get.back(), child: Text('common.cancel'.tr)),
        FilledButton(
          onPressed: loading || loadingCache ? null : _connect,
          child: Text(loading ? 'common.loading'.tr : 'common.connectAndScan'.tr),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final tracks = await NavidromeService(
        serverUrl: _composeServerUrl(),
        username: username.text.trim(),
        password: password.text,
      ).listAudio();

      await _saveCache();
      widget.onTracksLoaded(tracks);

      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'source.navidrome.success'.tr,
        'source.successCount'.trParams({'count': '${tracks.length}'}),
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('source.navidrome.failed'.tr),
          content: Text(_formatNavidromeError(e)),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('common.ok'.tr)),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatNavidromeError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('localhost') || message.contains('127.0.0.1')) {
      return 'source.navidrome.localhost'.tr;
    }
    return message;
  }
}
