__version__ = "0.1.0"

from dataclasses import dataclass


def sdk_name() -> str:
    return "wavium-python-sdk"


def package_name() -> str:
    return "wavium"


class AbiError(Exception):
    """Raised when canonical ABI encoding or decoding fails."""


@dataclass(frozen=True)
class CapabilityHandle:
    """An opaque, runtime-issued capability handle. Resource access always
    flows through a handle like this rather than an ambient API."""

    id: int

    def is_valid(self) -> bool:
        return self.id != 0


# Canonical ABI codecs. These mirror the encoding used by wavium-wit so that
# payloads produced by this SDK are wire-compatible with the runtime.
def encode_i32(value: int, out: bytearray) -> int:
    if len(out) < 4:
        raise AbiError("buffer too small")
    out[0:4] = value.to_bytes(4, byteorder="little", signed=True)
    return 4


def decode_i32(data: bytes) -> int:
    if len(data) < 4:
        raise AbiError("buffer too small")
    return int.from_bytes(data[0:4], byteorder="little", signed=True)


def encode_bool(value: bool, out: bytearray) -> int:
    if len(out) < 1:
        raise AbiError("buffer too small")
    out[0] = 1 if value else 0
    return 1


def decode_bool(data: bytes) -> bool:
    if len(data) < 1:
        raise AbiError("buffer too small")
    if data[0] == 0:
        return False
    if data[0] == 1:
        return True
    raise AbiError("invalid boolean encoding")


def encode_string(value: str, out: bytearray) -> int:
    payload = value.encode("utf-8")
    if len(payload) > 0xFFFFFFFF:
        raise AbiError("string too long")
    required = 4 + len(payload)
    if len(out) < required:
        raise AbiError("buffer too small")
    out[0:4] = len(payload).to_bytes(4, byteorder="little")
    out[4:required] = payload
    return required


def decode_string(data: bytes) -> str:
    if len(data) < 4:
        raise AbiError("buffer too small")
    length = int.from_bytes(data[0:4], byteorder="little")
    required = 4 + length
    if len(data) < required:
        raise AbiError("buffer too small")
    return bytes(data[4:required]).decode("utf-8")
