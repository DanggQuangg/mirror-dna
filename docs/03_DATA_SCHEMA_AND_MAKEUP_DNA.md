# 03. Cấu trúc Dữ liệu Makeup DNA & Schema SQLite Cục bộ

## 1. Cấu trúc tệp JSON của Makeup DNA (`*.dna.json`)
Mỗi layout trang điểm (tự lưu từ ảnh cũ hoặc preset đóng gói sẵn) được biểu diễn dưới dạng một tệp JSON nhẹ (khoảng 30–50 KB) chứa thông số hình học chuẩn hóa và sắc độ tương đối.

```json
{
  "schema_version": "1.0.0",
  "dna_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at_utc": "2026-11-25T08:30:00Z",
  "source_type": "personal_photo",
  "lighting_baseline": {
    "anchor_skin_lab": { "l": 68.4, "a": 10.2, "b": 15.8 },
    "mean_luminance": 64.1,
    "lr_light_diff": 3.2
  },
  "regions": {
    "eyebrows": {
      "relative_lab": { "l": -34.2, "a": -4.1, "b": -7.5 },
      "left_uv_polygon": [[0.24, 0.36], [0.33, 0.34], [0.43, 0.37], [0.33, 0.37]],
      "right_uv_polygon": [[0.57, 0.37], [0.67, 0.34], [0.76, 0.36], [0.67, 0.37]],
      "arch_angle_deg": 14.5,
      "thickness_ratio": 0.028
    },
    "eyes": {
      "eyeshadow_relative_lab": { "l": -12.8, "a": 8.6, "b": 4.2 },
      "eyeliner_relative_lab": { "l": -48.0, "a": -6.2, "b": -10.1 },
      "eyeshadow_left_uv_polygon": [[0.26, 0.40], [0.42, 0.41], [0.41, 0.44], [0.27, 0.44]],
      "eyeshadow_right_uv_polygon": [[0.58, 0.41], [0.74, 0.40], [0.73, 0.44], [0.59, 0.44]],
      "eyeliner_wing_angle_left_deg": 18.0,
      "eyeliner_wing_angle_right_deg": 17.5,
      "eyeliner_wing_length_ratio": 0.22,
      "target_blending_gradient": 6.8
    },
    "blush": {
      "relative_lab": { "l": -5.4, "a": 14.5, "b": 2.1 },
      "left_uv_polygon": [[0.22, 0.54], [0.36, 0.55], [0.34, 0.65], [0.21, 0.62]],
      "right_uv_polygon": [[0.64, 0.55], [0.78, 0.54], [0.79, 0.62], [0.66, 0.65]],
      "placement_style": "apple_to_temple",
      "target_blending_gradient": 5.2
    },
    "lips": {
      "relative_lab": { "l": -18.6, "a": 29.4, "b": 11.2 },
      "outer_uv_polygon": [[0.38, 0.75], [0.50, 0.73], [0.62, 0.75], [0.50, 0.82]],
      "finish_gloss_index": 0.62,
      "overdraw_ratio": 0.03
    }
  }
}
```

### Quy ước tọa độ UV
* Mọi tọa độ `[u, v]` nằm trong khoảng $[0.0, 1.0]$ của bản đồ mặt chuẩn hóa (Canonical Face UV Map $256 \times 256$ của MediaPipe Face Mesh).
* Số điểm tối đa mỗi đa giác được rút gọn bằng thuật toán Douglas-Peucker (`cv::approxPolyDP`) còn 16–32 điểm để tệp JSON luôn nhỏ gọn và xử lý nhanh.

---

## 2. Schema Cơ sở dữ liệu SQLite (Triển khai bằng Drift)

Agent tạo các bảng trong `lib/core/database/tables/` theo cấu trúc quan hệ chuẩn dưới đây:

```sql
-- 1. Kho layout trang điểm (gồm cả Personal Looks và Bundled Presets)
CREATE TABLE makeup_looks (
    id TEXT PRIMARY KEY,                  -- UUID v4
    name TEXT NOT NULL,                   -- VD: "Tiệc tối 20/10"
    category TEXT NOT NULL,               -- 'personal' | 'preset'
    occasion_tag TEXT,                    -- 'daily' | 'office' | 'party' | 'date'
    dna_json_path TEXT NOT NULL,          -- Đường dẫn tương đối tới file .dna.json
    thumbnail_webp_path TEXT NOT NULL,    -- Ảnh đại diện nén WebP (max 512px)
    uv_overlay_webp_path TEXT NOT NULL,   -- Ảnh UV texture trong suốt cho AR Ghost Overlay
    is_favorite INTEGER NOT NULL DEFAULT 0,
    best_overall_score INTEGER,           -- Điểm cao nhất người dùng từng đạt khi tái tạo
    created_at INTEGER NOT NULL,          -- Unix timestamp (ms)
    updated_at INTEGER NOT NULL
);

-- 2. Danh mục mỹ phẩm cá nhân người dùng đã nhập
CREATE TABLE cosmetic_products (
    id TEXT PRIMARY KEY,
    brand TEXT,                           -- VD: "3CE", "Rom&nd"
    product_name TEXT NOT NULL,           -- VD: "Juicy Lasting Tint"
    shade_code TEXT,                      -- VD: "#23 Nucadamia"
    station_type TEXT NOT NULL,           -- 'eyebrows' | 'eyes' | 'blush' | 'lips' | 'base'
    notes TEXT,
    created_at INTEGER NOT NULL
);

-- 3. Bảng liên kết: Layout nào dùng những món mỹ phẩm nào
CREATE TABLE look_products (
    look_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    step_note TEXT,                       -- VD: "Đánh lòng môi 2 lớp"
    PRIMARY KEY (look_id, product_id),
    FOREIGN KEY (look_id) REFERENCES makeup_looks(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES cosmetic_products(id) ON DELETE CASCADE
);

-- 4. Lịch sử các phiên trang điểm / luyện tập
CREATE TABLE practice_sessions (
    id TEXT PRIMARY KEY,
    look_id TEXT NOT NULL,
    overall_display_score INTEGER NOT NULL,
    anchor_lab_l REAL,
    anchor_lab_a REAL,
    anchor_lab_b REAL,
    calibration_skipped INTEGER NOT NULL DEFAULT 0,
    result_photo_webp_path TEXT,          -- Tùy chọn: ảnh lưu kỷ niệm sau phiên
    started_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (look_id) REFERENCES makeup_looks(id) ON DELETE CASCADE
);

-- 5. Chi tiết điểm số từng trạm trong một phiên
CREATE TABLE station_scores (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    station_type TEXT NOT NULL,           -- 'eyebrows' | 'eyes' | 'blush' | 'lips'
    display_score INTEGER NOT NULL,
    raw_score REAL NOT NULL,
    color_score REAL NOT NULL,
    shape_score REAL NOT NULL,
    blending_score REAL,                  -- NULL nếu là môi/lông mày
    symmetry_score REAL NOT NULL,
    delta_e2000 REAL NOT NULL,
    primary_tip_code INTEGER NOT NULL,
    secondary_tip_code INTEGER,
    scored_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES practice_sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_looks_category ON makeup_looks(category, created_at DESC);
CREATE INDEX idx_sessions_look ON practice_sessions(look_id, started_at DESC);
CREATE INDEX idx_station_scores_session ON station_scores(session_id);
```

---

## 3. Tổ chức lưu trữ tệp cục bộ (Local File Sandbox)
Toàn bộ tệp sinh ra được lưu trong `getApplicationDocumentsDirectory()/mirror_dna_storage/`:

```text
mirror_dna_storage/
├── dna/
│   └── {look_id}.dna.json          # JSON Makeup DNA (~30-50 KB)
├── overlays/
│   └── {look_id}_uv.webp           # Ảnh RGBA UV texture nén lossless/q85 (~25-40 KB)
├── thumbnails/
│   └── {look_id}_thumb.webp        # Ảnh chân dung resize 512x512, WebP q80 (~20-35 KB)
└── sessions/
    └── {session_id}_final.webp     # Ảnh kết quả nếu người dùng chọn lưu
```

* **Chính sách dọn rác (Cleanup Rule):** Khi người dùng xóa một bản ghi trong `makeup_looks`, tầng Repository phải đồng thời xóa toàn bộ các tệp tương ứng trong `dna/`, `overlays/`, `thumbnails/` và các ảnh `sessions/` liên quan để tránh rò rỉ bộ nhớ thiết bị.