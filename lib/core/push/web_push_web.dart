import 'dart:convert';
import 'dart:js_interop';

// Brücke zu web/push.js (window.signuraPush).
@JS('signuraPush.enable')
external JSPromise<JSString> _enable(JSString key);
@JS('signuraPush.sync')
external JSPromise<JSString> _sync(JSString key);
@JS('signuraPush.disable')
external JSPromise<JSString> _disable();

Map<String, String> _parse(String s) =>
    (jsonDecode(s) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));

Future<Map<String, String>> webPushEnable(String key) async =>
    _parse((await _enable(key.toJS).toDart).toDart);

Future<Map<String, String>> webPushSync(String key) async =>
    _parse((await _sync(key.toJS).toDart).toDart);

Future<void> webPushDisable() async {
  await _disable().toDart;
}
