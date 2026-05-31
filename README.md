# Music

一个基于 Flutter 开发的本地与私有音乐库播放器。

Music 支持本地音乐、NAS / WebDAV、Emby、Jellyfin、Navidrome / Subsonic 等音乐来源，适合在手机上统一管理和播放自己的音乐库。

## 功能特性

### 音乐来源

* 本地音乐文件
* 本地音乐文件夹扫描
* NAS / WebDAV
* Emby
* Jellyfin
* Navidrome / Subsonic

### 播放功能

* 本地与服务器音乐播放
* 播放 / 暂停 / 上一首 / 下一首
* 顶部进度条拖动调整播放位置
* 播放队列
* 自动播放开关
* Android 通知栏媒体控制
* iOS 后台音频支持

### 歌词功能

* 本地歌词
* 服务器歌词
* 网络歌词来源切换
* 歌词自动滚动
* 手动滚动后可回到当前播放歌词
* 支持手动切换歌词来源

### 音乐库

* 格子模式
* 列表模式
* 按音乐来源筛选
* 本地缓存
* 按音乐源清空缓存，不删除原始音乐文件

### 界面与主题

* Material You / 莫奈风格
* 支持浅色模式
* 支持夜间模式
* 支持跟随系统
* 支持根据歌曲封面自动取色
* 主题色缓存，重新打开 App 后保持上次主题色

### 多语言

* English
* 简体中文
* 繁體中文

App 名称会根据系统语言显示：

* 简体中文：音乐
* 繁體中文：音樂
* 其他语言：Music

## 技术栈

* Flutter
* Dart
* Provider
* media_kit
* SQLite / sqflite
* SharedPreferences
* WebDAV
* Emby API
* Jellyfin API
* Navidrome / Subsonic API
* Material Color Utilities

## 项目结构

```text
lib/
  data/                 数据库与本地数据
  l10n/                 国际化文件
  models/               数据模型
  pages/                页面
  providers/            状态管理
  services/             音乐源、歌词、缓存、通知等服务
  utils/                工具类
  widgets/              通用组件
```

## 环境要求

```text
Flutter SDK: >= 3.4.0
Dart SDK: >= 3.4.0 < 4.0.0
Android minSdk: 23
```

## 安装依赖

```bash
flutter pub get
```

## 运行项目

```bash
flutter run
```

## Android 运行

建议先清理缓存：

```bash
flutter clean
flutter pub get
flutter run
```

如果修改了 Android 包名、图标、原生配置，建议执行：

```bash
flutter clean
flutter pub get
flutter run
```

## iOS 运行

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

## 生成 App 图标

项目使用 `flutter_launcher_icons` 生成 Android / iOS 图标。

图标文件建议放在：

```text
assets/icons/app_icon_ios.png
assets/icons/app_icon_monochrome.png
```

生成图标：

```bash
dart run flutter_launcher_icons
```

如果桌面图标没有变化，建议卸载旧 App 后重新安装。

```bash
adb uninstall com.chatlee.aimusic
flutter run
```

## Android 主题图标

Android 13+ 支持 Material You 主题图标。需要提供单色图标：

```text
assets/icons/app_icon_monochrome.png
```

建议该图标为：

* 透明背景
* 单色图形
* 不使用渐变
* 不使用复杂阴影
* 图形居中并保留安全边距

## 当前包名

```text
com.chatlee.aimusic
```

## 常用命令

### 清理项目

```bash
flutter clean
```

### 重新获取依赖

```bash
flutter pub get
```

### 检查代码

```bash
flutter analyze
```

### Debug 运行

```bash
flutter run
```

### Debug APK

```bash
flutter build apk --debug
```

### Release APK

```bash
flutter build apk --release
```

## 权限说明

Android 端会根据系统版本请求本地音乐读取权限，用于扫描设备中的音乐文件。

App 只会读取本地音乐文件用于展示和播放，不会删除用户原始音乐文件。

清空音乐库缓存时，只清除 App 内部缓存数据，不会删除本地文件，也不会删除服务器上的音乐。

## 关于音乐源

### 本地音乐

支持扫描手机本地常见音乐目录，并读取音乐文件、歌曲信息、封面与歌词。

### NAS / WebDAV

支持连接 WebDAV 服务，适合 NAS、自建文件服务等场景。

### Emby / Jellyfin

支持连接 Emby / Jellyfin 服务器，读取音乐库、封面、歌词与播放地址。

### Navidrome / Subsonic

支持 Navidrome / Subsonic API，适合自建音乐服务。

## 关于歌词

歌词优先级大致如下：

1. 音乐文件自带歌词
2. 服务器返回歌词
3. 手动选择的歌词来源
4. 网络歌词来源

歌词页支持手动切换歌词来源。

## 注意事项

* 如果修改 `pubspec.yaml` 的 `name`，需要同步修改所有 `package:<旧包名>/...` 的 Dart import。
* 手机桌面显示名称不由 `pubspec.yaml` 的 `name` 控制。
* Android 包名由 `android/app/build.gradle` 的 `applicationId` 控制。
* iOS Bundle ID 由 Xcode 工程配置控制。
* 如果 Android Studio / Gradle 编译内存不足，可以适当增大系统虚拟内存和 Gradle JVM 内存。

## License

This project is for personal and private music library usage.
