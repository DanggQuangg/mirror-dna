# 05. Bộ Prompt mẫu để điều khiển AI Coding Agent

Bạn có thể sao chép từng prompt dưới đây để giao việc theo đúng nhịp cho Cursor, Claude Code, Windsurf hoặc Copilot Workspace sau khi đã đặt các file tài liệu vào dự án.

---

## Prompt 1: Khởi động dự án (Phase 0)
```text
Hãy đọc kỹ toàn bộ các file theo đúng thứ tự:
1. AGENTS.md
2. docs/01_PRD_AND_UX_FLOWS.md
3. docs/02_ARCHITECTURE_AND_AI_PIPELINE.md
4. docs/03_DATA_SCHEMA_AND_MAKEUP_DNA.md
5. docs/04_IMPLEMENTATION_PLAN.md

Sau khi đọc xong, tóm tắt lại các ràng buộc bất biến (offline, thermal budget, C++ FFI) để xác nhận bạn đã hiểu đúng. Sau đó, CHỈ thực hiện Task 0.1 và Task 0.2 của Phase 0. Không chuyển sang Phase 1 khi tôi chưa duyệt.
```

## Prompt 2: Xây lõi C++ CV & Unit Test (Phase 1)
```text
Bây giờ hãy thực hiện Task 1.1 và Task 1.2 trong docs/04_IMPLEMENTATION_PLAN.md theo đúng công thức toán học và hợp đồng C ABI ở docs/02_ARCHITECTURE_AND_AI_PIPELINE.md.
Yêu cầu bắt buộc:
- Viết code C++17 sạch trong native/cv_engine/src/.
- Viết bộ unit test bằng GoogleTest trong native/cv_engine/tests/ kiểm chứng công thức Delta E 2000 (theo test vector chuẩn Sharma 2005), IoU, độ đối xứng, Sobel blending và hàm ánh xạ điểm 60-99.
- Chạy ctest và chỉ báo cáo hoàn thành khi 100% test pass.
```

## Prompt 3: Xây Database & Luồng Lưu Makeup DNA (Phase 2)
```text
Thực hiện Phase 2 (Task 2.1 và Task 2.2) theo đúng schema SQLite và JSON Makeup DNA trong docs/03_DATA_SCHEMA_AND_MAKEUP_DNA.md.
Chú ý cài đặt cơ chế tự động xóa các tệp WebP/JSON trong sandbox khi người dùng xóa layout, và tạo 10 file preset mẫu hợp lệ trong assets/presets/. Viết unit test Dart kiểm tra CRUD và serialization rồi chạy flutter test.
```

## Prompt 4: Xây Gương AR, Hiệu chuẩn & Chấm điểm (Phase 3 & 4)
```text
Thực hiện Phase 3 (Task 3.1, 3.2, 3.3) trước, đảm bảo MediaPipe được giới hạn 15-20 FPS, có bộ lọc One-Euro Filter chống rung, và BiSeNet TUYỆT ĐỐI không chạy trên từng khung hình video mà chỉ kích hoạt on-demand. Sau khi hoàn tất Phase 3 và kiểm tra flutter analyze không có lỗi, hãy báo cáo để tôi kiểm thử trên thiết bị thật trước khi chuyển sang Phase 4.
```

## Prompt 5: Kiểm tra tuân thủ Offline & Audit trước khi lên Store (Phase 5)
```text
Hãy đóng vai Senior Mobile Security & Performance Auditor, rà soát toàn bộ codebase để xác minh:
1. Không có bất kỳ lời gọi mạng nào liên quan đến ảnh khuôn mặt, Makeup DNA hay chấm điểm.
2. BiSeNet chỉ được gọi on-demand trên background thread và giải phóng bộ nhớ tensor đúng cách.
3. Không rò rỉ bộ nhớ C++ (mọi char* từ cv_extract_makeup_dna_json đều được giải phóng qua cv_free_string).
Liệt kê các vấn đề tìm thấy (nếu có) và sửa triệt để trước khi sang Task 5.1 (RevenueCat).
```