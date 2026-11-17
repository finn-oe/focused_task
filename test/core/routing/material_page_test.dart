import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Regression: go_router < 18 only recognised the deprecated SDK MaterialApp and fell back to pages without transitions.
  testWidgets('go_router builds Material pages under the material_ui MaterialApp', (tester) async {
    Page<Object?>? page;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            page = ModalRoute.of(context)?.settings as Page<Object?>?;
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(page, isA<MaterialPage<Object?>>());
  });
}
