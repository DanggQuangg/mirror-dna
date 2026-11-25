import 'dart:ffi';
import 'dart:io';

import 'cv_engine_bindings.g.dart';

CvEngineBindings openCvEngine() {
  if (Platform.isAndroid) {
    return CvEngineBindings(DynamicLibrary.open('libcv_engine.so'));
  }
  if (Platform.isIOS) {
    return CvEngineBindings(
      DynamicLibrary.open('@rpath/cv_engine.framework/cv_engine'),
    );
  }
  throw UnsupportedError('MirrorDNA requires Android or iOS.');
}
