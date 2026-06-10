package com.chatlee.aimusic

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.palette.graphics.Palette
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min

object MusicNotificationHelper {
    private const val CHANNEL_ID = "music_playback"
    private const val NOTIFICATION_ID = 20260530
    private const val ACTION_LYRICS = "OPEN_LYRICS"
    private const val ACTION_PREVIOUS = "PREVIOUS"
    private const val ACTION_PLAY = "PLAY"
    private const val ACTION_PAUSE = "PAUSE"
    private const val ACTION_PLAY_PAUSE = "PLAY_PAUSE"
    private const val ACTION_NEXT = "NEXT"
    private const val ACTION_STOP = "STOP"
    private const val ACTION_SEEK_TO = "SEEK_TO"
    private const val EXTRA_POSITION_MS = "positionMs"

    private var mediaSession: MediaSessionCompat? = null
    private var lastCoverPath: String? = null
    private var lastCoverBitmap: Bitmap? = null
    private var lastCoverColor: Int = Color.rgb(55, 38, 33)
    private var controlChannel: MethodChannel? = null

    fun attachControlChannel(channel: MethodChannel?) {
        controlChannel = channel
    }

    fun update(
        context: Context,
        title: String?,
        artist: String?,
        source: String?,
        isPlaying: Boolean,
        coverUrl: String?,
        positionMs: Long?,
        durationMs: Long?
    ) {
        if (title.isNullOrBlank()) {
            cancel(context)
            return
        }

        val appContext = context.applicationContext
        ensureChannel(appContext)

        val contentIntent = PendingIntent.getActivity(
            appContext,
            0,
            Intent(appContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            pendingIntentFlags()
        )

        val lyricsIntent = actionIntent(appContext, ACTION_LYRICS, 0)
        val previousIntent = actionIntent(appContext, ACTION_PREVIOUS, 1)
        val playPauseIntent = actionIntent(appContext, ACTION_PLAY_PAUSE, 2)
        val nextIntent = actionIntent(appContext, ACTION_NEXT, 3)
        val stopIntent = actionIntent(appContext, ACTION_STOP, 4)

        val session = ensureMediaSession(appContext)
        val coverBitmap = loadCoverBitmap(coverUrl)
        val duration = (durationMs ?: 0L).coerceAtLeast(0L)
        val position = normalisePosition(positionMs ?: 0L, duration)
        updateMediaSession(
            session = session,
            title = title,
            artist = artist,
            source = source,
            isPlaying = isPlaying,
            cover = coverBitmap,
            positionMs = position,
            durationMs = duration
        )

        val contentArtist = when {
            !artist.isNullOrBlank() -> artist
            !source.isNullOrBlank() -> source
            else -> "Music"
        }
        val notificationColor = notificationColorFromCover(coverBitmap)

        val builder = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(title)
            .setContentText(contentArtist)
            .setSubText(source ?: "Music")
            .setContentIntent(contentIntent)
            .setDeleteIntent(stopIntent)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setOngoing(isPlaying)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setColor(notificationColor)
            .setColorized(coverBitmap != null)
            // 顺序按 Salt Player：词 / 上一首 / 播放暂停 / 下一首 / 关闭。
            .addAction(R.drawable.ic_lyrics, "词", lyricsIntent)
            .addAction(R.drawable.ic_skip_previous, "上一首", previousIntent)
            .addAction(
                if (isPlaying) R.drawable.ic_pause_filled else R.drawable.ic_play_filled,
                if (isPlaying) "暂停" else "播放",
                playPauseIntent
            )
            .addAction(R.drawable.ic_skip_next, "下一首", nextIntent)
            .addAction(R.drawable.ic_close, "关闭", stopIntent)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    // 收起时只显示上一首 / 播放暂停 / 下一首；展开后显示 5 个动作。
                    .setShowActionsInCompactView(1, 2, 3)
                    .setShowCancelButton(true)
                    .setCancelButtonIntent(stopIntent)
            )

        if (coverBitmap != null) {
            builder.setLargeIcon(coverBitmap)
        }

        if (duration > 0) {
            val maxProgress = min(duration, Int.MAX_VALUE.toLong()).toInt()
            val safeProgress = min(position, maxProgress.toLong()).toInt()
            builder.setProgress(maxProgress, safeProgress, false)
        }

        try {
            NotificationManagerCompat.from(appContext).notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ notification permission may not be granted yet.
        }
    }

    fun cancel(context: Context) {
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0L, 0f)
                .build()
        )
        mediaSession?.isActive = false
        NotificationManagerCompat.from(context.applicationContext).cancel(NOTIFICATION_ID)
    }

    private fun ensureMediaSession(context: Context): MediaSessionCompat {
        val existing = mediaSession
        if (existing != null) return existing

        val appContext = context.applicationContext
        val session = MediaSessionCompat(appContext, "MusicPlaybackSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = sendAction(appContext, ACTION_PLAY)
                override fun onPause() = sendAction(appContext, ACTION_PAUSE)
                override fun onSkipToPrevious() = sendAction(appContext, ACTION_PREVIOUS)
                override fun onSkipToNext() = sendAction(appContext, ACTION_NEXT)
                override fun onStop() = sendAction(appContext, ACTION_STOP)
                override fun onSeekTo(pos: Long) = sendAction(appContext, ACTION_SEEK_TO, pos)

                override fun onCustomAction(action: String?, extras: Bundle?) {
                    when (action) {
                        ACTION_LYRICS -> sendAction(appContext, ACTION_LYRICS)
                        ACTION_STOP -> sendAction(appContext, ACTION_STOP)
                        else -> super.onCustomAction(action, extras)
                    }
                }
            })
            isActive = true
        }
        mediaSession = session
        return session
    }

    private fun updateMediaSession(
        session: MediaSessionCompat,
        title: String,
        artist: String?,
        source: String?,
        isPlaying: Boolean,
        cover: Bitmap?,
        positionMs: Long,
        durationMs: Long
    ) {
        session.isActive = true
        val displayArtist = when {
            !artist.isNullOrBlank() -> artist
            !source.isNullOrBlank() -> source
            else -> "Music"
        }
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, displayArtist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, source ?: "Music")
        if (durationMs > 0) {
            metadata.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
        }
        if (cover != null) {
            metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, cover)
            metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, cover)
        }
        session.setMetadata(metadata.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val playbackPosition = if (durationMs > 0) positionMs else PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN
        val playbackSpeed = if (isPlaying) 1f else 0f
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SEEK_TO or
                        PlaybackStateCompat.ACTION_STOP
                )
                .addCustomAction(
                    PlaybackStateCompat.CustomAction.Builder(
                        ACTION_LYRICS,
                        "词",
                        R.drawable.ic_lyrics
                    ).build()
                )
                .addCustomAction(
                    PlaybackStateCompat.CustomAction.Builder(
                        ACTION_STOP,
                        "关闭",
                        R.drawable.ic_close
                    ).build()
                )
                .setState(state, playbackPosition, playbackSpeed, SystemClock.elapsedRealtime())
                .build()
        )
    }

    private fun loadCoverBitmap(coverUrl: String?): Bitmap? {
        if (coverUrl.isNullOrBlank()) return null
        val coverPath = try {
            when {
                coverUrl.startsWith("file://") -> Uri.parse(coverUrl).path
                coverUrl.startsWith("/") -> File(coverUrl).absolutePath
                else -> null
            }
        } catch (_: Exception) {
            null
        } ?: return null

        val cached = lastCoverBitmap
        if (coverPath == lastCoverPath && cached != null && !cached.isRecycled) {
            return cached
        }

        return try {
            val decoded = BitmapFactory.decodeFile(coverPath) ?: return null
            val scaled = scaleBitmapForNotification(decoded)
            if (scaled !== decoded) decoded.recycle()
            lastCoverPath = coverPath
            lastCoverBitmap = scaled
            lastCoverColor = Color.rgb(55, 38, 33)
            scaled
        } catch (_: Exception) {
            null
        }
    }

    private fun scaleBitmapForNotification(bitmap: Bitmap): Bitmap {
        val maxSize = 640
        val width = bitmap.width
        val height = bitmap.height
        if (width <= maxSize && height <= maxSize) return bitmap

        val ratio = min(maxSize.toFloat() / width.toFloat(), maxSize.toFloat() / height.toFloat())
        val targetWidth = max(1, (width * ratio).toInt())
        val targetHeight = max(1, (height * ratio).toInt())
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
    }

    private fun notificationColorFromCover(cover: Bitmap?): Int {
        if (cover == null) return Color.rgb(55, 38, 33)
        if (cover === lastCoverBitmap && lastCoverColor != Color.rgb(55, 38, 33)) {
            return lastCoverColor
        }
        return try {
            val palette = Palette.from(cover).generate()
            val color = palette.vibrantSwatch?.rgb
                ?: palette.mutedSwatch?.rgb
                ?: palette.darkVibrantSwatch?.rgb
                ?: palette.darkMutedSwatch?.rgb
                ?: palette.dominantSwatch?.rgb
                ?: Color.rgb(55, 38, 33)
            if (cover === lastCoverBitmap) lastCoverColor = color
            color
        } catch (_: Exception) {
            Color.rgb(55, 38, 33)
        }
    }

    private fun normalisePosition(positionMs: Long, durationMs: Long): Long {
        val safePosition = positionMs.coerceAtLeast(0L)
        return if (durationMs > 0) safePosition.coerceAtMost(durationMs) else safePosition
    }

    private fun sendAction(context: Context, action: String, positionMs: Long? = null) {
        val channel = controlChannel
        if (channel != null) {
            when (action) {
                ACTION_PLAY_PAUSE -> channel.invokeMethod("togglePlayPause", null)
                ACTION_PLAY -> channel.invokeMethod("play", null)
                ACTION_PAUSE -> channel.invokeMethod("pause", null)
                ACTION_PREVIOUS -> channel.invokeMethod("skipToPrevious", null)
                ACTION_NEXT -> channel.invokeMethod("skipToNext", null)
                ACTION_SEEK_TO -> channel.invokeMethod("seekToPosition", (positionMs ?: 0L).toInt())
                ACTION_STOP -> channel.invokeMethod("stopPlaybackAndCloseApp", null)
                ACTION_LYRICS -> channel.invokeMethod("openLyrics", null)
            }
            return
        }

        val intent = Intent(context.applicationContext, MainActivity::class.java).apply {
            this.action = action
            if (positionMs != null) putExtra(EXTRA_POSITION_MS, positionMs)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.applicationContext.startActivity(intent)
    }

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context.applicationContext, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context.applicationContext, requestCode, intent, pendingIntentFlags())
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Music 正在播放",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "显示当前正在播放的歌曲"
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
