# Flutter + plugins ship their own consumer rules; keep AdMob and TTS/STT entry points.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.play.core.**
