# Music Local Sources Build

这个版本保留 Music 原来的界面、底部导航、播放页、音乐库页和主题风格，但移除了 原来的在线账号 API / SDK 登录能力。

新的音乐来源来自 ai_music：

- 本地音乐文件 / 文件夹
- NAS / WebDAV / AList / Cloudreve
- Emby
- Jellyfin
- Navidrome / Subsonic

## 运行

```bash
flutter clean
flutter pub get
flutter run
```

Android 如果提示缺少 NDK，请安装 `28.2.13676358`。

## 说明

- 第三个底部 Tab 已改为“音乐源”。
- 导入音乐后，Music 原来的 Library / Now Playing / Queue UI 会展示和播放这些来源的歌曲。
- App 内部仍保留 `SpotifyProvider` 类名作为兼容层，目的是减少对原 Music UI 的侵入；它已经不再访问 Spotify 网络 API。
