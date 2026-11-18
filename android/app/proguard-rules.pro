# --- Room / WorkManager (pulled in by Google Mobile Ads) ---------------------
# Room instantiates generated *_Impl database classes by reflection. R8 full
# mode (AGP 9 default) strips them, crashing at startup with:
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }
-keepnames class androidx.work.** extends androidx.work.ListenableWorker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# --- Google Mobile Ads / UMP and Firebase -----------------------------------
# These ship consumer rules; keep the reflective entry points explicitly too.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.**
