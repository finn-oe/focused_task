import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every text field closes the keyboard on a tap outside (#56). Flutter's default keeps it open on phones, so a field
/// added without `onTapOutside: unfocusOnTapOutside` would bring the bug back.
void main() {
  test('every TextField / TextFormField in lib uses unfocusOnTapOutside', () {
    final field = RegExp(r'\b(TextField|TextFormField)\(');
    final missing = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      final fields = field.allMatches(source).length;
      final handled = 'onTapOutside: unfocusOnTapOutside'.allMatches(source).length;
      if (fields != handled) missing.add('${file.path}: $fields fields, $handled with onTapOutside');
    }
    expect(missing, isEmpty);
  });
}
