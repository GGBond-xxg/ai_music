# Fresh Music / AI Music

一个基于 Flutter + GetX 的音乐播放器项目，定位是本地音乐、NAS/WebDAV、Emby、Jellyfin、Navidrome 聚合播放。当前版本重点优化了移动端播放体验：首页歌曲列表、底部迷你播放器、全屏播放页、歌词页、封面加载、封面取色背景和滑动性能。

> 当前项目名为 `fresh_music`，Android 应用显示名称为 `Music`。

## 当前版本重点

- 本地音乐导入：支持单个/多个音频文件导入，也支持文件夹扫描。
- NAS / WebDAV：支持账号密码连接、目录路径配置、递归扫描子目录。
- Emby：支持 API Key，也支持用户名/密码登录；扫描音乐库后生成可播放地址。
- Jellyfin：支持 API Key，也支持用户名/密码登录；可选择是否预加载歌词。
- Navidrome：通过 Subsonic API 扫描歌曲、播放、读取封面和歌词。
- 首页列表：支持 A-Z 字母索引、中文拼音排序、搜索、来源筛选、排序方式持久化。
- 播放页：底部 MiniPlayer 上滑进入全屏播放页，不再反复打开 Get 路由，滑动更顺。
- 歌词页：播放页和歌词页左右切换；歌词跟随播放进度滚动；支持歌词左/中/右对齐。
- 歌词识别：支持 LRC 时间轴歌词、普通文本歌词、部分双语歌词清理与单行显示。
- 播放模式：顺序播放、随机播放、重复播放、单曲循环，并做持久化保存。
- 睡眠定时器：支持预设时间和自定义分钟数，到点自动暂停。
- 后台播放：集成 `just_audio_background`，支持状态栏/锁屏媒体控制。
- 主题：支持浅色/深色/跟随系统；可手动开启 Android Monet 动态取色。
- 封面取色：播放界面和歌词界面背景会根据当前歌曲封面自动生成氛围色。
- 性能优化：图片缓存扩大、封面延迟加载、已加载封面保持显示、歌词滚动减少整页重建。

## 技术栈

| 模块 | 技术/依赖 |
| --- | --- |
| UI | Flutter Material 3 |
| 状态管理 | GetX |
| 播放器 | just_audio |
| 后台播放 | just_audio_background、audio_service |
| 本地缓存 | shared_preferences |
| 网络请求 | dio |
| WebDAV | webdav_client |
| 本地文件 | file_picker、path_provider、permission_handler |
| 音频元数据 | audio_metadata_reader |
| 图片缓存 | cached_network_image |
| 封面取色 | palette_generator |
| 中文排序 | lpinyin |
| 字体 | google_fonts |

## 目录结构

```text
lib/
├── app/
│   ├── app.dart                 # App 主题、Material 3、动态取色
│   └── app_controller.dart      # 主题模式、Monet 开关持久化
├── features/
│   ├── home/
│   │   ├── home_page.dart       # 首页、歌曲列表、搜索、排序、抽屉入口
│   │   └── home_controller.dart # 歌曲缓存、排序、去重、导入、恢复播放
│   ├── player/
│   │   └── player_page.dart     # 全屏播放页、歌词页、手势、控制栏、封面取色
│   ├── settings/
│   │   └── settings_page.dart   # 设置页、主题、缓存清理
│   └── sources/
│       └── sources_page.dart    # WebDAV / Emby / Jellyfin / Navidrome 连接弹窗
├── models/
│   ├── lyric_line.dart          # LRC / 普通歌词解析
│   └── music_track.dart         # 歌曲模型、来源枚举
├── services/
│   ├── cover_uri_resolver.dart  # 封面地址解析
│   ├── emby_service.dart        # Emby 扫描、鉴权、播放 URL
│   ├── jellyfin_service.dart    # Jellyfin 扫描、鉴权、歌词读取
│   ├── local_music_service.dart # 本地音频选择、扫描、标签、封面、歌词
│   ├── navidrome_service.dart   # Navidrome/Subsonic API
│   ├── player_controller.dart   # 播放队列、播放模式、进度、恢复播放
│   ├── player_sheet_controller.dart # 全屏播放页手势展开/收起
│   └── webdav_music_service.dart # WebDAV 音频扫描
└── widgets/
    ├── mini_player.dart         # 底部迷你播放器
    └── track_cover.dart         # 封面组件、缓存、延迟加载优化
```

## 支持的音乐来源

### 1. 本地音乐

入口：首页右上角 `+` → 本地音乐。

支持两种方式：

- 选择单个/多个音频文件
- 选择音乐文件夹并递归扫描

本地音乐会尝试读取：

- 歌名
- 艺术家
- 专辑
- 时长
- 内嵌封面
- 内嵌歌词
- 同名 `.lrc` 旁挂歌词

支持格式包括：

```text
mp3, flac, m4a, m4b, wav, ogg, opus, aac, wma, ape, aiff, aif, alac, mka, mpga, mpeg, amr
```

Android 11+ 部分系统文件夹选择器可能不给真实路径。如果文件夹扫描不到内容，项目会自动 fallback 到多文件选择，让用户在该目录里全选音频文件。

### 2. WebDAV / NAS

入口：首页右上角 `+` → WebDAV。

填写示例：

```text
WebDAV 地址：http://192.168.1.10:5244/dav
账号：你的账号
密码：你的密码
目录路径：/
递归扫描子目录：开启
```

WebDAV 会扫描远程目录中的音频文件，并生成可直接播放的地址。适合 AList、NAS WebDAV、网盘 WebDAV 等场景。

### 3. Emby

入口：首页右上角 `+` → Emby。

推荐填写方式：

```text
Emby IP 地址：192.168.137.177
端口号：8096
API Key：你的 Emby API Key
```

也可以使用用户名密码：

```text
Emby IP 地址：192.168.137.177
端口号：8096
用户名：你的用户名
密码：你的密码
```

程序会自动拼接服务地址，也兼容填写完整地址。例如：

```text
192.168.137.177:8096
http://192.168.137.177:8096
http://192.168.137.177:8096/emby
```

Emby 播放使用：

```text
/emby/Audio/{Id}/universal
```

主要播放参数：

```text
TranscodingProtocol=http
TranscodingContainer=mp3
AudioCodec=mp3,aac,flac
Container=mp3,aac,m4a,flac,webma,webm,wav,ogg
Static=false
```

### 4. Jellyfin

入口：首页右上角 `+` → Jellyfin。

填写方式和 Emby 类似，支持：

- API Key
- 用户名/密码
- IP + 端口
- 完整服务地址

Jellyfin 默认只扫描歌曲列表，避免大音乐库在连接时因为逐首拉歌词而卡很久。如果需要歌词，可以在连接弹窗中开启预加载歌词。

### 5. Navidrome

入口：首页右上角 `+` → Navidrome。

填写示例：

```text
Navidrome 地址：192.168.1.20:4533
用户名：你的用户名
密码：你的密码
```

Navidrome 使用 Subsonic API：

- `ping.view` 检测连接
- `search3.view` 搜索歌曲
- `getAlbum.view` 兜底读取专辑歌曲
- `stream.view` 播放
- `getCoverArt.view` 封面
- `getLyrics.view` 歌词

## 首页功能

首页主要由 `_GramophoneLibraryView` 实现，当前包含：

- 顶部 AppBar：设置、排序、搜索、添加来源
- 来源筛选：当存在多个音乐来源时自动显示
- A-Z 索引：适合歌曲很多时快速跳转
- 歌曲列表：固定行高，减少 layout 计算
- 中文拼音排序：中文歌曲可参与 A-Z / Z-A 排序
- 搜索页：按歌曲名、艺术家、来源搜索
- MiniPlayer：底部常驻播放条，可点击或上滑打开播放页

### 排序方式

排序配置会保存到本地：

- 歌名 A-Z
- 歌名 Z-A
- 艺术家 A-Z
- 艺术家 Z-A

### 封面滚动优化

这版重点优化了首页封面滑动卡顿：

- `main.dart` 扩大 Flutter 图片缓存，减少反复解码。
- `TrackCover` 使用 `RepaintBoundary`，降低列表滚动重绘影响。
- 已经加载出来的封面会继续显示。
- 未加载过的封面在滚动中先显示占位图。
- 手指停止滑动后再加载当前可见区域封面。
- 网络封面使用 `CachedNetworkImage` 并关闭淡入淡出动画。

这样可以避免“滑动到未加载封面区域时，一边滚动一边下载/解码图片”导致明显掉帧。

## 播放页与歌词页

全屏播放页通过 `PlayerSheetController` 控制，不再每次拖动都打开/关闭 Get 路由。`PlayerPage` 预挂载在首页上方，通过 `sheetOffset` 做抽屉式平移。

### 手势

- 点击 MiniPlayer：打开全屏播放页
- 上滑 MiniPlayer：跟手打开播放页
- 下滑播放页：关闭回首页
- 左右滑动：播放页和歌词页切换
- 顶部横条下滑：关闭播放页

### 播放页

播放页包含：

- 歌曲标题/艺术家
- 来源标签
- 大封面
- 两行歌词预览
- 进度条
- 上一首/播放暂停/下一首
- 播放模式
- 睡眠定时器

播放页背景会通过 `palette_generator` 从当前歌曲封面提取颜色，生成氛围背景，同时保持文字可读性。

### 歌词页

歌词页包含：

- 当前歌曲信息
- 歌词列表
- 歌词对齐切换：左对齐 / 居中 / 右对齐
- 自动跟随当前播放进度滚动

歌词滚动逻辑做了性能优化：

- 只有歌词索引变化时才更新当前行。
- 拖动进度条时使用预览位置同步歌词，避免 seek 过程中歌词跳回开头。
- 横屏切换到歌词页时，会等待列表完成 layout 后再定位当前歌词。
- 歌词展示做单行清理，避免双语歌词被误拆成多行造成高度跳动。

## 播放控制

`PlayerController` 负责：

- 播放队列
- 当前歌曲索引
- 当前播放状态
- 进度拖动和 seek
- 上一首/下一首
- 播放模式
- 歌词偏移位置
- 播放页当前页持久化
- 上次播放歌曲和进度恢复
- 后台通知元数据

### 播放模式

支持 4 种模式：

| 模式 | 说明 |
| --- | --- |
| 顺序播放 | 按队列播放到最后一首后停止 |
| 随机播放 | 下一首随机选择 |
| 重复播放 | 播放到最后一首后回到第一首继续播放 |
| 单曲循环 | 当前歌曲循环播放 |

播放模式会写入 `shared_preferences`，下次打开 App 会恢复。

## 缓存与持久化

当前会持久化这些内容：

- 音乐列表缓存
- 各来源连接信息
- 排序方式
- 当前播放歌曲
- 当前播放进度
- 播放模式
- 歌词对齐方式
- 播放页当前页
- 主题模式
- Monet 动态取色开关

本地音乐缓存会检查文件是否仍存在；网络来源如 WebDAV / Emby / Jellyfin / Navidrome 会先显示缓存，播放或重新扫描时再连接服务。

## Android 权限配置

`android/app/src/main/AndroidManifest.xml` 已包含：

```xml
<!-- 网络：Emby / NAS / 封面图片 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 后台播放 / 状态栏媒体通知 -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- Android 13+ 通知权限 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Android 13+ 读取音频文件权限 -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- Android 12 及以下读取存储权限 -->
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

如果播放 HTTP 局域网服务，项目也已开启：

```xml
android:usesCleartextTraffic="true"
android:networkSecurityConfig="@xml/network_security_config"
```

## 运行项目

环境要求：

```text
Dart SDK: >= 3.4.0 < 4.0.0
Flutter: 建议使用稳定版
```

安装依赖：

```bash
flutter pub get
```

运行：

```bash
flutter run
```

清理后重新运行：

```bash
flutter clean
flutter pub get
flutter run
```

Release 运行测试：

```bash
flutter run --release
```

Android 打包：

```bash
flutter build apk --release
```

## 常见问题

### 1. 本地文件夹扫描不到歌曲

Android 11+ 的系统文件夹授权有时不给真实路径，`Directory.list` 会读不到内容。项目会自动弹出多文件选择器作为 fallback。建议在目标文件夹内全选音乐文件导入。

### 2. Emby / Jellyfin 真机连接失败

真机不能填电脑上的 `localhost` 或 `127.0.0.1`。需要填写电脑或 NAS 在同一局域网内的 IP，例如：

```text
192.168.1.20:8096
```

同时确认手机和服务器在同一网络，防火墙允许对应端口访问。

### 3. HTTP 音乐流无法播放

确认 Android 已允许明文 HTTP。当前 Manifest 已配置 `usesCleartextTraffic=true`，同时需要检查 `network_security_config.xml` 是否允许你的局域网地址。

### 4. 首页滑动到未加载封面时卡顿

当前版本已经做了封面延迟加载优化。正常表现应该是：未加载区域滑动时先显示占位图，停止滑动后封面逐步出现；已经出现过的封面再次滑动会很流畅。

### 5. 歌词不同步或跳动

优先检查 LRC 时间轴是否正确。如果是进度条拖动后的短暂不同步，当前版本已经用 `seekPreviewPosition` 做了优化，正常会在 seek 完成后恢复。

## 当前优化记录

- 播放页不再依赖重复路由打开，改为首页 overlay + sheet 平移。
- 播放页、歌词页左右切换动画优化为平移切换。
- 歌词滚动减少整页 `setState`，只在当前歌词索引变化时更新。
- 横屏歌词定位增加 layout 等待，避免进入歌词页先跳顶部。
- 播放界面和歌词界面背景改为跟随封面取色。
- 播放页透明度提高，减少首页透出。
- 首页封面滚动优化：已加载封面保留，未加载封面滚动中延迟加载。
- MiniPlayer 进度层保留轻量展示，避免大面积复杂渐变影响性能。
- 图片缓存上限提高到 600 张 / 96MB，减少封面反复解码。
- 本地文件夹导入增加 Android 权限请求和 fallback 多文件选择。

## 后续可继续优化

- 增加播放器均衡器或音效设置。
- 增加歌单/收藏/最近播放。
- 增加下载缓存网络歌曲能力。
- 增加歌词时间偏移手动调整。
- 增加桌面端更适配的布局。
- 增加 iOS 后台播放和文件导入细节适配。
