// Push-Mitteilungen im Browser (Web-Push). Auf Android/iOS (Flutter-App)
// gibt es das hier nicht; die Handy-App ist die Expo-App.
export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
