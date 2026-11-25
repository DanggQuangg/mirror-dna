#include "cv_engine_api.h"
#include <gtest/gtest.h>
#include <cmath>

TEST(Bridge, ReportsAbiVersion) {
    EXPECT_EQ(cv_engine_abi_version(), 1);
}

TEST(Bridge, StubsReportUnavailableWithoutReadingBuffers) {
    auto quality = cv_check_quality(nullptr, 0, 0, 0, 0, 0, 8);
    EXPECT_EQ(quality.is_valid, 0);
    EXPECT_EQ(quality.error_code, -1);
    auto anchor = cv_compute_anchor_skin(nullptr, 0, 0, nullptr, nullptr);
    EXPECT_TRUE(std::isnan(anchor.l));
    auto score = cv_score_station(nullptr, 0, 0, nullptr, nullptr, anchor, nullptr, 0);
    EXPECT_EQ(score.display_score, -1);
    EXPECT_TRUE(std::isnan(score.raw_score));
    auto dna = cv_extract_makeup_dna_json(nullptr, 0, 0, nullptr, nullptr, nullptr);
    EXPECT_EQ(dna, nullptr);
    cv_free_string(dna);
}
