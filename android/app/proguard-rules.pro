# Keep Flutter / app widget classes used through Android reflection.
-keep class io.flutter.embedding.** { *; }
-keep class com.chatlee.aimusic.MusicWidget { *; }
-keep class com.chatlee.aimusic.DynamicColorUtils { *; }

# Keep model classes accessed by generated/platform code.
-keep class com.chatlee.aimusic.** { *; }
