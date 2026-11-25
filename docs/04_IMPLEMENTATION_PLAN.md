# 04. Lộ trình Triển khai chi tiết (Agent Implementation Plan)

Tài liệu này chia nhỏ toàn bộ dự án thành **6 Phase (20 tuần)** với các task nguyên tử để AI Coding Agent có thể thực thi tuần tự, có tiêu chí kiểm thử rõ ràng (Definition of Done - DoD) ở cuối mỗi task.

---

## Phase 0: Khởi tạo dự án & Khung FFI (Tuần 1–2)
* **Task 0.1 — Bootstrap Flutter & Architecture:**
  * Khởi tạo dự án Flutter, cấu hình `riverpod`, `go_router`, `drift`, `freezed`, `json_serializable`, `path_provider`, `image_picker`.
  * Thiết lập cấu trúc thư mục đúng theo `AGENTS.md`.
  * *DoD:* `flutter analyze` và `flutter test` chạy xanh, app mở được màn hình khung trống trên máy ảo Android/iOS.
* **Task 0.2 — C++ CV Engine & Dart FFI Bridge:**
  * Thiết lập `native/cv_engine/CMakeLists.txt` liên kết OpenCV (`core`, `imgproc`) cho cả Android NDK (`arm64-v8a`) và iOS (`arm64`).
  * Định nghĩa `cv_engine_api.h` với hàm stub và sinh Dart FFI binding bằng `ffigen`.
  * *DoD:* Gọi thành công một hàm C++ đơn giản từ Flutter trên cả Android và iOS, GoogleTest chạy xanh trên host machine.

---

## Phase 1: Lõi Thuật toán AI/CV Offline — PoC (Tuần 3–6)
* **Task 1.1 — Chất lượng ảnh & Hiệu chuẩn ánh sáng (C++):**
  * Cài đặt `cv_check_quality` (pose, độ sáng $L^*$, chênh lệch trái–phải, phương sai Laplacian).
  * Cài đặt `cv_compute_anchor_skin` (trích xuất trung vị CIELAB vùng da tham chiếu).
  * *DoD:* Unit test GoogleTest xác minh đúng các case ảnh tối, lệch sáng, mờ, góc nghiêng quá $8^\circ$.
* **Task 1.2 — Động cơ Chấm điểm Màu, Hình dáng & Tán phấn (C++):**
  * Cài đặt đầy đủ công thức CIE `delta_e2000.cpp` (kiểm chứng với bộ test vector chuẩn của Sharma et al. 2005, sai số $< 10^{-4}$).
  * Cài đặt `geometry_iou.cpp` (UV normalization, IoU, đối xứng trái–phải, góc đuôi eyeliner).
  * Cài đặt `blending_metrics.cpp` (dải viền chuyển tiếp + gradient Sobel).
  * Cài đặt `scoring_engine.cpp` và hàm ánh xạ điểm hiển thị $S_{display} \in [60, 99]$.
  * *DoD:* Toàn bộ GoogleTest pass; kiểm thử trên 2 ảnh giống hệt nhau phải trả về $S_{display} \ge 98$, thay đổi màu son/tạo viền gắt làm giảm đúng chỉ số thành phần tương ứng.
* **Task 1.3 — Tích hợp On-Device Inference (MediaPipe + BiSeNet ONNX):**
  * Tích hợp MediaPipe Face Landmarker native (Android/iOS) trả về 478 tọa độ 3D + ma trận xoay đầu.
  * Tích hợp ONNX Runtime Mobile nạp `bisenet_celebamask_int8.onnx` ở chế độ **on-demand** trên luồng nền (background isolate / worker thread).
  * *DoD:* Đo benchmark trên thiết bị thật: MediaPipe dưới 15 ms/frame, BiSeNet + CV Scoring dưới 400 ms/lần bấm.

---

## Phase 2: Kho Makeup DNA, Preset & Luồng Nhập ảnh (Tuần 7–9)
* **Task 2.1 — SQLite Database (Drift) & File Sandbox:**
  * Tạo đầy đủ 5 bảng theo `docs/03_DATA_SCHEMA_AND_MAKEUP_DNA.md`, DAOs và cơ chế tự dọn tệp WebP/JSON khi xóa layout.
  * Tạo bộ nạp 10 Preset đóng gói sẵn từ `assets/presets/` khi khởi chạy lần đầu.
  * *DoD:* Unit test CRUD cho `MakeupLook`, `CosmeticProduct`, `PracticeSession`, xác nhận xóa layout không để lại tệp mồ côi.
* **Task 2.2 — Luồng Enrollment ("Lưu layout đẹp nhất của tôi"):**
  * Cài đặt `cv_extract_makeup_dna_json` sinh JSON Makeup DNA và xuất ảnh `uv_overlay_webp` nén WebP.
  * Xây UI chọn ảnh -> kiểm tra Quality Gate -> hiển thị tiến trình bóc tách -> màn hình đặt tên & gắn thẻ mỹ phẩm.
  * *DoD:* Chọn 1 ảnh selfie từ thư viện tạo ra tệp `.dna.json` dưới 60 KB, ảnh thumbnail WebP, ảnh UV overlay và hiển thị ngay trong Kho cá nhân khi tắt hoàn toàn Wi-Fi.

---

## Phase 3: Gương AR Thông minh, Hiệu chuẩn & Ghost Overlay (Tuần 10–12)
* **Task 3.1 — Native Camera Texture & MediaPipe Throttling:**
  * Xây dựng Native Camera (`CameraX` / `AVFoundation`) render trực tiếp ra Flutter `Texture` mượt 30–60 FPS.
  * Gắn bộ điều tiết (throttler) chỉ đẩy khung hình vào MediaPipe ở 15–20 FPS kèm bộ lọc làm mượt tọa độ **One-Euro Filter**.
  * *DoD:* Giao diện gương mượt, không giật khung, độ trễ bám mặt thấp.
* **Task 3.2 — Luồng Hiệu chuẩn mặt mộc 2 giây:**
  * Xây dựng màn hình/modal hiệu chuẩn có vòng tròn tiến độ 2 giây chỉ chạy khi góc đầu và ánh sáng đồng thời đạt chuẩn xanh.
  * *DoD:* Lưu được `current_anchor_lab` cho phiên hiện tại và cho phép nhấn "Bỏ qua" đúng đặc tả.
* **Task 3.3 — GPU AR Ghost Overlay & Guide Lines:**
  * Viết shader OpenGL ES (Android) và Metal (iOS) phủ tệp `{look_id}_uv.webp` lên 478 đỉnh landmark theo thời gian thực với thanh trượt `opacity` từ 0% đến 50%.
  * Bổ sung chế độ vẽ **Guide Lines** theo từng trạm đang chọn và chế độ **Split Compare**.
  * *DoD:* Khi xoay nhẹ đầu hoặc thay đổi khoảng cách, lớp bóng mờ và đường dẫn hướng bám sát khuôn mặt không bị trễ hay rách lưới.

---

## Phase 4: Chấm điểm từng trạm, Gợi ý sửa lỗi & Hoàn thiện UX (Tuần 13–15)
* **Task 4.1 — Luồng Chấm điểm On-Demand & Tip Generator:**
  * Kết nối nút **"Chấm điểm"** ở màn hình gương -> chụp khung hình sắc nét -> chạy BiSeNet + `cv_score_station` trên background thread -> ánh xạ `tip_code` sang câu tiếng Việt/tiếng Anh tự nhiên.
  * Thiết kế Bottom Sheet kết quả: hiển thị điểm khích lệ, lời khen điểm mạnh nhất, tối đa 2 gợi ý chỉnh sửa cụ thể, và 3 thanh chỉ số thành phần.
  * *DoD:* Bấm chấm điểm cho từng trạm (Lông mày, Mắt, Má hồng, Môi) trả kết quả dưới 0.5 giây và lưu lịch sử vào `practice_sessions` + `station_scores`.
* **Task 4.2 — Thử nghiệm thực địa & Tinh chỉnh hệ số:**
  * Tạo màn hình Developer Debug (ẩn trong bản Release) cho phép xuất ảnh chụp, mask BiSeNet và các chỉ số $\Delta E_{2000}$, IoU, $G_{edge}$ để tinh chỉnh lại $\sigma_c$ và $k_b$ cho sát cảm quan thực tế.
  * *DoD:* Kiểm thử 20 phút sử dụng liên tục trên điện thoại thật không gây quá nhiệt hoặc rớt FPS dưới 24.

---

## Phase 5: Thương mại hóa, Kiểm thử Offline & Phát hành Store (Tuần 16–20)
* **Task 5.1 — RevenueCat Freemium & Offline Cache:**
  * Tích hợp `purchases_flutter`, thiết lập cổng giới hạn gói Free (tối đa 3 layout cá nhân, 5 preset, dùng thử Ghost Overlay 10 giây) và lưu cache trạng thái Pro cục bộ.
  * *DoD:* Mua gói thử nghiệm thành công trên Sandbox (Apple/Google), bật chế độ Máy bay khởi động lại app vẫn giữ nguyên quyền Pro.
* **Task 5.2 — Đóng gói Privacy, ASO & Phát hành:**
  * Xác minh không còn bất kỳ quyền mạng không cần thiết hay log ảnh nhạy cảm; chuẩn bị trang Privacy Policy tĩnh.
  * Chạy **Google Play Closed Testing** (tuyển dự phòng 16–18 tester tham gia liên tục đủ 14 ngày) và **TestFlight** trên iOS.
  * Quay video demo luồng hiệu chuẩn + AR + chấm điểm đính kèm App Review Notes cho Apple.
  * *DoD:* Vượt qua vòng kiểm duyệt và phát hành bản Production trên App Store & Google Play.