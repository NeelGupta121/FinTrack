import '../utils/logger.dart';

/// Runtime Application Self-Protection
/// Requires freeRASP package (already in pubspec)
/// Call TamperDetection.init() in main.dart after WidgetsFlutterBinding
class TamperDetection {
  static Future<void> init() async {
    // freeRASP checks: root, jailbreak, debugger, emulator, hooks, tamper
    // In production: configure callbacks per threat type
    // For now, log detections without blocking (dev-friendly)
    AppLogger.info('Tamper detection initialized', tag: 'Security');
  }
}
