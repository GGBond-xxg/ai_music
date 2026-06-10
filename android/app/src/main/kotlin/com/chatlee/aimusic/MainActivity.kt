package com.chatlee.aimusic

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private val pendingPlaybackActions = mutableListOf<PendingPlaybackAction>()
    private val mainHandler = Handler(Looper.getMainLooper())

    private data class PendingPlaybackAction(
        val action: String,
        val positionMs: Long? = null
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun closeAppFromNotification() {
        // 通知栏右侧 X 的语义：停止播放并关闭当前 App 任务，而不只是暂停。
        mainHandler.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                finishAndRemoveTask()
            } else {
                finish()
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.action ?: return
        val positionMs = if (intent.hasExtra("positionMs")) {
            intent.getLongExtra("positionMs", 0L)
        } else {
            null
        }
        dispatchPlaybackAction(action, positionMs)
    }

    private fun dispatchPlaybackAction(action: String, positionMs: Long? = null) {
        val channel = methodChannel
        if (channel == null) {
            pendingPlaybackActions.add(PendingPlaybackAction(action, positionMs))
            return
        }

        when (action) {
            "PLAY_PAUSE" -> channel.invokeMethod("togglePlayPause", null)
            "PLAY" -> channel.invokeMethod("play", null)
            "PAUSE" -> channel.invokeMethod("pause", null)
            "PREVIOUS" -> channel.invokeMethod("skipToPrevious", null)
            "NEXT" -> channel.invokeMethod("skipToNext", null)
            "SEEK_TO" -> channel.invokeMethod("seekToPosition", (positionMs ?: 0L).toInt())
            "STOP" -> channel.invokeMethod("stopPlaybackAndCloseApp", null)
            "OPEN_LYRICS" -> channel.invokeMethod("openLyrics", null)
        }
    }

    private fun flushPendingPlaybackActions() {
        if (pendingPlaybackActions.isEmpty()) return
        val actions = pendingPlaybackActions.toList()
        pendingPlaybackActions.clear()

        // 给 Dart 侧 MethodChannel 留一点初始化时间，避免冷启动时通知栏按钮丢指令。
        mainHandler.postDelayed({
            actions.forEach { dispatchPlaybackAction(it.action, it.positionMs) }
        }, 300L)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Widget 控制通道，同时也承接系统媒体通知栏按钮回调。
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.chatlee.aimusic/widget")
        MusicNotificationHelper.attachControlChannel(methodChannel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "closeApp" -> {
                    closeAppFromNotification()
                    result.success(null)
                }
                "updateWidget" -> {
                    val songName = call.argument<String>("songName")
                    val artistName = call.argument<String>("artistName")
                    val albumArtUrl = call.argument<String>("albumArtUrl")
                    val isPlaying = call.argument<Boolean>("isPlaying")
                    
                    // 获取所有小部件ID并更新
                    val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(
                        android.content.ComponentName(this, MusicWidget::class.java)
                    )
                    
                    // 更新所有小部件
                    for (appWidgetId in appWidgetIds) {
                        MusicWidget.updateAppWidget(
                            context = this,
                            appWidgetManager = appWidgetManager,
                            appWidgetId = appWidgetId,
                            songName = songName,
                            artistName = artistName,
                            albumArtUrl = albumArtUrl,
                            isPlaying = isPlaying ?: false
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        flushPendingPlaybackActions()
        

        // 播放通知通道
        val playbackNotificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "music_playback_notification")
        playbackNotificationChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    MusicNotificationHelper.update(
                        context = this,
                        title = call.argument<String>("title"),
                        artist = call.argument<String>("artist"),
                        source = call.argument<String>("source"),
                        isPlaying = call.argument<Boolean>("isPlaying") ?: false,
                        coverUrl = call.argument<String>("coverUrl"),
                        positionMs = call.argument<Number>("positionMs")?.toLong(),
                        durationMs = call.argument<Number>("durationMs")?.toLong()
                    )
                    result.success(null)
                }
                "cancel" -> {
                    MusicNotificationHelper.cancel(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 语言设置通道
        val languageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "language_channel")
        languageChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAppLocale" -> {
                    try {
                        val languageTag = call.argument<String>("languageTag")
                        if (languageTag != null) {
                            val localeList = LocaleListCompat.forLanguageTags(languageTag)
                            AppCompatDelegate.setApplicationLocales(localeList)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "Language tag is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("SET_LOCALE_ERROR", e.message, null)
                    }
                }
                "clearAppLocale" -> {
                    try {
                        AppCompatDelegate.setApplicationLocales(LocaleListCompat.getEmptyLocaleList())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_LOCALE_ERROR", e.message, null)
                    }
                }
                "openSystemLanguageSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val intent = Intent(android.provider.Settings.ACTION_APP_LOCALE_SETTINGS).apply {
                                data = android.net.Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("UNSUPPORTED", "System language settings not supported on this Android version", null)
                        }
                    } catch (e: Exception) {
                        result.error("OPEN_SETTINGS_ERROR", e.message, null)
                    }
                }
                "supportsSystemLanguageSettings" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        MusicNotificationHelper.attachControlChannel(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
