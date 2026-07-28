#include "wavium.h"
#include <string.h>

const char *wavium_sdk_name(void) {
    return "wavium-c-sdk";
}

const char *wavium_package_name(void) {
    return "wavium";
}

int wavium_capability_is_valid(wavium_capability_handle handle) {
    return handle.id != 0;
}

wavium_abi_status wavium_encode_i32(int32_t value, uint8_t *out, size_t out_len, size_t *written) {
    if (out_len < 4) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    uint32_t bits = (uint32_t)value;
    out[0] = (uint8_t)(bits & 0xFF);
    out[1] = (uint8_t)((bits >> 8) & 0xFF);
    out[2] = (uint8_t)((bits >> 16) & 0xFF);
    out[3] = (uint8_t)((bits >> 24) & 0xFF);
    if (written) *written = 4;
    return WAVIUM_ABI_OK;
}

wavium_abi_status wavium_decode_i32(const uint8_t *data, size_t data_len, int32_t *value) {
    if (data_len < 4) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    uint32_t bits = (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
                    ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
    *value = (int32_t)bits;
    return WAVIUM_ABI_OK;
}

wavium_abi_status wavium_encode_bool(int value, uint8_t *out, size_t out_len, size_t *written) {
    if (out_len < 1) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    out[0] = value ? 1 : 0;
    if (written) *written = 1;
    return WAVIUM_ABI_OK;
}

wavium_abi_status wavium_decode_bool(const uint8_t *data, size_t data_len, int *value) {
    if (data_len < 1) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    if (data[0] == 0) {
        *value = 0;
        return WAVIUM_ABI_OK;
    }
    if (data[0] == 1) {
        *value = 1;
        return WAVIUM_ABI_OK;
    }
    return WAVIUM_ABI_ERR_INVALID_BOOL;
}

wavium_abi_status wavium_encode_string(const char *value, size_t value_len, uint8_t *out, size_t out_len, size_t *written) {
    if (value_len > 0xFFFFFFFFu) return WAVIUM_ABI_ERR_STRING_TOO_LONG;
    size_t required = 4 + value_len;
    if (out_len < required) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    uint32_t len32 = (uint32_t)value_len;
    out[0] = (uint8_t)(len32 & 0xFF);
    out[1] = (uint8_t)((len32 >> 8) & 0xFF);
    out[2] = (uint8_t)((len32 >> 16) & 0xFF);
    out[3] = (uint8_t)((len32 >> 24) & 0xFF);
    memcpy(out + 4, value, value_len);
    if (written) *written = required;
    return WAVIUM_ABI_OK;
}

wavium_abi_status wavium_decode_string(const uint8_t *data, size_t data_len, const uint8_t **value_ptr, size_t *value_len) {
    if (data_len < 4) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    uint32_t len32 = (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
                     ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
    size_t required = 4 + (size_t)len32;
    if (data_len < required) return WAVIUM_ABI_ERR_BUFFER_TOO_SMALL;
    *value_ptr = data + 4;
    *value_len = len32;
    return WAVIUM_ABI_OK;
}
