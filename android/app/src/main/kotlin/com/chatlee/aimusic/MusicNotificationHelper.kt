package com.chatlee.aimusic

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import java.io.File

object MusicNotificationHelper {
    private const val CHANNEL_ID = "music_playback"
    private const val NOTIFICATION_ID = 20260530
    private var mediaSession: MediaSessionCompat? = null

    fun update(
        context: Context,
        title: String?,
        artist: String?,
        source: String?,
        isPlaying: Boolean,
        coverUrl: String?
    ) {
        if (title.isNullOrBlank()) {
            cancel(context)
            return
        }

        ensureChannel(context)

        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            pendingIntentFlags()
        )

        val previousIntent = actionIntent(context, "PREVIOUS", 1)
        val playPauseIntent = actionIntent(context, "PLAY_PAUSE", 2)
        val nextIntent = actionIntent(context, "NEXT", 3)
        val session = ensureMediaSession(context)
        val coverBitmap = loadCoverBitmap(coverUrl)
        updateMediaSession(session, title, artist, source, isPlaying, coverBitmap)

        val contentArtist = if (artist.isNullOrBlank()) source ?: "Music" else artist
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(title)
            .setContentText(contentArtist)
            .setContentIntent(contentIntent)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setOngoing(isPlaying)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_media_previous, "上一首", previousIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "暂停" else "播放",
                playPauseIntent
            )
            .addAction(android.R.drawable.ic_media_next, "下一首", nextIntent)
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )

        if (coverBitmap != null) {
            builder.setLargeIcon(coverBitmap)
        }

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ notification permission may not be granted yet.
        }
    }

    fun cancel(context: Context) {
        mediaSession?.isActive = false
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun ensureMediaSession(context: Context): MediaSessionCompat {
        val existing = mediaSession
        if (existing != null) return existing
        val session = MediaSessionCompat(context.applicationContext, "MusicPlaybackSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = sendAction(context, "PLAY_PAUSE")
                override fun onPause() = sendAction(context, "PLAY_PAUSE")
                override fun onSkipToPrevious() = sendAction(context, "PREVIOUS")
                override fun onSkipToNext() = sendAction(context, "NEXT")
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
        cover: Bitmap?
    ) {
        session.isActive = true
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist ?: source ?: "Music")
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, source ?: "Music")
        if (cover != null) {
            metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, cover)
            metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, cover)
        }
        session.setMetadata(metadata.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT
                )
                .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .build()
        )
    }

    private fun loadCoverBitmap(coverUrl: String?): Bitmap? {
        if (coverUrl.isNullOrBlank()) return null
        return try {
            when {
                coverUrl.startsWith("file://") -> BitmapFactory.decodeFile(Uri.parse(coverUrl).path)
                coverUrl.startsWith("/") -> BitmapFactory.decodeFile(File(coverUrl).absolutePath)
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun sendAction(context: Context, action: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context, requestCode, intent, pendingIntentFlags())
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
        }
        manager.createNotificationChannel(channel)
    }
}
