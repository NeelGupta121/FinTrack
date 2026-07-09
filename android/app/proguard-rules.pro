# Keep MLKit text recognition language-specific classes (referenced dynamically)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }

# Keep TFLite GPU delegate (referenced dynamically)
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.** { *; }

# freeRASP
-keep class com.aheaditec.** { *; }

# AndroidX Window extensions/sidecar (optional; not present on all devices)
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
