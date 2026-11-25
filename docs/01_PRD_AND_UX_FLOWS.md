# 01. Đặc tả Sản phẩm & Luồng Người Dùng (PRD & UX Flows)

## 1. Tầm nhìn sản phẩm & Điểm khác biệt (USP)
**MirrorDNA** giải quyết hai vấn đề lớn nhất của người tự trang điểm:
1. **Không nhớ cách tái tạo lại lần trang điểm đẹp nhất của chính mình** (Personal Look Cloning): Người dùng chọn bức ảnh selfie cũ từng ưng ý nhất, ứng dụng bóc tách "Makeup DNA" và hướng dẫn trực tiếp trên gương AR để trang điểm lại y hệt.
2. **Bảo mật tuyệt đối & Không phụ thuộc Internet**: Toàn bộ quá trình phân tích, dẫn hướng và chấm điểm chạy 100% offline trên thiết bị. Không tải ảnh mặt mộc lên máy chủ.

### Cấu hình hỗ trợ tối thiểu
* **iOS:** iOS 15.0+, từ iPhone 11 trở lên.
* **Android:** Android 8.0 (API 26)+, RAM từ 4 GB, chip tương đương Snapdragon 680 / Dimensity 700 trở lên.

---

## 2. Các luồng người dùng cốt lõi (Core User Flows)

### Luồng A: Lưu "Makeup DNA" từ ảnh đẹp nhất (Enrollment Flow)
1. Người dùng nhấn nút **"Lưu layout của tôi"** ở màn hình chính và chọn 1 ảnh chân dung từ thư viện (hoặc chụp ngay sau khi trang điểm xong).
2. **Kiểm tra chất lượng ảnh đầu vào (Auto Gate):**
   * Xác minh ảnh có đúng 1 khuôn mặt rõ nét.
   * Góc xoay đầu nằm trong ngưỡng chấp nhận (Yaw/Pitch trong khoảng $\pm 15^\circ$ cho ảnh lưu mẫu).
   * Không bị che khuất mắt/môi bởi kính râm hoặc tay.
   * Nếu không đạt: hiển thị thông báo cụ thể lý do và cho chọn ảnh khác.
3. **Trích xuất Makeup DNA (Offline ~0.5–1 giây):**
   * Chạy MediaPipe Face Landmarker + BiSeNet + OpenCV C++.
   * Bóc tách dáng lông mày, đường eyeliner, vùng phấn mắt, má hồng, viền môi (tọa độ chuẩn hóa UV) và bảng màu CIELAB tương đối so với vùng da nền.
   * Cắt và nén ảnh tham chiếu + ảnh texture vùng trang điểm sang định dạng WebP.
4. **Gắn thông tin cá nhân hóa:**
   * Đặt tên layout (ví dụ: *"Đi tiệc tối 20/10"*, *"Makeup trong veo đi làm"*).
   * Tùy chọn ghi chú nhanh tên/mã mỹ phẩm đã dùng cho từng bộ phận (Son, Phấn má, Bảng mắt, Kẻ mắt).
5. Lưu vào **Kho Makeup DNA** cục bộ (SQLite + file JSON ~30–50 KB).

### Luồng B: Tái tạo lại layout & Chấm điểm từng trạm (Recreate & Score Flow)
1. Người dùng chọn 1 layout từ **Kho cá nhân** hoặc từ **10 Preset mặc định**.
2. **Bước 1 — Hiệu chuẩn mặt mộc 2 giây (Bare-Face Calibration):**
   * Mở camera trước với khung oval căn chỉnh khuôn mặt.
   * HUD kiểm tra 2 điều kiện thời gian thực:
     * Góc nghiêng đầu (Pitch, Yaw, Roll) dưới $8^\circ$.
     * Độ sáng khuôn mặt đủ và đều (không ngược sáng gắt hoặc tối một bên).
   * Khi cả hai chỉ báo chuyển xanh, đếm ngược tự động 2 giây để đo cân bằng trắng và màu da nền mặt mộc thực tế của căn phòng.
   * *(Có nút "Bỏ qua hiệu chuẩn" cho người đang dặm lại giữa chừng, kèm cảnh báo nhỏ rằng độ chuẩn màu sẽ giảm nhẹ).*
3. **Bước 2 — Gương thông minh & AR Ghost Overlay:**
   * Màn hình hiển thị toàn bộ luồng camera dạng gương (lật ngang).
   * Thanh chọn **4 Trạm tuần tự hoặc tự do**: `1. Lông mày` -> `2. Mắt (Phấn & Eyeliner)` -> `3. Má hồng` -> `4. Môi`.
   * Thanh công cụ thao tác một tay ở cạnh dưới cho phép bật/tắt nhanh:
     * **Chế độ Đường viền (Guide Lines):** Vẽ khung đường mảnh chuẩn theo trạm đang chọn.
     * **Chế độ Bóng mờ (AR Ghost Overlay):** Phủ lớp trang điểm từ ảnh mẫu khớp theo lưới mặt với thanh trượt độ mờ **0% – 50%** (mặc định 30%).
     * **Chế độ Chia đôi (Split Compare):** Kéo màn rèm dọc để đối chiếu mặt hiện tại với ảnh mẫu.
     * **Xem ghi chú mỹ phẩm:** Popup nhỏ hiển thị đúng mã son/phấn mắt đã lưu của trạm hiện tại.
4. **Bước 3 — Chấm điểm tại trạm (On-Demand Station Scoring):**
   * Khi làm xong một vùng, người dùng giữ thẳng mặt (HUD báo xanh) và bấm nút **"Chấm điểm"**.
   * Hệ thống chụp 1 khung hình sắc nét -> chạy BiSeNet (on-demand) -> chạy lõi chấm điểm C++.
   * Hiển thị **Bottom Sheet kết quả** (không rời khỏi màn hình gương):
     * Điểm số của trạm hiện tại (thang điểm khích lệ).
     * 3 thanh chỉ số phụ: **Độ chuẩn màu**, **Độ khớp dáng & Cân đối**, **Độ mịn tán phấn** (áp dụng cho Mắt/Má).
     * **Tối đa 1–2 lời khuyên ngắn, định lượng, dễ sửa ngay** (ví dụ: *"Đuôi mắt phải đang thấp hơn mẫu 2 mm, nâng nhẹ góc đuôi lên"* hoặc *"Viền má hồng bên trái hơi gắt, tán loang thêm bằng cọ sạch"*).
     * Nút **"Chấm lại"** hoặc **"Sang trạm tiếp theo"**.
5. **Bước 4 — Tổng kết phiên trang điểm:**
   * Sau khi hoàn tất các trạm, hiển thị thẻ tổng điểm, ảnh so sánh Trước/Sau (hoặc So với Mẫu) và lưu vào lịch sử luyện tập.

### Luồng C: Bộ 10 Preset đóng gói sẵn (Bundled Presets)
Đóng gói sẵn 10 tệp `.dna.json` trong `assets/presets/` để người dùng mới có thể trải nghiệm ngay lập tức mà chưa cần tải ảnh mẫu:
1. Hàn Quốc trong veo (Daily Clean Girl)
2. Công sở thanh lịch (Office Soft Matte)
3. Douyin mắt to (Douyin Doll)
4. Thái Lan sắc sảo (Thai Glam)
5. Dự tiệc tối quyến rũ (Evening Smokey)
6. Mùa hè cam đào (Peach Coral)
7. Kẻ mắt mèo cổ điển (Classic Cat-Eye)
8. Hồng lạnh tiểu thư (Cool Pink)
9. Tự nhiên không phấn mắt (No-Makeup Look)
10. Tây phương tạo khối (Soft Western)

---

## 3. Đặc tả màn hình & Nguyên tắc UX

### Nguyên tắc thiết kế gương thao tác một tay (One-Handed Mirror UX)
* Toàn bộ nút điều khiển chính (chuyển trạm, thanh trượt Ghost Overlay, nút Chấm điểm) phải đặt trong **35% vùng dưới cùng màn hình** để người dùng thao tác bằng ngón cái khi tay kia đang cầm cọ/son.
* Khu vực hiển thị khuôn mặt (65% phía trên) giữ sạch tối đa; chỉ hiển thị pill cảnh báo ánh sáng/góc mặt mảnh ở mép trên khi có lỗi.
* Giao diện sử dụng nền tối trung tính (Dark Neutral `#121214`) để tránh ánh sáng màn hình hắt màu sai lệch lên da mặt người dùng.

### Nguyên tắc phản hồi điểm số (Encouraging Scoring UX)
* Không hiển thị điểm thô quá thấp gây nản chí (ví dụ 25/100 cho người mới tập).
* Ánh xạ điểm thô $S_{raw} \in [0, 100]$ sang điểm hiển thị $S_{display} \in [60, 99]$ theo đường cong phi tuyến (định nghĩa chi tiết ở file `02`).
* Luôn hiển thị **1 lời khen cho chỉ số cao nhất** trước khi hiển thị **1–2 điểm cần chỉnh sửa**.

---

## 4. Mô hình Freemium & Paywall (RevenueCat)

| Tính năng | Gói Miễn phí (Free) | Gói Pro (Subscription / Lifetime) |
|---|---|---|
| Lưu kho Makeup DNA cá nhân | Tối đa **3 layout** | Không giới hạn |
| Bộ Preset có sẵn | 5 mẫu cơ bản | Toàn bộ 10+ mẫu |
| Hướng dẫn Đường viền AR (Guide Lines) | Có | Có |
| Chế độ AR Ghost Overlay tùy chỉnh độ mờ | Chỉ dùng thử 10 giây | Không giới hạn |
| Chấm điểm tổng quan & 1 gợi ý chính | Có | Có |
| Báo cáo chi tiết 3 chỉ số (Màu / Dáng / Tán phấn) | Khóa | Mở khóa đầy đủ |
| Gắn thẻ nhật ký mỹ phẩm theo từng layout | Khóa | Mở khóa đầy đủ |

* **Nguyên tắc Offline cho Pro Entitlement:** Cache trạng thái entitlement của RevenueCat xuống local storage để người dùng Pro vẫn dùng đầy đủ tính năng khi tắt Wi-Fi/4G.