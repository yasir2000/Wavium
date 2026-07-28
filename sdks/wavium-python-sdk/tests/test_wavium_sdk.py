import unittest

from wavium_sdk import (
    AbiError,
    CapabilityHandle,
    decode_bool,
    decode_i32,
    decode_string,
    encode_bool,
    encode_i32,
    encode_string,
    package_name,
    sdk_name,
)


class WaviumSdkTests(unittest.TestCase):
    def test_sdk_name(self):
        self.assertEqual(sdk_name(), "wavium-python-sdk")

    def test_package_name(self):
        self.assertEqual(package_name(), "wavium")

    def test_capability_handle_validity(self):
        self.assertFalse(CapabilityHandle(id=0).is_valid())
        self.assertTrue(CapabilityHandle(id=7).is_valid())

    def test_encode_decode_i32(self):
        buf = bytearray(4)
        encode_i32(-99, buf)
        self.assertEqual(decode_i32(bytes(buf)), -99)

    def test_encode_decode_bool(self):
        buf = bytearray(1)
        encode_bool(True, buf)
        self.assertTrue(decode_bool(bytes(buf)))
        with self.assertRaises(AbiError):
            decode_bool(bytes([9]))

    def test_encode_decode_string(self):
        buf = bytearray(32)
        used = encode_string("wavium-sdk", buf)
        self.assertEqual(decode_string(bytes(buf[:used])), "wavium-sdk")

    def test_buffer_too_small(self):
        with self.assertRaises(AbiError):
            encode_i32(1, bytearray(2))


if __name__ == "__main__":
    unittest.main()
