import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mirror_dna/core/ffi/cv_engine.dart';
import 'package:mirror_dna/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Launches the vault with ABI version 1', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Kho Makeup DNA'), findsOneWidget);
    expect(openCvEngine().cv_engine_abi_version(), 1);
  });
}
