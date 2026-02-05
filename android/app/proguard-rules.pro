# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Solana Mobile Client
-keep class com.solana.** { *; }
-keep class com.solanamobile.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# App Links
-keep class com.llfbandit.app_links.** { *; }

# Crypto / PineNaCl / TweetNaCl
-keep class org.libsodium.** { *; }
-keep class com.goterl.lazysodium.** { *; }
-keep class pinenacl.** { *; }
-keep class tweetnacl.** { *; }
-dontwarn org.libsodium.**
-dontwarn pinenacl.**

# Keep Dart/Flutter crypto classes
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class * {
    @com.sun.jna.** *;
}

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of needed classes
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit

# Play Core (deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
