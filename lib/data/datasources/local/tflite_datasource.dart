// Platform-conditional TfliteDatasource.
//
// Mobile/desktop/VM (dart.library.io) get the real TensorFlow Lite
// implementation (tflite_datasource_io.dart, which imports dart:ffi via
// tflite_flutter). Web (dart.library.html) has no dart:ffi, so it gets a no-op
// stub that falls back to 'other'. Unit tests run on the VM and therefore
// exercise the real io implementation.
export 'tflite_datasource_io.dart'
    if (dart.library.html) 'tflite_datasource_web.dart';
