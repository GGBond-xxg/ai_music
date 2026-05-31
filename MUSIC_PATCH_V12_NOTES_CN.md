# Music v12 修改说明

本包基于用户上传的最新 `spotoolfy_flutter-main (2).zip`，保留当前 Music/Spotoolfy 风格，继续完善本地/NAS/Emby/Jellyfin/Navidrome 音乐源版本。

## 主要改动

- App 名称：Spotoolfy 文案改为 Music；简体中文显示“音乐”，繁体中文显示“音樂”，其他语言显示“Music”。
- 顶部播放状态：显示“歌曲名 / 播放自 音乐源”。例如：`不再犹豫`、`播放自 Jellyfin`。
- Debug 标签：关闭 Flutter debug banner。
- 右上角按钮：进入设置，不再进入音乐源。
- 设置页：加入打开 App 自动播放、主题模式、语言切换、关于我们、ChatGPT 链接复制、TRC20 地址复制。
- 音乐源页：移除自动播放开关，自动播放只在设置页管理。
- 播放页：加回展开歌词按钮，可打开完整歌词面板。
- 顶部进度条：支持点击和拖动调整播放进度。
- 歌词切歌卡死：移除歌词 ListView 的 GlobalKey 定位方式，改为估算滚动位置，避免 Android 上 RenderViewport layout cycle 死循环。
- Android 通知栏：增加正在播放通知，Android 13+ 会请求通知权限。
- iOS：写入 MPNowPlayingInfoCenter，用于系统正在播放信息。
- 语言文件：移除日语本地化入口，仅保留 English / 简体中文 / 繁體中文。

## 运行建议

```powershell
flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.lock -ErrorAction SilentlyContinue
flutter pub get
flutter run
```

如果 Windows 仍遇到 Kotlin 跨盘缓存问题，可设置：

```powershell
setx PUB_CACHE D:\Code\PubCache
```

关闭 PowerShell 后重新打开，再重新执行 `flutter pub get` 和 `flutter run`。

## 需要你后续替换

设置页“关于我们”里的 TRC20 地址现在是占位：`请替换为你的 TRC20 地址`。如果有真实地址，直接在 `lib/pages/login.dart` 里修改 `_trc20Address`。
