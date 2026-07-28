#ifndef WAVIUM_H
#define WAVIUM_H

#include <stddef.h>
#include <stdint.h>

#define WAVIUM_SDK_VERSION "0.1.0"

const char *wavium_sdk_name(void);
const char *wavium_package_name(void);

/* An opaque, runtime-issued capability handle. Resource access always flows
 * through a handle like this rather than an ambient API. */
typedef struct {
    uint64_t id;
} wavium_capability_handle;

int wavium_capability_is_valid(wavium_capability_handle handle);

typedef enum {
    WAVIUM_ABI_OK = 0,
    WAVIUM_ABI_ERR_BUFFER_TOO_SMALL = 1,
    WAVIUM_ABI_ERR_INVALID_BOOL = 2,
    WAVIUM_ABI_ERR_STRING_TOO_LONG = 3,
} wavium_abi_status;

/* Canonical ABI codecs. These mirror the encoding used by wavium-wit so that
 * payloads produced by this SDK are wire-compatible with the runtime. */
wavium_abi_status wavium_encode_i32(int32_t value, uint8_t *out, size_t out_len, size_t *written);
wavium_abi_status wavium_decode_i32(const uint8_t *data, size_t data_len, int32_t *value);

wavium_abi_status wavium_encode_bool(int value, uint8_t *out, size_t out_len, size_t *written);
wavium_abi_status wavium_decode_bool(const uint8_t *data, size_t data_len, int *value);

wavium_abi_status wavium_encode_string(const char *value, size_t value_len, uint8_t *out, size_t out_len, size_t *written);
wavium_abi_status wavium_decode_string(const uint8_t *data, size_t data_len, const uint8_t **value_ptr, size_t *value_len);

#endif
