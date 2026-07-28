package wavium

import "testing"

func TestSDKName(t *testing.T) {
	if SDKName() != "wavium-go-sdk" {
		t.Fatalf("unexpected sdk name: %s", SDKName())
	}
}

func TestCapabilityHandleValidity(t *testing.T) {
	if (CapabilityHandle{ID: 0}).IsValid() {
		t.Fatal("zero id should not be valid")
	}
	if !(CapabilityHandle{ID: 7}).IsValid() {
		t.Fatal("non-zero id should be valid")
	}
}

func TestEncodeDecodeI32(t *testing.T) {
	buf := make([]byte, 4)
	if _, err := EncodeI32(-99, buf); err != nil {
		t.Fatalf("encode failed: %v", err)
	}
	value, err := DecodeI32(buf)
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if value != -99 {
		t.Fatalf("expected -99, got %d", value)
	}
}

func TestEncodeDecodeBool(t *testing.T) {
	buf := make([]byte, 1)
	if _, err := EncodeBool(true, buf); err != nil {
		t.Fatalf("encode failed: %v", err)
	}
	value, err := DecodeBool(buf)
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if !value {
		t.Fatal("expected true")
	}
	if _, err := DecodeBool([]byte{9}); err != ErrInvalidBooleanEncoding {
		t.Fatalf("expected ErrInvalidBooleanEncoding, got %v", err)
	}
}

func TestEncodeDecodeString(t *testing.T) {
	buf := make([]byte, 32)
	used, err := EncodeString("wavium-sdk", buf)
	if err != nil {
		t.Fatalf("encode failed: %v", err)
	}
	value, err := DecodeString(buf[:used])
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if value != "wavium-sdk" {
		t.Fatalf("expected wavium-sdk, got %s", value)
	}
}

func TestEncodeBufferTooSmall(t *testing.T) {
	if _, err := EncodeI32(1, make([]byte, 2)); err != ErrBufferTooSmall {
		t.Fatalf("expected ErrBufferTooSmall, got %v", err)
	}
}
