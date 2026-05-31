# Android 运行修复说明

这版没有替换 Music UI，只修复 Android 构建运行问题。

## 本次修复

1. 保持 Android Gradle Plugin 8.8.0，不强制升级 Gradle。
2. 在 `android/build.gradle` 里强制 AndroidX 兼容版本：
   - `androidx.core:core:1.13.1`
   - `androidx.core:core-ktx:1.13.1`
   - `androidx.browser:browser:1.8.0`
3. 修复 `androidx.browser:browser:1.9.0`、`androidx.core:core/core-ktx:1.17.0` 要求 AGP 8.9.1+ 的问题。
4. 在 `android/gradle.properties` 里关闭 Kotlin 增量编译/daemon，降低 Windows C 盘 Pub Cache + D 盘项目导致的 Kotlin cache roots 报错。
5. 保留 `ndkVersion = "28.2.13676358"`。

## 建议运行命令 PowerShell

```powershell
cd D:\Code\ProJect\spotoolfy_flutter-main

flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\build -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.lock -ErrorAction SilentlyContinue

flutter pub get
flutter run
```

如果仍出现 Kotlin `different roots`，把项目移动到 C 盘，或者设置 Pub Cache 到 D 盘：

```powershell
setx PUB_CACHE D:\Code\PubCache
```

关闭 PowerShell 后重新打开，再执行上面的 clean / pub get / run。
