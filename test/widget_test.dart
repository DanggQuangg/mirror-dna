import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_dna/app/app.dart';
import 'package:mirror_dna/core/ffi/inference_engine.dart';

void main() {
  testWidgets('Opens the vault without model assets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MirrorDnaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Kho Makeup DNA'), findsOneWidget);
  });

  test('Inference is unavailable until local models are bundled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(inferenceEngineProvider).modelsAvailable, isFalse);
  });
}
