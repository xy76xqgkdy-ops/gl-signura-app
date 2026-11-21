// Kein Browser: kein Web-Push.
Future<Map<String, String>> webPushEnable(String key) async => {
  'status': 'unsupported',
};
Future<Map<String, String>> webPushSync(String key) async => {'status': 'skip'};
Future<void> webPushDisable() async {}
