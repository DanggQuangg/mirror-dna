# MirrorDNA

Khung ứng dụng Flutter Android/iOS cho gương hướng dẫn trang điểm ngoại tuyến. Phase 0 mở màn hình Kho Makeup DNA và cung cấp C ABI phiên bản 1. Các hàm xử lý ảnh hiện là stub. Các phép đo chưa có trả về NaN, điểm hiển thị trả về -1 và hàm trích xuất trả về con trỏ null.

## Chạy ứng dụng

Dùng Flutter stable 3.50.1 và Dart 3.14. Chạy `flutter pub get`, sau đó `flutter run -d <device-id>`. Android dùng API 26 trở lên, ABI arm64-v8a, Android NDK theo bản Flutter và SDK CMake 3.22.1. iOS dùng Xcode trên macOS, iOS 15 trở lên và CMake trong PATH của Xcode.

CMake tải mã nguồn OpenCV 4.10.0 ở lần build mobile đầu và biên dịch hai module core, imgproc. Có thể dùng mã nguồn đã tải bằng tùy chọn CMake `FETCHCONTENT_SOURCE_DIR_OPENCV`. Khi chạy, ứng dụng dùng thư viện đã đóng gói trên thiết bị.

## Kiểm tra Phase 0

```sh
dart analyze
flutter analyze
flutter test
flutter test integration_test/native_bridge_test.dart -d <device-id>
```

Chạy integration test trên từng nền tảng để kiểm tra màn hình khởi động và lời gọi Dart vào thư viện native đã đóng gói. Để chạy GoogleTest trên Linux có CMake, trình biên dịch C++17, OpenCV core/imgproc và GoogleTest, dùng các lệnh sau.

```sh
cmake -S native/cv_engine -B build/native
cmake --build build/native
ctest --test-dir build/native --output-on-failure
```

Khi thay đổi C ABI, dùng LLVM/libclang và chạy `dart run ffigen --config ffigen.yaml` để cập nhật bindings.
