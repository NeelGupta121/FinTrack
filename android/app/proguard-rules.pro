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

# PdfBox-Android (via read_pdf_text) references an optional JPEG2000 decoder
# (com.gemalto.jp2) that isn't bundled. JP2-encoded images in PDFs simply won't
# decode; text extraction is unaffected. Suppress the R8 missing-class error.
-dontwarn com.gemalto.jp2.**
-dontwarn com.tom_roush.pdfbox.**
-keep class com.tom_roush.pdfbox.** { *; }
