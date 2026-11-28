# Release builds are shrunk by R8 (Flutter turns it on). Jetpack Glance runs its
# widget sessions on WorkManager, whose Room database is created by reflection.
# Without these rules R8 renames it and the app crashes at start-up
# ("Failed to create an instance of androidx.work.impl.WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# Glance creates the widget tap handler from its class name.
-keep class * implements androidx.glance.appwidget.action.ActionCallback { <init>(); }
