import 'package:shared_preferences/shared_preferences.dart';

/// [SharedPreferences] backed by an in-memory store, for overriding `sharedPreferencesProvider`.
Future<SharedPreferences> fakePreferences([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
