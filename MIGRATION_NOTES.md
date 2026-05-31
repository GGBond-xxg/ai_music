# Migration notes

目标：保留 Music 原来的 UI / 交互 / 主题 / 页面壳，只替换音乐来源和播放数据层。

## 保留的 Music 结构

- `lib/main.dart`
- `lib/pages/nowplaying.dart`
- `lib/pages/library.dart`
- `lib/widgets/player.dart`
- `lib/widgets/library_section.dart`
- `lib/widgets/library_grid.dart`
- 原来的底部导航、播放页、音乐库、搜索、主题、歌词/笔记相关 UI

## 新增 / 接入的 ai_music 音乐源

- `lib/models/music_track.dart`
- `lib/services/local_music_service.dart`
- `lib/services/webdav_music_service.dart`
- `lib/services/emby_service.dart`
- `lib/services/jellyfin_service.dart`
- `lib/services/navidrome_service.dart`
- `lib/services/player/media_kit_player.dart`
- `lib/pages/music_sources_page.dart`

## 已移除 / 停用

- Spotify SDK 依赖
- Spotify 登录跳转
- Spotify Android redirect activity
- iOS Spotify URL scheme / Associated Domains
- Web Spotify Playback SDK script
- 旧的在线 API 客户端文件

`SpotifyProvider` 类名被保留为兼容层，避免大规模改动 Music UI。它现在使用 `media_kit` 播放本地/NAS/媒体服务器音乐，不再访问原在线账号 API。
