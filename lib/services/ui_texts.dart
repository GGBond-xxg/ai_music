import 'package:flutter/material.dart';

import '../models/music_track.dart';
import 'app_locale_notifier.dart';
import 'language_service.dart';

class UiTexts {
  UiTexts._(this.locale)
      : _lang = locale.languageCode.toLowerCase(),
        _isTraditional = isTraditionalChineseLocale(locale);

  final Locale locale;
  final String _lang;
  final bool _isTraditional;

  static UiTexts of(BuildContext context) {
    return UiTexts._(Localizations.localeOf(context));
  }

  bool get isZh => _lang == 'zh';
  bool get isZhHans => isZh && !_isTraditional;
  bool get isZhHant => isZh && _isTraditional;

  String choose(
      {required String en, required String zh, required String zhTw}) {
    if (isZhHant) return zhTw;
    if (isZhHans) return zh;
    return en;
  }

  String get appName => appNameForLocale(locale);
  String get play => choose(en: 'Play', zh: '播放', zhTw: '播放');
  String get pause => choose(en: 'Pause', zh: '暂停', zhTw: '暫停');
  String get next => choose(en: 'Next', zh: '下一首', zhTw: '下一首');
  String get settings => choose(en: 'Settings', zh: '设置', zhTw: '設定');
  String get close => choose(en: 'Close', zh: '关闭', zhTw: '關閉');
  String get cancel => choose(en: 'Cancel', zh: '取消', zhTw: '取消');
  String get ok => choose(en: 'OK', zh: '确定', zhTw: '確定');
  String get copy => choose(en: 'Copy', zh: '复制', zhTw: '複製');
  String copied(String title) => choose(
        en: '$title copied',
        zh: '$title 已复制',
        zhTw: '$title 已複製',
      );

  String get playback => choose(en: 'Playback', zh: '播放', zhTw: '播放');
  String get autoPlayOnOpen => choose(
        en: 'Auto-play when opening app',
        zh: '打开 App 自动播放音乐',
        zhTw: '開啟 App 時自動播放音樂',
      );
  String get autoPlayDisabledNoMusic => choose(
        en: 'Stays off when there is no music in the library.',
        zh: '没有音乐源数据时保持关闭',
        zhTw: '沒有音樂源資料時保持關閉',
      );
  String get autoPlaySubtitle => choose(
        en: 'When enabled, the app will auto-play on launch or after importing songs. Default is off.',
        zh: '开启后启动 App 或导入歌曲后自动播放，默认关闭',
        zhTw: '開啟後啟動 App 或匯入歌曲後自動播放，預設關閉',
      );

  String get themeMode => choose(en: 'Theme', zh: '主题模式', zhTw: '主題模式');
  String get followSystem =>
      choose(en: 'Follow system', zh: '跟随系统', zhTw: '跟隨系統');
  String get lightMode => choose(en: 'Light mode', zh: '浅色模式', zhTw: '淺色模式');
  String get darkMode => choose(en: 'Dark mode', zh: '夜间模式', zhTw: '夜間模式');

  String get languageSwitch => choose(en: 'Language', zh: '语言切换', zhTw: '語言切換');
  String get currentAppName =>
      choose(en: 'Current app name', zh: '当前应用名', zhTw: '目前應用名稱');
  String get aboutUs => choose(en: 'About', zh: '关于我们', zhTw: '關於我們');
  String get aboutDialogTitle =>
      choose(en: 'About Music', zh: '关于 音乐', zhTw: '關於 音樂');
  String get techStack => choose(en: 'Tech stack', zh: '技术栈', zhTw: '技術棧');
  String get techStackBody => choose(
        en: 'Flutter / Dart, Provider, media_kit, SQLite, SharedPreferences, WebDAV, Emby / Jellyfin / Navidrome API.',
        zh: 'Flutter / Dart、Provider、media_kit、SQLite、SharedPreferences、WebDAV、Emby/Jellyfin/Navidrome API。',
        zhTw:
            'Flutter / Dart、Provider、media_kit、SQLite、SharedPreferences、WebDAV、Emby/Jellyfin/Navidrome API。',
      );
  String get inspiredBy =>
      choose(en: 'Inspired by', zh: '借鉴的开源项目 / 技术方向', zhTw: '借鑑的開源專案 / 技術方向');
  String get inspiredByBody => choose(
        en: 'The UI keeps the original Music visual frame. Local and self-hosted music source support is adapted from the ai_music direction.',
        zh: '界面保留原项目的视觉框架，音乐源能力参考 ai_music 的本地音乐和自托管服务接入方式。',
        zhTw: '介面保留原專案的視覺框架，音樂源能力參考 ai_music 的本地音樂和自架服務接入方式。',
      );
  String get sponsorText => choose(
        en: 'Sponsorships and donations are welcome. Thank you for supporting continued maintenance of this music app.',
        zh: '如有赞助欢迎捐赠，感谢支持这个音乐 App 的持续维护。',
        zhTw: '如有贊助歡迎捐贈，感謝支持這個音樂 App 的持續維護。',
      );
  String get trc20Address =>
      choose(en: 'TRC20 address', zh: 'TRC20 地址', zhTw: 'TRC20 地址');
  String get chatGpt => 'ChatGPT';

  String get clearMusicCache =>
      choose(en: 'Clear music cache', zh: '清空音乐缓存', zhTw: '清空音樂快取');
  String clearSourceMusic(String source) => choose(
        en: 'Clear $source music',
        zh: '清空$source音乐',
        zhTw: '清空$source音樂',
      );
  String get clearSourceConfirmTitle =>
      choose(en: 'Clear this music source?', zh: '清空这个音乐源？', zhTw: '清空這個音樂源？');
  String clearSourceConfirmMessage(String source) => choose(
        en: 'Only the $source list cache inside the app will be cleared. Original local files and server music will not be deleted.',
        zh: '只会清空 App 内的 $source 列表缓存，不会删除本地文件或服务器音乐。',
        zhTw: '只會清空 App 內的 $source 清單快取，不會刪除本地檔案或伺服器音樂。',
      );
  String get clear => choose(en: 'Clear', zh: '清空', zhTw: '清空');
  String clearedSource(String source) => choose(
        en: '$source music cache cleared',
        zh: '已清空$source音乐缓存',
        zhTw: '已清空$source音樂快取',
      );

  String get musicSources =>
      choose(en: 'Music Sources', zh: '音乐源', zhTw: '音樂源');

  String get currentLibrary =>
      choose(en: 'Current library', zh: '当前音乐库', zhTw: '目前音樂庫');
  String get scanningDeviceMusic => choose(
      en: 'Scanning music on this device...',
      zh: '正在扫描设备里的音乐...',
      zhTw: '正在掃描裝置裡的音樂...');
  String get noImportedMusic =>
      choose(en: 'No music imported yet', zh: '还没有导入音乐', zhTw: '尚未匯入音樂');
  String importedCount(int count) => choose(
      en: '$count songs imported',
      zh: '已导入 $count 首音乐',
      zhTw: '已匯入 $count 首音樂');
  String get localMusicFile =>
      choose(en: 'Local music files', zh: '本地音乐文件', zhTw: '本地音樂檔案');
  String get localMusicFileSubtitle => choose(
        en: 'Pick mp3, flac, m4a, wav and other audio files from your phone or computer.',
        zh: '选择手机/电脑上的 mp3、flac、m4a、wav 等音频文件。',
        zhTw: '選擇手機/電腦上的 mp3、flac、m4a、wav 等音訊檔案。',
      );
  String get localMusicFolder =>
      choose(en: 'Local music folder', zh: '本地音乐文件夹', zhTw: '本地音樂資料夾');
  String get localMusicFolderSubtitle => choose(
        en: 'Scan a folder and add the songs inside to your library.',
        zh: '扫描一个文件夹，把里面的音乐批量加入资料库。',
        zhTw: '掃描一個資料夾，把裡面的音樂批量加入音樂庫。',
      );
  String get nasWebDavSubtitle => choose(
        en: 'Enter the WebDAV URL, account, password and folder path. Recursive scan is supported.',
        zh: '填写 WebDAV 地址、账号、密码和目录路径，支持递归扫描。',
        zhTw: '填寫 WebDAV 位址、帳號、密碼和目錄路徑，支援遞迴掃描。',
      );
  String get embySubtitle => choose(
      en: 'Connect to an Emby music library. API Key or username/password is supported.',
      zh: '连接 Emby 音乐库，支持 API Key 或用户名密码。',
      zhTw: '連接 Emby 音樂庫，支援 API Key 或使用者名稱密碼。');
  String get jellyfinSubtitle => choose(
      en: 'Connect to a Jellyfin music library. Lyrics scanning is optional.',
      zh: '连接 Jellyfin 音乐库，可选扫描歌词。',
      zhTw: '連接 Jellyfin 音樂庫，可選掃描歌詞。');
  String get navidromeSubtitle => choose(
      en: 'Connect to Navidrome or a Subsonic-compatible music server.',
      zh: '连接 Navidrome 或兼容 Subsonic API 的音乐服务器。',
      zhTw: '連接 Navidrome 或相容 Subsonic API 的音樂伺服器。');
  String get importLocalFailed => choose(
      en: 'Failed to import local music', zh: '导入本地音乐失败', zhTw: '匯入本地音樂失敗');
  String get scanFolderFailed => choose(
      en: 'Failed to scan local folder', zh: '扫描本地文件夹失败', zhTw: '掃描本地資料夾失敗');
  String get account => choose(en: 'Account', zh: '账号', zhTw: '帳號');
  String get password => choose(en: 'Password', zh: '密码', zhTw: '密碼');
  String get folderPath => choose(en: 'Folder path', zh: '目录路径', zhTw: '目錄路徑');
  String get port => choose(en: 'Port', zh: '端口', zhTw: '連接埠');
  String get recursiveScan => choose(
      en: 'Scan subfolders recursively', zh: '递归扫描子文件夹', zhTw: '遞迴掃描子資料夾');
  String get scanLyrics => choose(en: 'Scan lyrics', zh: '扫描歌词', zhTw: '掃描歌詞');
  String get scanLyricsSubtitle => choose(
      en: 'Large libraries may take longer. You can turn this off first.',
      zh: '音乐库很大时会更慢，可先关闭。',
      zhTw: '音樂庫很大時會更慢，可先關閉。');
  String get connectingAndScanning =>
      choose(en: 'Connecting and scanning...', zh: '扫描中...', zhTw: '掃描中...');
  String get connectAndScan =>
      choose(en: 'Connect & Scan', zh: '连接并扫描', zhTw: '連接並掃描');
  String get serverAddress =>
      choose(en: 'Server address', zh: '服务器地址', zhTw: '伺服器位址');
  String get usernameNoApiKey => choose(
      en: 'Username (when no API Key)',
      zh: '用户名（没有 API Key 时填写）',
      zhTw: '使用者名稱（沒有 API Key 時填寫）');
  String get username => choose(en: 'Username', zh: '用户名', zhTw: '使用者名稱');
  String get apiKeyOptional =>
      choose(en: 'API Key (optional)', zh: 'API Key（可选）', zhTw: 'API Key（可選）');
  String get embyDescription => choose(
      en: 'You can enter an API Key; without one, use username and password.',
      zh: '可以填 API Key；没有 API Key 时填用户名和密码。',
      zhTw: '可以填 API Key；沒有 API Key 時填使用者名稱和密碼。');
  String get jellyfinDescription => choose(
      en: 'Use the Jellyfin root address. On a real phone, use a LAN IP instead of localhost.',
      zh: '建议填 Jellyfin 根地址。真机访问电脑服务时不要填 localhost，要填局域网 IP。',
      zhTw: '建議填 Jellyfin 根位址。真機訪問電腦服務時不要填 localhost，要填區域網路 IP。');
  String get navidromeDescription => choose(
      en: 'Enter the server address, username and password for Navidrome or a Subsonic-compatible API.',
      zh: '填写 Navidrome 或兼容 Subsonic API 的服务器地址、用户名和密码。',
      zhTw: '填寫 Navidrome 或相容 Subsonic API 的伺服器位址、使用者名稱和密碼。');
  String get connectNasWebDav => choose(
      en: 'Connect NAS / WebDAV',
      zh: '连接 NAS / WebDAV',
      zhTw: '連接 NAS / WebDAV');
  String get connectEmby =>
      choose(en: 'Connect Emby', zh: '连接 Emby', zhTw: '連接 Emby');
  String get connectJellyfin =>
      choose(en: 'Connect Jellyfin', zh: '连接 Jellyfin', zhTw: '連接 Jellyfin');
  String get connectNavidrome => choose(
      en: 'Connect Navidrome / Subsonic',
      zh: '连接 Navidrome / Subsonic',
      zhTw: '連接 Navidrome / Subsonic');
  String sourceError(String source) => choose(
      en: '$source failed. Check server or network.',
      zh: '$source 失败，请检查服务器或网络。',
      zhTw: '$source 失敗，請檢查伺服器或網路。');

  String get myMusicLibrary =>
      choose(en: 'My Library', zh: '我的音乐库', zhTw: '我的音樂庫');
  String get localMusic => choose(en: 'Local music', zh: '本地音乐', zhTw: '本地音樂');
  String get nasServer =>
      choose(en: 'NAS / Server', zh: 'NAS / 服务器', zhTw: 'NAS / 伺服器');
  String get layoutMode => choose(en: 'Layout', zh: '排列方式', zhTw: '排列方式');
  String get grid => choose(en: 'Grid', zh: '格子', zhTw: '格子');
  String get list => choose(en: 'List', zh: '列表', zhTw: '列表');
  String get libraryLoadFailed =>
      choose(en: 'Failed to load library', zh: '音乐库加载失败', zhTw: '音樂庫載入失敗');
  String get retry => choose(en: 'Retry', zh: '重试', zhTw: '重試');
  String get noMusicYet =>
      choose(en: 'No music yet', zh: '还没有音乐', zhTw: '還沒有音樂');
  String get importFromSourcesHint => choose(
        en: 'Import songs from Music Sources: local music, NAS/WebDAV, Emby, Jellyfin or Navidrome.',
        zh: '到“音乐源”页导入本地音乐、NAS/WebDAV、Emby、Jellyfin 或 Navidrome 歌曲。',
        zhTw: '到「音樂源」頁匯入本地音樂、NAS/WebDAV、Emby、Jellyfin 或 Navidrome 歌曲。',
      );
  String get noMusicFound =>
      choose(en: 'No music found', zh: '没有找到音乐', zhTw: '找不到音樂');
  String get emptyQueue =>
      choose(en: 'Queue is empty', zh: '当前队列为空', zhTw: '目前佇列為空');
  String get noLyrics => choose(en: 'No lyrics', zh: '暂无歌词', zhTw: '暫無歌詞');
  String get expandLyrics =>
      choose(en: 'Expand lyrics', zh: '展开歌词', zhTw: '展開歌詞');
  String get collapseLyrics =>
      choose(en: 'Collapse lyrics', zh: '收起歌词', zhTw: '收合歌詞');
  String playingFrom(String source) => choose(
      en: 'Playing from $source', zh: '播放自 $source', zhTw: '播放自 $source');
  String get musicLibrarySource =>
      choose(en: 'Library', zh: '音乐库', zhTw: '音樂庫');

  String sourceNameFromString(String? sourceType, {String? fallback}) {
    switch (sourceType) {
      case 'localFile':
        return localMusic;
      case 'webDav':
        return nasServer;
      case 'emby':
        return 'Emby';
      case 'jellyfin':
        return 'Jellyfin';
      case 'navidrome':
        return 'Navidrome';
      case 'directUrl':
        return choose(en: 'Direct URL', zh: '直链音乐', zhTw: '直連音樂');
      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : musicLibrarySource;
    }
  }

  String sourceName(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.localFile:
        return localMusic;
      case MusicSourceType.webDav:
        return nasServer;
      case MusicSourceType.emby:
        return 'Emby';
      case MusicSourceType.jellyfin:
        return 'Jellyfin';
      case MusicSourceType.navidrome:
        return 'Navidrome';
      case MusicSourceType.directUrl:
        return choose(en: 'Direct URL', zh: '直链音乐', zhTw: '直連音樂');
    }
  }
}
