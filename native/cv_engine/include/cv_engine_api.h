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

int32_t cv_engine_abi_version(void);

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
