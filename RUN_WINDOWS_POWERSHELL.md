# Windows PowerShell 运行步骤

请把压缩包完整解压成一个新目录，不要只覆盖 `lib`。

```powershell
cd D:\Code\ProJect\spotoolfy_flutter-main

flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\build -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.lock -ErrorAction SilentlyContinue

flutter pub get
flutter analyze
flutter run
```

如果出现 Kotlin 的 `this and base files have different roots`，把 Pub 缓存放到 D 盘后重新打开 PowerShell：

```powershell
setx PUB_CACHE D:\Code\PubCache
```

重新打开 PowerShell 后再执行：

```powershell
cd D:\Code\ProJect\spotoolfy_flutter-main
flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.lock -ErrorAction SilentlyContinue
flutter pub get
flutter run
```
