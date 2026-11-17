import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';

void main() {
  test('the database keeps its file name so existing installs keep their data', () {
    // drift_flutter stores native databases as `<databaseDirectory>/<name>.sqlite`; versions up to 1.2.0 used
    // `<app documents>/focused_task.sqlite`.
    expect(databaseName, 'focused_task');
  });
}
