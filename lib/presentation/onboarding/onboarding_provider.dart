import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/sms_parser_service.dart';
import 'package:telephony/telephony.dart';

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
  PermissionsNotifier() : super({'sms': false, 'notification': false});

  Future<void> requestSms() async {
    final s = await Permission.sms.request();
    state = {...state, 'sms': s.isGranted};
  }

  Future<void> requestNotification() async {
    final s = await Permission.notification.request();
    state = {...state, 'notification': s.isGranted};
  }
}

final smsImportProvider = FutureProvider.family<int, bool>((ref, run) async {
  if (!run) return 0;
  final telephony = Telephony.instance;
  final since = DateTime.now().subtract(const Duration(days: 90));
  final msgs = await telephony.getInboxSms(
    filter: SmsFilter.where(SmsColumn.DATE)
        .greaterThanOrEqualTo(since.millisecondsSinceEpoch.toString()),
  );
  final parser = SmsParserService();
  return msgs.where((m) => parser.parse(m.body ?? '') != null).length;
});
