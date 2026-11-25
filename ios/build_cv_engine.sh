#!/bin/sh
set -eu

# Xcode's build environment selects the device/simulator SDK and active slices.
source_dir="$SRCROOT/../native/cv_engine"
build_dir="$PROJECT_TEMP_DIR/mirror_cv/$PLATFORM_NAME"
architectures=$(printf '%s' "$ARCHS" | tr ' ' ';')
cmake -S "$source_dir" -B "$build_dir" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_OSX_ARCHITECTURES="$architectures" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$IPHONEOS_DEPLOYMENT_TARGET" \
  -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE="$build_dir/output" \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build "$build_dir" --config Release --target cv_engine
cmake --install "$build_dir" --config Release --component mirror_dna --prefix "$build_dir/stage"
framework="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/cv_engine.framework"
mkdir -p "$(dirname "$framework")"
ditto "$build_dir/stage/Frameworks/cv_engine.framework" "$framework"
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$framework"
fi
