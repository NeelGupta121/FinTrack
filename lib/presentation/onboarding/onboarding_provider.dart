import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

const _key = 'onboarding_complete';

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_key) ?? false;
});

Future<void> setOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key, true);
}

final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, Map<String, bool>>(
        (ref) => PermissionsNotifier());

class PermissionsNotifier extends StateNotifier<Map<String, bool>> {
  PermissionsNotifier() : super({'notification': false});

  Future<void> requestNotification() async {
    final s = await Permission.notification.request();
    state = {...state, 'notification': s.isGranted};
  }
}
