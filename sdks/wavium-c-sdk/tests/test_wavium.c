#include "../include/wavium.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>

static void test_capability_handle_validity(void) {
    wavium_capability_handle zero = {0};
    wavium_capability_handle nonzero = {7};
    assert(!wavium_capability_is_valid(zero));
    assert(wavium_capability_is_valid(nonzero));
}

static void test_encode_decode_i32(void) {
    uint8_t buf[4];
    size_t written = 0;
    assert(wavium_encode_i32(-99, buf, sizeof(buf), &written) == WAVIUM_ABI_OK);
    assert(written == 4);

    int32_t value = 0;
    assert(wavium_decode_i32(buf, sizeof(buf), &value) == WAVIUM_ABI_OK);
    assert(value == -99);
}

static void test_encode_decode_bool(void) {
    uint8_t buf[1];
    size_t written = 0;
    assert(wavium_encode_bool(1, buf, sizeof(buf), &written) == WAVIUM_ABI_OK);
    assert(written == 1);

    int value = 0;
    assert(wavium_decode_bool(buf, sizeof(buf), &value) == WAVIUM_ABI_OK);
    assert(value == 1);

    uint8_t bad = 9;
    assert(wavium_decode_bool(&bad, 1, &value) == WAVIUM_ABI_ERR_INVALID_BOOL);
}

static void test_encode_decode_string(void) {
    uint8_t buf[32];
    size_t written = 0;
    const char *msg = "wavium-sdk";
    assert(wavium_encode_string(msg, strlen(msg), buf, sizeof(buf), &written) == WAVIUM_ABI_OK);

    const uint8_t *value_ptr = NULL;
    size_t value_len = 0;
    assert(wavium_decode_string(buf, written, &value_ptr, &value_len) == WAVIUM_ABI_OK);
    assert(value_len == strlen(msg));
    assert(memcmp(value_ptr, msg, value_len) == 0);
}

static void test_buffer_too_small(void) {
    uint8_t buf[2];
    size_t written = 0;
    assert(wavium_encode_i32(1, buf, sizeof(buf), &written) == WAVIUM_ABI_ERR_BUFFER_TOO_SMALL);
}

int main(void) {
    test_capability_handle_validity();
    test_encode_decode_i32();
    test_encode_decode_bool();
    test_encode_decode_string();
    test_buffer_too_small();
    printf("wavium-c-sdk: all tests passed\n");
    return 0;
}
