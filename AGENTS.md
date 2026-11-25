# AGENTS.md — Quy tắc phát triển dự án MirrorDNA (Offline AI Makeup Guide)

Tài liệu này là nguồn chuẩn (Source of Truth) cho mọi AI Coding Agent tham gia viết mã, tái cấu trúc hoặc kiểm thử dự án **MirrorDNA** — ứng dụng gương trang điểm AR, chấm điểm và tái tạo layout cá nhân (**Personal Look Cloning**) chạy **100% Offline trên thiết bị di động**.

---

## 1. Thứ tự đọc tài liệu bắt buộc
Trước khi viết bất kỳ dòng code nào, Agent **phải** đọc theo đúng thứ tự sau:
1. `AGENTS.md` (file này — các ràng buộc bất biến và quy ước kỹ thuật).
2. `docs/01_PRD_AND_UX_FLOWS.md` (yêu cầu sản phẩm, luồng người dùng, UX gương một tay, giới hạn miễn phí/trả phí).
3. `docs/02_ARCHITECTURE_AND_AI_PIPELINE.md` (kiến trúc hệ thống, pipeline MediaPipe + BiSeNet + OpenCV C++, thuật toán hiệu chuẩn ánh sáng và chấm điểm).
4. `docs/03_DATA_SCHEMA_AND_MAKEUP_DNA.md` (cấu trúc JSON của Makeup DNA và schema SQLite cục bộ).
5. `docs/04_IMPLEMENTATION_PLAN.md` (lộ trình triển khai từng phase và tiêu chí hoàn thành DoD).

---

## 2. Các ràng buộc bất biến (Non-Negotiable Constraints)

### 2.1. 100% Offline cho toàn bộ lõi AI & Hình ảnh
* **CẤM** gọi bất kỳ API Cloud AI, LLM hay máy chủ từ xa nào để xử lý ảnh khuôn mặt, trích xuất Makeup DNA hoặc chấm điểm trang điểm.
* Mọi ảnh khuôn mặt và tệp JSON Makeup DNA chỉ được lưu cục bộ trong sandbox ứng dụng.
* Kết nối mạng **chỉ** được phép dùng cho: xác thực thanh toán In-App Purchase (RevenueCat) và gửi báo cáo lỗi kỹ thuật không chứa ảnh (Firebase Crashlytics). Ứng dụng phải vận hành trơn tru ở chế độ Máy bay (Airplane Mode).

### 2.2. Ngân sách Nhiệt độ & Pin (Thermal & Battery Budget)
* **MediaPipe Face Landmarker** (478 điểm mốc 3D) khi chạy ở chế độ gương trực tiếp phải giới hạn tốc độ suy luận ở mức **15–20 FPS** (trong khi luồng hiển thị camera duy trì 30–60 FPS).
* **BiSeNet (Face Parsing)** **TUYỆT ĐỐI KHÔNG** chạy liên tục trên từng khung hình video. Chỉ kích hoạt BiSeNet **theo yêu cầu (on-demand)** tại 2 thời điểm:
  1. Khi người dùng nhập một ảnh mẫu mới để trích xuất Makeup DNA.
  2. Khi người dùng nhấn nút **"Chấm điểm"** tại một trạm (Lông mày / Mắt / Má hồng / Môi).
* Mọi phép toán ma trận ảnh (chuyển đổi CIELAB, tính $\Delta E_{2000}$, lọc Sobel/Laplacian, tính IoU) **phải** viết bằng **C++ (OpenCV)** và gọi qua **Dart FFI**, không viết vòng lặp xử lý pixel bằng Dart.

### 2.3. Dung lượng & Hiệu năng mục tiêu
* Dung lượng bản cài đặt (APK/IPA) tối đa: dưới 70 MB (đã bao gồm model lượng tử hóa INT8/FP16 và OpenCV).
* Độ trễ suy luận BiSeNet + Scoring C++ cho 1 lần bấm chấm điểm: dưới 400 ms trên thiết bị tầm trung (iPhone 11 / Snapdragon 680).

---

## 3. Tech Stack cố định
* **UI Framework:** Flutter (Dart 3.x, null-safety nghiêm ngặt).
* **State Management:** Riverpod (`flutter_riverpod` + `riverpod_annotation`).
* **Navigation:** `go_router`.
* **Local Database:** SQLite qua `drift` (code-gen type-safe) + lưu ảnh nén chuẩn `WebP`.
* **Native Camera & GPU AR:** Android (`CameraX` + `OpenGL ES 3.0`), iOS (`AVFoundation` + `Metal`) giao tiếp qua Platform Channel / Flutter `Texture`.
* **AI Runtime On-Device:**
  * Face Landmarker: Google MediaPipe Tasks Vision (Native Android/iOS SDK).
  * Face Parsing: BiSeNet (CelebAMask-HQ, quantized INT8) chạy qua `ONNX Runtime Mobile` (hoặc `LiteRT`).
* **CV & Scoring Core:** C++17 + OpenCV (mobile static/shared lib) kết nối qua `dart:ffi` + `ffigen`.
* **Monetization:** `purchases_flutter` (RevenueCat SDK).

---

## 4. Cấu trúc thư mục chuẩn (Project Structure)

```text
mirror_dna/
├── AGENTS.md
├── docs/
│   ├── 01_PRD_AND_UX_FLOWS.md
│   ├── 02_ARCHITECTURE_AND_AI_PIPELINE.md
│   ├── 03_DATA_SCHEMA_AND_MAKEUP_DNA.md
│   └── 04_IMPLEMENTATION_PLAN.md
├── assets/
│   ├── models/
│   │   ├── face_landmarker.task
│   │   └── bisenet_celebamask_int8.onnx
│   └── presets/
│       └── *.dna.json              # 10 layout mẫu đóng gói sẵn
├── native/
│   └── cv_engine/                  # Lõi C++17 + OpenCV dùng chung Android & iOS
│       ├── CMakeLists.txt
│       ├── include/
│       │   └── cv_engine_api.h     # C ABI export cho Dart FFI
│       ├── src/
│       │   ├── color_calibration.cpp
│       │   ├── delta_e2000.cpp
│       │   ├── geometry_iou.cpp
│       │   ├── blending_metrics.cpp
│       │   ├── dna_extractor.cpp
│       │   └── scoring_engine.cpp
│       └── tests/                  # GoogleTest cho lõi C++
├── lib/
│   ├── main.dart
│   ├── app/                        # Router, Theme, DI providers
│   ├── core/
│   │   ├── ffi/                    # Dart FFI bindings tới cv_engine
│   │   ├── database/               # Drift tables, DAOs, migrations
│   │   ├── storage/                # Quản lý tệp WebP và Makeup DNA JSON
│   │   └── monetization/           # RevenueCat entitlement wrapper
│   └── features/
│       ├── vault/                  # Kho Makeup DNA cá nhân & Preset
│       ├── enrollment/             # Luồng nhập ảnh cũ -> trích xuất DNA
│       ├── calibration/            # Luồng hiệu chuẩn mặt mộc 2 giây
│       ├── mirror_ar/              # Màn hình gương AR, Ghost Overlay, HUD
│       ├── scoring/                # Chấm điểm từng trạm, gợi ý sửa lỗi
│       └── paywall/                # Gói Free vs Pro
├── android/                        # CameraX, MediaPipe, OpenGL ES shader, CMake NDK
├── ios/                            # AVFoundation, MediaPipe, Metal shader, Podspec/XCFramework
└── test/                           # Unit & Widget tests (Dart)
```

---

## 5. Quy trình làm việc cho AI Agent (Agent Execution Protocol)
1. **Làm cuốn chiếu từng Task:** Chỉ triển khai 1 Task trong `docs/04_IMPLEMENTATION_PLAN.md` tại một thời điểm. Không tự ý thêm tính năng ngoài đặc tả.
2. **Viết Test đi kèm Code:**
   * Mọi hàm toán học trong `native/cv_engine/` (CIELAB, $\Delta E_{2000}$, IoU, Sobel blending, mapping điểm) bắt buộc có unit test bằng GoogleTest.
   * Mọi repository, JSON serializer và rule sinh gợi ý sửa lỗi bằng Dart bắt buộc có unit test trong `test/`.
3. **Không bịa dữ liệu mô hình:** Khi chưa có tệp nhị phân `.onnx` hoặc `.task` trong môi trường dev, phải tạo tầng `MockInferenceEngine` qua dependency injection để chạy kiểm thử luồng UI và FFI độc lập, ghi rõ `// TODO(model-asset)` ở điểm nạp file.
4. **Kiểm tra trước khi báo xong:** Chạy `dart analyze`, `flutter test`, và build kiểm tra C++ (`ctest`) sau mỗi thay đổi. Báo cáo ngắn gọn các file đã tạo/sửa và kết quả test.