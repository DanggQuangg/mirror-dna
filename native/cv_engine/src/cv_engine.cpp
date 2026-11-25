#include "cv_engine_api.h"

#include <cstdlib>
#include <limits>

int32_t cv_engine_abi_version() { return 1; }

// Phase 0 exposes the ABI only. NaN and -1 denote unavailable measurements.
constexpr float unavailable = std::numeric_limits<float>::quiet_NaN();

QualityGateResult cv_check_quality(const uint8_t*, int32_t, int32_t, float,
                                   float, float, float) {
    return {0, -1, unavailable, unavailable, unavailable};
}

LabColor cv_compute_anchor_skin(const uint8_t*, int32_t, int32_t,
                                const uint8_t*, const Point3F*) {
    return {unavailable, unavailable, unavailable};
}

char* cv_extract_makeup_dna_json(const uint8_t*, int32_t, int32_t,
                                 const uint8_t*, const Point3F*, uint8_t*) {
    return nullptr;
}

StationScoreResult cv_score_station(const uint8_t*, int32_t, int32_t,
                                    const uint8_t*, const Point3F*, LabColor,
                                    const char*, int32_t) {
    return {unavailable, -1, unavailable, unavailable, unavailable, unavailable,
            unavailable, unavailable, unavailable, unavailable, -1, -1};
}

void cv_free_string(char* ptr) { std::free(ptr); }
