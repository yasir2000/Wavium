package wavium

import (
	"encoding/binary"
	"errors"
	"math"
)

const Version = "0.1.0"

func SDKName() string {
	return "wavium-go-sdk"
}

func PackageName() string {
	return "wavium"
}

// CapabilityHandle is an opaque, runtime-issued capability handle. Resource
// access always flows through a handle like this rather than an ambient API.
type CapabilityHandle struct {
	ID uint64
}

func (h CapabilityHandle) IsValid() bool {
	return h.ID != 0
}

var (
	ErrBufferTooSmall         = errors.New("wavium: buffer too small")
	ErrInvalidBooleanEncoding = errors.New("wavium: invalid boolean encoding")
	ErrStringTooLong          = errors.New("wavium: string too long")
)

// EncodeI32 and the sibling codecs below mirror the canonical ABI encoding
// used by wavium-wit so payloads stay wire-compatible with the runtime.
func EncodeI32(value int32, out []byte) (int, error) {
	if len(out) < 4 {
		return 0, ErrBufferTooSmall
	}
	binary.LittleEndian.PutUint32(out, uint32(value))
	return 4, nil
}

func DecodeI32(data []byte) (int32, error) {
	if len(data) < 4 {
		return 0, ErrBufferTooSmall
	}
	return int32(binary.LittleEndian.Uint32(data[:4])), nil
}

func EncodeBool(value bool, out []byte) (int, error) {
	if len(out) < 1 {
		return 0, ErrBufferTooSmall
	}
	if value {
		out[0] = 1
	} else {
		out[0] = 0
	}
	return 1, nil
}

func DecodeBool(data []byte) (bool, error) {
	if len(data) < 1 {
		return false, ErrBufferTooSmall
	}
	switch data[0] {
	case 0:
		return false, nil
	case 1:
		return true, nil
	default:
		return false, ErrInvalidBooleanEncoding
	}
}

func EncodeString(value string, out []byte) (int, error) {
	if len(value) > math.MaxUint32 {
		return 0, ErrStringTooLong
	}
	required := 4 + len(value)
	if len(out) < required {
		return 0, ErrBufferTooSmall
	}
	binary.LittleEndian.PutUint32(out[:4], uint32(len(value)))
	copy(out[4:required], value)
	return required, nil
}

func DecodeString(data []byte) (string, error) {
	if len(data) < 4 {
		return "", ErrBufferTooSmall
	}
	length := binary.LittleEndian.Uint32(data[:4])
	required := 4 + int(length)
	if len(data) < required {
		return "", ErrBufferTooSmall
	}
	return string(data[4:required]), nil
}
