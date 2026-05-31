import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';
import '../providers/spotify_provider.dart';
import '../services/emby_service.dart';
import '../services/jellyfin_service.dart';
import '../services/local_music_service.dart';
import '../services/navidrome_service.dart';
import '../services/webdav_music_service.dart';
import '../services/ui_texts.dart';

class MusicSourcesPage extends StatelessWidget {
  const MusicSourcesPage({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<SpotifyProvider>();
    final t = UiTexts.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        showHeader ? 32 : 8,
        16,
        8,
      ),
      children: [
        if (showHeader) ...[
          Text(
            t.musicSources,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 20),
        ],
        _LibrarySummaryCard(
          trackCount: provider.libraryTracks.length,
          scanningDevice: provider.initialDeviceScanInProgress,
        ),
        const SizedBox(height: 16),
        SourcesSection(
          onTracksLoaded: (tracks, sourceName) => _handleTracksLoaded(
            context,
            tracks,
            sourceName,
          ),
        ),
      ],
    );
  }

  Future<void> _handleTracksLoaded(
    BuildContext context,
    List<MusicTrack> tracks,
    String sourceName,
  ) async {
    final provider = context.read<SpotifyProvider>();
    await provider.importTracks(
      tracks,
      sourceName: sourceName,
      playFirst: provider.autoPlayOnOpen,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '$sourceName · ${UiTexts.of(context).importedCount(tracks.length)}')),
    );
  }
}

class _LibrarySummaryCard extends StatelessWidget {
  const _LibrarySummaryCard({
    required this.trackCount,
    required this.scanningDevice,
  });

  final int trackCount;
  final bool scanningDevice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: scanningDevice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.library_music_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UiTexts.of(context).currentLibrary,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scanningDevice
                            ? UiTexts.of(context).scanningDeviceMusic
                            : trackCount == 0
                                ? UiTexts.of(context).noImportedMusic
                                : UiTexts.of(context).importedCount(trackCount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef TracksLoadedCallback = Future<void> Function(
    List<MusicTrack> tracks, String sourceName);

class SourcesSection extends StatelessWidget {
  const SourcesSection({super.key, required this.onTracksLoaded});

  final TracksLoadedCallback onTracksLoaded;

  @override
  Widget build(BuildContext context) {
    final t = UiTexts.of(context);
    return Column(
      children: [
        SourceActionCard(
          icon: Icons.audio_file_rounded,
          title: t.localMusicFile,
          subtitle: t.localMusicFileSubtitle,
          onTap: () => _loadLocalFiles(context),
        ),
        SourceActionCard(
          icon: Icons.folder_rounded,
          title: t.localMusicFolder,
          subtitle: t.localMusicFolderSubtitle,
          onTap: () => _loadLocalFolder(context),
        ),
        SourceActionCard(
          icon: Icons.storage_rounded,
          title: 'NAS / WebDAV / AList / Cloudreve',
          subtitle: t.nasWebDavSubtitle,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _WebDavDialog(onTracksLoaded: onTracksLoaded),
          ),
        ),
        SourceActionCard(
          icon: Icons.live_tv_rounded,
          title: 'Emby',
          subtitle: t.embySubtitle,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _EmbyDialog(onTracksLoaded: onTracksLoaded),
          ),
        ),
        SourceActionCard(
          icon: Icons.cast_connected_rounded,
          title: 'Jellyfin',
          subtitle: t.jellyfinSubtitle,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _JellyfinDialog(onTracksLoaded: onTracksLoaded),
          ),
        ),
        SourceActionCard(
          icon: Icons.cloud_queue_rounded,
          title: 'Navidrome / Subsonic',
          subtitle: t.navidromeSubtitle,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _NavidromeDialog(onTracksLoaded: onTracksLoaded),
          ),
        ),
      ],
    );
  }

  Future<void> _loadLocalFiles(BuildContext context) async {
    HapticFeedback.lightImpact();
    final sourceName = UiTexts.of(context).localMusic;
    try {
      final tracks = await LocalMusicService().pickAudioFiles();
      if (tracks.isEmpty) return;
      await onTracksLoaded(tracks, sourceName);
    } catch (e) {
      if (context.mounted) {
        _showError(context, UiTexts.of(context).importLocalFailed, e);
      }
    }
  }

  Future<void> _loadLocalFolder(BuildContext context) async {
    HapticFeedback.lightImpact();
    final sourceName = UiTexts.of(context).localMusic;
    try {
      final tracks = await LocalMusicService().pickAudioFolder();
      if (tracks.isEmpty) return;
      await onTracksLoaded(tracks, sourceName);
    } catch (e) {
      if (context.mounted) {
        _showError(context, UiTexts.of(context).scanFolderFailed, e);
      }
    }
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
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
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
            decoration:
                InputDecoration(labelText: hostLabel, hintText: hostHint),
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
                labelText: UiTexts.of(context).port, hintText: portHint),
          ),
        ),
      ],
    );
  }
}

String _composeServerUrl(TextEditingController hostController,
    TextEditingController portController, String defaultPort) {
  var host = hostController.text.trim();
  if (host.isEmpty) return '';
  var port = portController.text.trim().isEmpty
      ? defaultPort
      : portController.text.trim();
  final hasScheme = host.startsWith('http://') || host.startsWith('https://');
  final parseInput = hasScheme ? host : 'http://$host';
  final uri = Uri.tryParse(parseInput);
  if (uri != null && uri.host.isNotEmpty) {
    if (uri.hasPort &&
        (portController.text.trim().isEmpty ||
            portController.text.trim() == defaultPort)) {
      port = uri.port.toString();
      portController.text = port;
    }
    final path = uri.pathSegments.where((e) => e.trim().isNotEmpty).join('/');
    final prefix = hasScheme ? '${uri.scheme}://' : '';
    final hostText = '$prefix${uri.host}${path.isEmpty ? '' : '/$path'}';
    if (hostController.text.trim() != hostText) hostController.text = hostText;
    return '$prefix${uri.host}:$port${path.isEmpty ? '' : '/$path'}';
  }
  final match = RegExp(r'^(.+):(\d+)$').firstMatch(host);
  if (match != null && !host.contains(']')) {
    host = match.group(1) ?? host;
    port = match.group(2) ?? port;
    hostController.text = host;
    portController.text = port;
  }
  return '$host:$port';
}

class _WebDavDialog extends StatefulWidget {
  const _WebDavDialog({required this.onTracksLoaded});
  final TracksLoadedCallback onTracksLoaded;

  @override
  State<_WebDavDialog> createState() => _WebDavDialogState();
}

class _WebDavDialogState extends State<_WebDavDialog> {
  final url = TextEditingController(text: 'http://192.168.1.10:5244/dav');
  final user = TextEditingController();
  final pass = TextEditingController();
  final path = TextEditingController(text: '/');
  bool recursive = true;
  bool loading = false;
  bool loadingCache = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    url.text = prefs.getString('webdav.base_url') ?? url.text;
    user.text = prefs.getString('webdav.username') ?? '';
    pass.text = prefs.getString('webdav.password') ?? '';
    path.text = prefs.getString('webdav.path') ?? '/';
    recursive = prefs.getBool('webdav.recursive') ?? true;
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav.base_url', url.text.trim());
    await prefs.setString('webdav.username', user.text.trim());
    await prefs.setString('webdav.password', pass.text);
    await prefs.setString(
        'webdav.path', path.text.trim().isEmpty ? '/' : path.text.trim());
    await prefs.setBool('webdav.recursive', recursive);
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
      title: Text(UiTexts.of(context).connectNasWebDav),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: url,
                enabled: !loading && !loadingCache,
                decoration: InputDecoration(
                    labelText: 'WebDAV URL',
                    hintText: 'http://192.168.1.10:5244/dav')),
            TextField(
                controller: user,
                enabled: !loading && !loadingCache,
                decoration:
                    InputDecoration(labelText: UiTexts.of(context).account)),
            TextField(
                controller: pass,
                enabled: !loading && !loadingCache,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: UiTexts.of(context).password)),
            TextField(
                controller: path,
                enabled: !loading && !loadingCache,
                decoration: InputDecoration(
                    labelText: UiTexts.of(context).folderPath, hintText: '/')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: recursive,
              onChanged: loading || loadingCache
                  ? null
                  : (v) => setState(() => recursive = v),
              title: Text(UiTexts.of(context).recursiveScan),
            ),
            if (loading || loadingCache)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator()),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: loading ? null : () => Navigator.pop(context),
            child: Text(UiTexts.of(context).cancel)),
        FilledButton(
            onPressed: loading || loadingCache ? null : _connect,
            child: Text(loading
                ? UiTexts.of(context).connectingAndScanning
                : UiTexts.of(context).connectAndScan)),
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final tracks = await WebDavMusicService().listAudio(
        baseUrl: url.text.trim(),
        username: user.text.trim(),
        password: pass.text,
        path: path.text.trim().isEmpty ? '/' : path.text.trim(),
        recursive: recursive,
      );
      await _save();
      await widget.onTracksLoaded(tracks, 'NAS / WebDAV');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, UiTexts.of(context).sourceError('WebDAV'), e);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _EmbyDialog extends StatefulWidget {
  const _EmbyDialog({required this.onTracksLoaded});
  final TracksLoadedCallback onTracksLoaded;

  @override
  State<_EmbyDialog> createState() => _EmbyDialogState();
}

class _EmbyDialogState extends State<_EmbyDialog> {
  final host = TextEditingController(text: '192.168.1.20');
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
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    host.text = prefs.getString('emby.host') ?? host.text;
    port.text = prefs.getString('emby.port') ?? port.text;
    apiKey.text = prefs.getString('emby.api_key') ?? '';
    username.text = prefs.getString('emby.username') ?? '';
    password.text = prefs.getString('emby.password') ?? '';
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _save(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emby.host', host.text.trim());
    await prefs.setString('emby.port', port.text.trim());
    await prefs.setString('emby.server_url', serverUrl);
    await prefs.setString('emby.api_key', apiKey.text.trim());
    await prefs.setString('emby.username', username.text.trim());
    await prefs.setString('emby.password', password.text);
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

  @override
  Widget build(BuildContext context) => _MediaServerDialogScaffold(
        title: UiTexts.of(context).connectEmby,
        description: UiTexts.of(context).embyDescription,
        loading: loading || loadingCache,
        busyText: loading
            ? UiTexts.of(context).connectingAndScanning
            : UiTexts.of(context).connectAndScan,
        onCancel: loading ? null : () => Navigator.pop(context),
        onSubmit: loading || loadingCache ? null : _connect,
        children: [
          _HostPortFields(
              hostController: host,
              portController: port,
              enabled: !loading && !loadingCache,
              hostLabel: UiTexts.of(context).serverAddress,
              hostHint: '192.168.1.20',
              portHint: '8096'),
          TextField(
              controller: apiKey,
              enabled: !loading && !loadingCache,
              obscureText: hideApiKey,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).apiKeyOptional,
                  suffixIcon: IconButton(
                      icon: Icon(hideApiKey
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () =>
                          setState(() => hideApiKey = !hideApiKey)))),
          TextField(
              controller: username,
              enabled: !loading && !loadingCache,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).usernameNoApiKey)),
          TextField(
              controller: password,
              enabled: !loading && !loadingCache,
              obscureText: hidePassword,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).password,
                  suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword)))),
        ],
      );

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final serverUrl = _composeServerUrl(host, port, '8096');
      final tracks = await EmbyService(
              serverUrl: serverUrl,
              apiKey: apiKey.text.trim(),
              username: username.text.trim(),
              password: password.text)
          .listAudio();
      await _save(serverUrl);
      await widget.onTracksLoaded(tracks, 'Emby');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, UiTexts.of(context).sourceError('Emby'), e);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _JellyfinDialog extends StatefulWidget {
  const _JellyfinDialog({required this.onTracksLoaded});
  final TracksLoadedCallback onTracksLoaded;

  @override
  State<_JellyfinDialog> createState() => _JellyfinDialogState();
}

class _JellyfinDialogState extends State<_JellyfinDialog> {
  final host = TextEditingController(text: '192.168.1.20');
  final port = TextEditingController(text: '8888');
  final apiKey = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  bool scanLyrics = false;
  bool loading = false;
  bool loadingCache = true;
  bool hideApiKey = true;
  bool hidePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    host.text = prefs.getString('jellyfin.host') ?? host.text;
    port.text = prefs.getString('jellyfin.port') ?? port.text;
    apiKey.text = prefs.getString('jellyfin.api_key') ?? '';
    username.text = prefs.getString('jellyfin.username') ?? '';
    password.text = prefs.getString('jellyfin.password') ?? '';
    scanLyrics = prefs.getBool('jellyfin.scan_lyrics') ?? false;
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _save(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jellyfin.host', host.text.trim());
    await prefs.setString('jellyfin.port', port.text.trim());
    await prefs.setString('jellyfin.server_url', serverUrl);
    await prefs.setString('jellyfin.api_key', apiKey.text.trim());
    await prefs.setString('jellyfin.username', username.text.trim());
    await prefs.setString('jellyfin.password', password.text);
    await prefs.setBool('jellyfin.scan_lyrics', scanLyrics);
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

  @override
  Widget build(BuildContext context) => _MediaServerDialogScaffold(
        title: UiTexts.of(context).connectJellyfin,
        description: UiTexts.of(context).jellyfinDescription,
        loading: loading || loadingCache,
        busyText: loading
            ? UiTexts.of(context).connectingAndScanning
            : UiTexts.of(context).connectAndScan,
        onCancel: loading ? null : () => Navigator.pop(context),
        onSubmit: loading || loadingCache ? null : _connect,
        children: [
          _HostPortFields(
              hostController: host,
              portController: port,
              enabled: !loading && !loadingCache,
              hostLabel: UiTexts.of(context).serverAddress,
              hostHint: '192.168.1.20',
              portHint: '8888'),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: scanLyrics,
              onChanged: loading || loadingCache
                  ? null
                  : (v) => setState(() => scanLyrics = v),
              title: Text(UiTexts.of(context).scanLyrics),
              subtitle: Text(UiTexts.of(context).scanLyricsSubtitle)),
          TextField(
              controller: apiKey,
              enabled: !loading && !loadingCache,
              obscureText: hideApiKey,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).apiKeyOptional,
                  suffixIcon: IconButton(
                      icon: Icon(hideApiKey
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () =>
                          setState(() => hideApiKey = !hideApiKey)))),
          TextField(
              controller: username,
              enabled: !loading && !loadingCache,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).usernameNoApiKey)),
          TextField(
              controller: password,
              enabled: !loading && !loadingCache,
              obscureText: hidePassword,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).password,
                  suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword)))),
        ],
      );

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final serverUrl = _composeServerUrl(host, port, '8888');
      final service = JellyfinService(
          serverUrl: serverUrl,
          apiKey: apiKey.text.trim(),
          username: username.text.trim(),
          password: password.text,
          prefetchLyrics: scanLyrics);
      await service.testConnection();
      final tracks = await service.listAudio();
      await _save(serverUrl);
      await widget.onTracksLoaded(tracks, 'Jellyfin');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, UiTexts.of(context).sourceError('Jellyfin'), e);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _NavidromeDialog extends StatefulWidget {
  const _NavidromeDialog({required this.onTracksLoaded});
  final TracksLoadedCallback onTracksLoaded;

  @override
  State<_NavidromeDialog> createState() => _NavidromeDialogState();
}

class _NavidromeDialogState extends State<_NavidromeDialog> {
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
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    host.text = prefs.getString('navidrome.host') ?? host.text;
    port.text = prefs.getString('navidrome.port') ?? port.text;
    username.text = prefs.getString('navidrome.username') ?? '';
    password.text = prefs.getString('navidrome.password') ?? '';
    if (mounted) setState(() => loadingCache = false);
  }

  Future<void> _save(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('navidrome.host', host.text.trim());
    await prefs.setString('navidrome.port', port.text.trim());
    await prefs.setString('navidrome.server_url', serverUrl);
    await prefs.setString('navidrome.username', username.text.trim());
    await prefs.setString('navidrome.password', password.text);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MediaServerDialogScaffold(
        title: UiTexts.of(context).connectNavidrome,
        description: UiTexts.of(context).navidromeDescription,
        loading: loading || loadingCache,
        busyText: loading
            ? UiTexts.of(context).connectingAndScanning
            : UiTexts.of(context).connectAndScan,
        onCancel: loading ? null : () => Navigator.pop(context),
        onSubmit: loading || loadingCache ? null : _connect,
        children: [
          _HostPortFields(
              hostController: host,
              portController: port,
              enabled: !loading && !loadingCache,
              hostLabel: UiTexts.of(context).serverAddress,
              hostHint: '192.168.1.20',
              portHint: '4533'),
          TextField(
              controller: username,
              enabled: !loading && !loadingCache,
              decoration:
                  InputDecoration(labelText: UiTexts.of(context).username)),
          TextField(
              controller: password,
              enabled: !loading && !loadingCache,
              obscureText: hidePassword,
              decoration: InputDecoration(
                  labelText: UiTexts.of(context).password,
                  suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword)))),
        ],
      );

  Future<void> _connect() async {
    setState(() => loading = true);
    try {
      final serverUrl = _composeServerUrl(host, port, '4533');
      final tracks = await NavidromeService(
              serverUrl: serverUrl,
              username: username.text.trim(),
              password: password.text)
          .listAudio();
      await _save(serverUrl);
      await widget.onTracksLoaded(tracks, 'Navidrome / Subsonic');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(context, UiTexts.of(context).sourceError('Navidrome'), e);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _MediaServerDialogScaffold extends StatelessWidget {
  const _MediaServerDialogScaffold({
    required this.title,
    required this.description,
    required this.children,
    required this.loading,
    required this.busyText,
    required this.onCancel,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final bool loading;
  final String busyText;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35),
              ),
              const SizedBox(height: 12),
              ...children.map((child) => Padding(
                  padding: const EdgeInsets.only(bottom: 8), child: child)),
              if (loading)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: onCancel, child: Text(UiTexts.of(context).cancel)),
        FilledButton(onPressed: onSubmit, child: Text(busyText)),
      ],
    );
  }
}

void _showError(BuildContext context, String title, Object _) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(title)),
  );
}
