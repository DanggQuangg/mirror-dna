import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class InferenceEngine {
  bool get modelsAvailable;
}

class MockInferenceEngine implements InferenceEngine {
  const MockInferenceEngine();

  @override
  bool get modelsAvailable => false;
}

final inferenceEngineProvider = Provider<InferenceEngine>((ref) {
  // TODO(model-asset): Load bundled models here when native inference is ready.
  return const MockInferenceEngine();
});
