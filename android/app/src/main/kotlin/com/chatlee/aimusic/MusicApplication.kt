package com.chatlee.aimusic

import io.flutter.app.FlutterApplication
import com.google.android.material.color.DynamicColors

class MusicApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        DynamicColors.applyToActivitiesIfAvailable(this)
    }
} 