# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

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

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ============================================
# Keep all native handler classes and methods
# ============================================

# Keep FlutterHandlerRegistrar and all its methods
-keep class com.example.qc.FlutterHandlerRegistrar { *; }

# Keep MainActivity
-keep class com.example.qc.MainActivity { *; }

# Keep all handler classes and their methods
-keep class com.example.qc.handlers.** { *; }

# Keep all handler classes with their public methods
-keepclassmembers class com.example.qc.handlers.** {
    public *;
    protected *;
}

# Keep method call handlers
-keepclassmembers class com.example.qc.handlers.** {
    public void handleMethodCall(io.flutter.plugin.common.MethodCall, io.flutter.plugin.common.MethodChannel$Result);
}

# Keep event channel stream handlers
-keepclassmembers class com.example.qc.handlers.** {
    public void setEventSink(io.flutter.plugin.common.EventChannel$EventSink);
}

# Keep MethodChannel and EventChannel usage
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.MethodCall { *; }
-keep class io.flutter.plugin.common.MethodChannel$Result { *; }
-keep class io.flutter.plugin.common.EventChannel$EventSink { *; }

# Keep all classes in com.example.qc package
-keep class com.example.qc.** { *; }

# Keep all Activities (including TouchActivity)
-keep class com.example.qc.**Activity { *; }
-keep class com.example.qc.Activity.** { *; }

# Keep all constructors for handlers (needed for instantiation)
-keepclassmembers class com.example.qc.handlers.** {
    <init>(android.app.Activity);
    <init>(...);
}

# Keep all handler instance methods (not just public)
-keepclassmembers class com.example.qc.handlers.** {
    *;
}

# Keep lambda expressions used in method channels
-keepclassmembers class * {
    void lambda$*(...);
}

# Keep anonymous classes used in event channels
-keepclassmembers class * {
    void onListen(...);
    void onCancel(...);
}

# Keep all native Android classes used by handlers
-keep class android.content.BroadcastReceiver { *; }
-keep class android.content.IntentFilter { *; }
-keep class android.os.BatteryManager { *; }
-keep class android.net.wifi.WifiManager { *; }
-keep class android.bluetooth.** { *; }
-keep class android.hardware.fingerprint.** { *; }
-keep class androidx.biometric.** { *; }

# Keep Settings classes for brightness control
-keep class android.provider.Settings { *; }
-keep class android.provider.Settings$System { *; }
-keep class android.provider.Settings$Secure { *; }
-keep class android.provider.Settings$Global { *; }
-keepclassmembers class android.provider.Settings$System {
    public static final ** SCREEN_BRIGHTNESS*;
    public static final ** SCREEN_BRIGHTNESS_MODE*;
    public static boolean canWrite(android.content.Context);
    public static int getInt(android.content.ContentResolver, java.lang.String, int);
    public static int putInt(android.content.ContentResolver, java.lang.String, int);
}

# Keep Intent classes and actions for WRITE_SETTINGS permission
-keep class android.content.Intent { *; }
-keepclassmembers class android.content.Intent {
    public static final java.lang.String ACTION_MANAGE_WRITE_SETTINGS;
    public static final java.lang.String ACTION_APPLICATION_DETAILS_SETTINGS;
    public static final java.lang.String ACTION_SETTINGS;
}
-keep class android.net.Uri { *; }
-keepclassmembers class android.net.Uri {
    public static android.net.Uri parse(java.lang.String);
}

# Keep ContentResolver for Settings access
-keep class android.content.ContentResolver { *; }

# Prevent obfuscation of method names used in MethodChannel
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep reflection-based code
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

