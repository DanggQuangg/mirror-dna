# 02. Kiến trúc Hệ thống & Pipeline AI/CV Offline

## 1. Kiến trúc phân tầng (Layered Architecture)

```text
+-------------------------------------------------------------------+
|                     Flutter Presentation Layer                    |
|   (Vault, Enrollment, Calibration, AR Mirror HUD, Score Sheet)    |
+---------------------------------+---------------------------------+
                                  | Riverpod Providers & UseCases
+---------------------------------v---------------------------------+
|                    Domain & Data Layer (Dart)                     |
|   - Drift SQLite (Looks, Products, Sessions)                      |
|   - MakeupDNA JSON Serializer / Deserializer                      |
|   - Deterministic Feedback Tip Generator                          |
|   - RevenueCat Entitlement Cache                                  |
+----------------+----------------------------------+---------------+
                 | Platform Channel / Texture       | Dart FFI (C ABI)
+----------------v-----------------+  +-------------v---------------+
|   Native Camera & AR Engine      |  |    C++17 CV & Scoring Core  |
| - Android: CameraX + OpenGL ES   |  | - OpenCV (CIELAB, Sobel,    |
| - iOS: AVFoundation + Metal      |  |   Morphology, Warping)      |
| - MediaPipe Face Landmarker      |  | - Bare-Face Calibration     |
|   (Throttled 15-20 FPS)          |  | - Delta E 2000 Engine       |
| - AR Ghost Overlay Shader        |  | - IoU & Symmetry Engine     |
+----------------+-----------------+  +-------------^---------------+
                 | On-Demand Frame Capture          | Masks + Landmarks
                 +-------------->+------------------+
                                 | On-Demand Face Parsing
                        +--------v---------+
                        |  ONNX Runtime    |
                        |  BiSeNet (INT8)  |
                        |  (~12 MB)        |
                        +------------------+
```

---

## 2. Danh mục mô hình AI & Ngân sách tài nguyên

| Thành phần | Mô hình / Thư viện | Định dạng | Dung lượng | Chế độ chạy | Độ trễ mục tiêu |
|---|---|---|---|---|---|
| Nhận diện khung mặt & 478 mốc 3D | Google MediaPipe Face Landmarker | `.task` (TFLite GPU/CPU) | ~4 MB | Liên tục (giới hạn 15–20 FPS) | 8–12 ms |
| Phân vùng bộ phận trang điểm | BiSeNet (CelebAMask-HQ 19 classes) | `.onnx` (INT8 static/dynamic) | ~12 MB | **On-Demand** (chỉ khi lưu mẫu hoặc bấm Chấm điểm) | 120–250 ms |
| Lõi xử lý ảnh & Chấm điểm | OpenCV 4.x (C++17 custom build: `core`, `imgproc`) | `.so` / `.xcframework` | ~15–18 MB | **On-Demand** qua Dart FFI | 40–80 ms |

> **Lưu ý tối ưu build OpenCV:** Chỉ biên dịch các module `opencv_core` và `opencv_imgproc` (tắt `videoio`, `highgui`, `dnn`, `calib3d` nếu không dùng) để giữ dung lượng binary nhỏ nhất có thể.

---

## 3. Phân lớp nhãn BiSeNet (CelebAMask-HQ Mapping)
Mô hình BiSeNet xuất bản đồ phân vùng kích thước $512 \times 512$ với các class ID chuẩn CelebAMask-HQ. Quy ước ánh xạ về các vùng trang điểm của MirrorDNA như sau:
* `skin` (class 1): Vùng da mặt cơ sở (dùng để lấy mẫu da nền loại trừ vùng má/mắt/môi).
* `l_brow` (class 2), `r_brow` (class 3): Trạm **Lông mày**.
* `l_eye` (class 4), `r_eye` (class 5): Vùng nhãn cầu (dùng làm mốc loại trừ khi tách vùng phấn mắt và eyeliner quanh mí).
* `u_lip` (class 12), `l_lip` (class 13): Trạm **Môi**.
* **Vùng suy diễn hình học kết hợp MediaPipe Landmarks + Mask `skin`:**
  * **Bầu mắt (Eyeshadow ROI):** Vùng đa giác giữa đường mí mắt trên (`l_eye`/`r_eye`) và đường dưới lông mày (`l_brow`/`r_brow`), lọc giao với `skin`.
  * **Đường kẻ mắt (Eyeliner ROI):** Dải pixel rộng bằng $12\%$ chiều cao mắt dọc theo mí mắt trên và mở rộng ra đuôi mắt ngoài bằng $35\%$ chiều rộng mắt.
  * **Vùng má hồng (Blush ROI):** Đa giác gò má định nghĩa bởi nhóm landmark MediaPipe vùng má trái/phải, lọc giao với `skin`.

---

## 4. Đặc tả thuật toán cốt lõi (C++ CV Engine)

### 4.1. Cổng kiểm tra chất lượng khung hình (Quality Gate)
Trước khi cho phép hiệu chuẩn hoặc chấm điểm, kiểm tra từ ma trận biến đổi 3D của MediaPipe và ảnh xám đầu vào:
1. **Góc đầu (Head Pose):** Trích xuất góc Euler $(\text{pitch}, \text{yaw}, \text{roll})$ từ `facialTransformationMatrixes`.
   * Điều kiện hợp lệ khi chấm điểm/hiệu chuẩn: $|\text{pitch}| \le 8^\circ$, $|\text{yaw}| \le 8^\circ$, $|\text{roll}| \le 8^\circ$.
   * Điều kiện hợp lệ khi nhập ảnh mẫu cũ: $|\text{pitch}| \le 15^\circ$, $|\text{yaw}| \le 15^\circ$.
2. **Độ sáng & Phân bố ánh sáng (Lighting Check):**
   * Tính giá trị kênh độ sáng $L^*$ trung bình trong vùng mặt: hợp lệ khi $35 \le \bar{L}^* \le 82$.
   * Tính chênh lệch độ sáng nửa mặt trái $\bar{L}^*_{left}$ và nửa mặt phải $\bar{L}^*_{right}$: cảnh báo lệch sáng nếu $|\bar{L}^*_{left} - \bar{L}^*_{right}| > 14$.
3. **Độ sắc nét (Blur Check):** Phương sai Laplacian trên vùng mặt phải đạt $\text{Var}(\nabla^2 I) \ge 60$.

### 4.2. Thuật toán Hiệu chuẩn ánh sáng & Mã hóa màu tương đối
Để giải quyết sai khác đèn phòng giữa ảnh mẫu cũ và lúc trang điểm thực tế, **không so sánh màu RGB/LAB tuyệt đối**, mà so sánh **độ dịch chuyển sắc độ tương đối so với da nền**.

1. **Xác định vùng da tham chiếu (Anchor Skin):** Lấy tập hợp pixel nằm ở vùng trán trên (gần chân tóc) hoặc vùng cằm dưới — nơi ít chịu ảnh hưởng của má hồng, phấn mắt và son. Tính trung vị (median) trong không gian màu **CIELAB** (tránh nhiễu điểm sáng/bóng đổ):
   $$\mathbf{c}_{anchor} = (L^*_{anchor}, a^*_{anchor}, b^*_{anchor})$$
   *(Ở bước hiệu chuẩn mặt mộc 2 giây, lưu $\mathbf{c}_{bare\_anchor}$ và cả màu mặt mộc của từng vùng môi/bầu mắt/má làm gốc chuẩn cho phiên hiện tại).*
2. **Mã hóa màu tương đối của vùng trang điểm $r$ (Relative Color Shift):**
   Với mỗi vùng $r \in \{\text{lips}, \text{blush}, \text{eyeshadow}, \text{eyebrows}\}$ có trung vị màu $\mathbf{c}_{r} = (L^*_r, a^*_r, b^*_r)$:
   $$\Delta \mathbf{c}_{r} = (L^*_r - L^*_{anchor},\; a^*_r - a^*_{anchor},\; b^*_r - b^*_{anchor})$$
3. **Tính khoảng cách màu $\Delta E_{2000}$ đã chuẩn hóa:**
   Để so sánh ảnh hiện tại với ảnh mẫu (DNA), quy đổi màu mục tiêu về hệ quy chiếu ánh sáng phòng hiện tại:
   $$\mathbf{c}_{target\_adapted} = \mathbf{c}_{current\_anchor} + \Delta \mathbf{c}_{r, DNA}$$
   Sau đó tính khoảng cách màu chuẩn CIE2000 $\Delta E_{2000}(\mathbf{c}_{r, current},\; \mathbf{c}_{target\_adapted})$ (cài đặt đầy đủ công thức chuẩn Sharma et al. 2005 trong `delta_e2000.cpp`).
4. **Quy đổi sang điểm màu $S_{color} \in [0, 100]$:**
   $$S_{color} = 100 \cdot \exp\left(-\frac{\Delta E_{2000}^2}{2 \sigma_c^2}\right)$$
   Với độ nhạy chuẩn đề xuất: $\sigma_c = 12.0$ cho môi/phấn mắt, $\sigma_c = 10.0$ cho má hồng/lông mày.

### 4.3. Thuật toán Chấm điểm Hình dáng & Cân đối (Geometry & Symmetry)
1. **Chuẩn hóa tọa độ về Không gian UV (Canonical Face Space):**
   Ánh xạ các đa giác/mask của từng vùng từ không gian ảnh về bản đồ lưới chuẩn hóa $256 \times 256$ thông qua phép biến đổi piecewise affine từ 478 điểm landmark MediaPipe. Điều này loại bỏ sai số do khoảng cách camera gần hay xa.
2. **Độ trùng khớp hình học (IoU):**
   Với mặt nạ nhị phân vùng trang điểm hiện tại $M_{curr}$ và mặt nạ mẫu $M_{ref}$ trên không gian chuẩn hóa:
   $$\text{IoU} = \frac{|M_{curr} \cap M_{ref}|}{|M_{curr} \cup M_{ref}|}$$
3. **Đo góc đuôi Eyeliner & Lông mày:**
   Tính góc vector $\theta$ từ khóe mắt ngoài đến đỉnh đuôi eyeliner (tách bằng ngưỡng tối cục bộ kênh $L^*$ trong Eyeliner ROI). Độ lệch góc $\Delta \theta = |\theta_{curr} - \theta_{ref}|$.
4. **Độ đối xứng Trái – Phải (Bilateral Symmetry):**
   Lật ngang mặt nạ vùng bên phải $M_{right}$ trên không gian UV chuẩn hóa thành $M'_{right}$, sau đó tính:
   $$S_{sym} = 100 \cdot \frac{|M_{left} \cap M'_{right}|}{|M_{left} \cup M'_{right}|}$$
5. **Điểm hình dáng tổng hợp $S_{shape}$:**
   $$S_{shape} = 0.65 \cdot (100 \cdot \text{IoU}) + 0.35 \cdot S_{sym}$$

### 4.4. Thuật toán Chấm điểm Độ mịn tán phấn (Blending Smoothness)
Áp dụng cho trạm **Má hồng** và **Phấn mắt**:
1. Xác định dải viền chuyển tiếp (Transition Band) bằng phép giãn nở và co nhỏ hình thái học (Morphological Dilation $-$ Erosion) quanh ranh giới vùng phấn trên kênh sắc độ $a^*$ và $b^*$.
2. Tính độ lớn gradient Sobel trung bình $G_{edge}$ trên dải viền chuyển tiếp:
   $$G_{edge} = \frac{1}{|B|} \sum_{(x,y) \in B} \sqrt{\left(\frac{\partial a^*}{\partial x}\right)^2 + \left(\frac{\partial a^*}{\partial y}\right)^2 + \left(\frac{\partial b^*}{\partial x}\right)^2 + \left(\frac{\partial b^*}{\partial y}\right)^2}$$
3. So sánh $G_{edge}$ với ngưỡng mượt mục tiêu $G_{target}$ lưu trong DNA (nếu $G_{edge} \le G_{target}$ coi như tán rất mượt, đạt 100 điểm; nếu cao hơn sẽ suy giảm tuyến tính):
   $$S_{blend} = \text{clamp}\left(100 - k_b \cdot \max(0,\; G_{edge} - G_{target}),\; 0,\; 100\right)$$
   Với hệ số mặc định $k_b = 4.5$.

### 4.5. Tổng hợp điểm & Ánh xạ khích lệ (UX Remapping)
* **Điểm thô của trạm $S_{raw}$:**
  * Trạm Lông mày & Môi: $S_{raw} = 0.45 S_{color} + 0.55 S_{shape}$
  * Trạm Mắt & Má hồng: $S_{raw} = 0.40 S_{color} + 0.35 S_{shape} + 0.25 S_{blend}$
* **Ánh xạ sang điểm hiển thị $S_{display}$ (phổ 60–99, thân thiện với người dùng):**
  $$S_{display} = \text{round}\left(60 + 39 \cdot \left(\frac{S_{raw}}{100}\right)^{0.75}\right)$$

### 4.6. Động cơ sinh gợi ý sửa lỗi tất định (Deterministic Tip Engine — Không dùng LLM)
Dựa trên dấu của sai lệch thành phần $(\Delta L^*, \Delta a^*, \Delta b^*)$, chênh lệch tọa độ đuôi mắt $(\Delta y_{left}, \Delta y_{right})$ và $G_{edge}$, sinh câu hướng dẫn theo bảng luật ưu tiên (chọn tối đa 2 lỗi lớn nhất):
* Nếu $\Delta L^* > 6$: *"Màu [vùng] đang nhạt hơn mẫu, dặm thêm 1 lớp mỏng."*
* Nếu $\Delta L^* < -6$: *"Màu [vùng] hơi đậm hơn mẫu, dùng bông mút/giấy thấm dặm bớt."*
* Nếu $\Delta a^* > 5$ và $\Delta b^* < -3$: *"Tông màu hơi thiên hồng/lạnh so với mẫu."*
* Nếu $\Delta b^* > 5$: *"Tông màu đang hơi thiên cam/ấm so với mẫu."*
* Nếu $S_{blend} < 75$: *"Viền [má hồng/phấn mắt] bị ranh giới gắt, dùng cọ sạch tán loang nhẹ ra ngoài."*
* Nếu $|\Delta y_{right} - \Delta y_{left}| > 0.015$ (tọa độ chuẩn hóa): *"Đuôi [lông mày/eyeliner] bên [trái/phải] đang thấp hơn bên còn lại khoảng 2 mm."*

---

## 5. Pipeline AR Ghost Overlay (GPU Shader)
Để đảm bảo 30–60 FPS không nóng máy:
1. Khi lưu Makeup DNA từ ảnh mẫu, hệ thống dùng MediaPipe landmarks để trải phẳng (UV unwrap) ảnh mẫu thành 1 ảnh texture chuẩn kích thước $512 \times 512$ (chỉ giữ lại alpha tại các vùng trang điểm đã phân tách bởi BiSeNet, phần da nền đặt alpha $= 0$). Lưu thành tệp WebP nén (~20–30 KB).
2. Khi bật Gương AR trực tiếp:
   * Luồng Camera gửi frame ra GPU texture.
   * MediaPipe cập nhật vị trí 478 đỉnh (vertex) ở 15–20 FPS; áp dụng **One-Euro Filter** để làm mượt chống rung tọa độ.
   * Vertex Shader/Fragment Shader (OpenGL ES trên Android / Metal trên iOS) phủ mảnh lưới UV của texture trang điểm mẫu lên đúng vị trí 478 đỉnh trên khung hình camera theo hệ số `opacity` người dùng kéo (0.0 đến 0.5), sử dụng chế độ hòa trộn `Multiply / Soft Light` cho phấn và `Alpha Blend` cho eyeliner/son.

---

## 6. Hợp đồng giao diện C++ FFI (`native/cv_engine/include/cv_engine_api.h`)
Agent phải tuân thủ chữ ký C ABI thuần để `ffigen` sinh binding tự động cho Dart:

```c
#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
    float z;
} Point3F;

typedef struct {
    float l;
    float a;
    float b;
} LabColor;

typedef struct {
    int32_t is_valid;
    int32_t error_code;      // 0: OK, 1: POSE_INVALID, 2: TOO_DARK, 3: UNEVEN_LIGHT, 4: BLURRY
    float mean_luminance;
    float lr_light_diff;
    float blur_variance;
} QualityGateResult;

typedef struct {
    float raw_score;
    int32_t display_score;
    float color_score;
    float shape_score;
    float blending_score;
    float symmetry_score;
    float delta_e2000;
    float delta_l;
    float delta_a;
    float delta_b;
    int32_t primary_tip_code;
    int32_t secondary_tip_code;
} StationScoreResult;

// 1. Kiểm tra chất lượng ảnh/khung hình
QualityGateResult cv_check_quality(
    const uint8_t* rgba_bytes, int32_t width, int32_t height,
    float pitch_deg, float yaw_deg, float roll_deg,
    float max_pose_deg
);

// 2. Tính màu da neo (Calibration)
LabColor cv_compute_anchor_skin(
    const uint8_t* rgba_bytes, int32_t width, int32_t height,
    const uint8_t* parsing_mask_512,
    const Point3F* landmarks_478
);

// 3. Trích xuất Makeup DNA JSON string (caller giải phóng bằng cv_free_string)
char* cv_extract_makeup_dna_json(
    const uint8_t* rgba_bytes, int32_t width, int32_t height,
    const uint8_t* parsing_mask_512,
    const Point3F* landmarks_478,
    uint8_t* out_uv_texture_rgba_512 // Buffer 512*512*4 để lưu làm Ghost Overlay
);

// 4. Chấm điểm 1 trạm trang điểm
StationScoreResult cv_score_station(
    const uint8_t* rgba_bytes, int32_t width, int32_t height,
    const uint8_t* parsing_mask_512,
    const Point3F* landmarks_478,
    LabColor current_anchor_lab,
    const char* target_dna_json,
    int32_t station_id // 0: EYEBROWS, 1: EYES, 2: BLUSH, 3: LIPS
);

void cv_free_string(char* ptr);

#ifdef __cplusplus
}
#endif
```